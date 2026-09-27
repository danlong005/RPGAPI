"""Custom 404 and error handlers (app: handlers, request limit 1000 bytes,
upload limit 3000)."""
from common import *
import json

args = setup(__doc__)

def as_json(body):
    try:
        return json.loads(body)
    except ValueError:
        return {}

status, headers, body = get('/ok')
check('a route answers as usual', (status, body) == (200, b'ok'), (status, body))

status, headers, body = get('/nope')
check('no route: the not-found handler answers',
      status == 404 and headers.get('content-type') == 'application/json' and
      as_json(body) == {'error': 'no route for GET /nope'}, (status, headers, body))
status, headers, body = get('/nope', method='HEAD')
check('HEAD with no route: its status and length, no body',
      status == 404 and headers.get('content-length') == str(len(b'{"error":"no route for HEAD /nope"}')) and
      body == b'', (status, headers, body))
status, headers, body = get('/items', method='OPTIONS')
check('OPTIONS on a path with routes is still answered with Allow',
      status == 204 and headers.get('allow') == 'GET, HEAD, OPTIONS', (status, headers))
status, headers, body = get('/nope', method='OPTIONS')
check('OPTIONS with no route: the not-found handler', status == 404 and
      as_json(body).get('error') == 'no route for OPTIONS /nope', (status, body))
status, headers, body = get('/zero')
check('a status left at 0 is sent as 404', (status, body) == (404, b'zero'), (status, body))

status, headers, body = get('/fail')
error = as_json(body)
check('a route that fails: the error handler answers with the escape message',
      status == 500 and headers.get('x-handled') == 'yes' and error.get('status') == 500 and
      error.get('id') == 'MCH1211' and 'divide by zero' in error.get('message', ''), (status, headers, body))
status, headers, body = get('/guarded')
check('failing middleware: the error handler answers', status == 500 and
      headers.get('x-handled') == 'yes' and as_json(body).get('id') == 'MCH1211', (status, body))

status, headers, body = get('/handler-fails')
check('an error handler that fails too: a plain 500', status == 500 and 'x-handled' not in headers,
      (status, headers, body))
check('and the server carries on', get('/ok')[2] == b'ok')

chunked_body = chunked(b'x' * 4000, [500] * 8)
status, headers, body = get('/read', 'Transfer-Encoding: chunked', method='POST', body=chunked_body)
error = as_json(body)
check('a body over the upload limit while the route reads it: the handler gets 413',
      status == 413 and error.get('status') == 413 and error.get('id') == 'CPF9898' and
      error.get('message', '').startswith('The request body'), (status, body))

status, headers, body = get('/read', 'Content-Length: 5000', method='POST', body=b'x' * 5000)
error = as_json(body)
check('a request refused before routing: the handler gets 413 and no message ID',
      status == 413 and error.get('status') == 413 and error.get('id') == '' and
      error.get('message') == 'Content Too Large', (status, body))
status, headers, body = get('/ok', 'X-Big: ' + 'y' * 40000)
check('headers too large: the handler gets 431', status == 431 and as_json(body).get('status') == 431,
      (status, body))

status, headers, body = get('/stream-fail')
text, complete = dechunk(body)
check('once a streamed response has begun, it is cut off, not handled',
      status == 200 and not complete and b'x-handled' not in body.lower(), (status, headers, body[:80]))
check('and the server carries on after that', get('/ok')[2] == b'ok')
done()
