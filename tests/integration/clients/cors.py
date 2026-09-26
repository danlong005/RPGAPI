"""HEAD, OPTIONS and CORS (app: cors). Mode "list" for an origin list with
credentials, max age and exposed headers; "any" for '*'."""
from common import *

args = setup(__doc__)
APP, OTHER = 'https://app.example.com', 'https://evil.example.com'
KEY = 'X-Key: k'

def request(method, path, *headers):
    return split(exchange(f'{method} {path} HTTP/1.1\r\nHost: x\r\n'.encode() +
                          b''.join(h.encode() + CRLF for h in headers) + CRLF))

if args.mode == 'list':
    status, headers, body = request('GET', '/items', KEY)
    get_length = headers.get('content-length')
    check('GET without Origin: no CORS headers', status == 200 and not any(h.startswith('access-control') for h in headers))
    status, headers, body = request('HEAD', '/items', KEY)
    check('HEAD is routed to GET, with its Content-Length and no body',
          status == 200 and headers.get('content-length') == str(len('HEAD items ')) and body == b'', (status, headers, body))
    status, headers, body = request('HEAD', '/nothing')
    check('HEAD of an unknown path: 404 without a body', status == 404 and body == b'')
    status, headers, body = request('HEAD', '/stream')
    check('HEAD of a streamed response: headers, no body', status == 200 and
          headers.get('transfer-encoding') == 'chunked' and body == b'', (status, headers, body[:30]))
    status, headers, body = request('OPTIONS', '/items', KEY)
    check('OPTIONS /items lists its methods', status == 204 and headers.get('allow') == 'GET, HEAD, POST, OPTIONS', (status, headers))
    status, headers, body = request('OPTIONS', '/items/5', KEY)
    check('OPTIONS /items/5 lists its methods', status == 204 and headers.get('allow') == 'GET, HEAD, PUT, OPTIONS', (status, headers))
    status, headers, body = request('OPTIONS', '/custom')
    check('an OPTIONS route of its own answers', (status, body) == (200, b'custom options'))
    status, headers, body = request('OPTIONS', '/nothing')
    check('OPTIONS of an unknown path: 404', status == 404)
    status, headers, body = request('OPTIONS', '/items')
    check('OPTIONS without CORS still goes through middleware', status == 401)

    status, headers, body = request('GET', '/items/7', KEY, f'Origin: {APP}')
    check('allowed origin gets the CORS headers', status == 200 and body == b'GET items 7' and
          headers.get('access-control-allow-origin') == APP and headers.get('vary') == 'Origin' and
          headers.get('access-control-allow-credentials') == 'true' and
          headers.get('access-control-expose-headers') == 'X-Total', headers)
    status, headers, body = request('GET', '/items', KEY, f'Origin: {OTHER}')
    check('other origin gets none', status == 200 and 'access-control-allow-origin' not in headers, headers)
    status, headers, body = request('GET', '/items', f'Origin: {APP}')
    check('CORS headers on the middleware\'s 401 too', status == 401 and headers.get('access-control-allow-origin') == APP)
    status, headers, body = request('OPTIONS', '/items', f'Origin: {APP}', 'Access-Control-Request-Method: POST',
                                    'Access-Control-Request-Headers: content-type, x-key')
    check('preflight is answered before the middleware', status == 204 and
          headers.get('access-control-allow-origin') == APP and
          headers.get('access-control-allow-methods') == 'GET, HEAD, POST, OPTIONS' and
          headers.get('access-control-allow-headers') == 'content-type, x-key' and
          headers.get('access-control-max-age') == '600' and
          headers.get('access-control-allow-credentials') == 'true', (status, headers))
    status, headers, body = request('OPTIONS', '/items/9', f'Origin: {OTHER}', 'Access-Control-Request-Method: PUT')
    check('preflight from another origin: 204 without CORS headers',
          status == 204 and not any(h.startswith('access-control') for h in headers), (status, headers))
elif args.mode == 'any':
    status, headers, body = request('GET', '/items', KEY, f'Origin: {OTHER}')
    check("'*': any origin, as *, without Vary", headers.get('access-control-allow-origin') == '*' and
          'vary' not in headers and 'access-control-allow-credentials' not in headers, headers)
    status, headers, body = request('OPTIONS', '/nowhere', f'Origin: {OTHER}', 'Access-Control-Request-Method: GET')
    check("'*' preflight for a path without routes: default methods", status == 204 and
          headers.get('access-control-allow-methods') == 'GET, HEAD, PUT, PATCH, POST, DELETE' and
          'access-control-max-age' not in headers, headers)
done()
