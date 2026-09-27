"""examples/notes-api.sqlrpgle: a JSON API whose JSON SQL builds
(JSON_OBJECT, JSON_ARRAYAGG) and reads (JSON_TABLE)."""
from common import *
import json

args = setup(__doc__)

def call(method, path, data=None):
    body = json.dumps(data).encode() if isinstance(data, dict) else (data or b'')
    headers = ['Content-Type: application/json', f'Content-Length: {len(body)}'] if body else []
    status, response_headers, raw = get(path, *headers, method=method, body=body)
    try:
        return status, json.loads(raw) if raw else None
    except ValueError:
        return status, raw

check('an empty list is []', call('GET', '/notes') == (200, []))
title, text = 'Jürgen\'s "list"', 'milk\\bread\nand eggs'
status, data = call('POST', '/notes', {'title': title, 'text': text})
check('POST: 201 with the new id', (status, data) == (201, {'id': 1}), (status, data))
call('POST', '/notes', {'title': 'second'})
status, data = call('GET', '/notes/1')
check('JSON_TABLE read the body and JSON_OBJECT escaped it: quotes, backslash, newline, umlaut',
      status == 200 and data.get('title') == title and data.get('text') == text, (status, data))
status, data = call('GET', '/notes')
check('JSON_ARRAYAGG: both notes in order', status == 200 and [n['id'] for n in data] == [1, 2] and
      data[1]['text'] == '', (status, data))
status, data = call('PUT', '/notes/2', {'title': 'second', 'text': 'changed'})
check('PUT changes a note', status == 200 and call('GET', '/notes/2')[1].get('text') == 'changed', (status, data))
check('DELETE: 204, then 404', call('DELETE', '/notes/2')[0] == 204 and call('GET', '/notes/2')[0] == 404)
check('no title: 400', call('POST', '/notes', {'text': 'x'})[0] == 400)
check('not JSON: 400', call('POST', '/notes', b'title=x')[0] == 400)
check('an id that is not a number: 400', call('GET', '/notes/abc')[0] == 400)
done()
