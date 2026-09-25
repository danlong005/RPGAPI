"""setRoute, patch, statuses, CR/LF, and complete responses byte for byte
(app: misc)."""
from common import *

args = setup(__doc__)

def raw(method, path):
    return exchange(f'{method} {path} HTTP/1.1\r\nHost: x\r\n\r\n'.encode())

check('PATCH route added with setRoute', split(raw('PATCH', '/viaset'))[::2] == (200, b'via setRoute'))
check('RPGAPI_patch route with a param', split(raw('PATCH', '/items/5'))[::2] == (200, b'patched 5'))
check('GET to a PATCH route is 404', split(raw('GET', '/items/5'))[0] == 404)
check('202 goes out as 202 Accepted', raw('GET', '/accepted').startswith(b'HTTP/1.1 202 Accepted\r\n'))
check('RPGAPI_CR + RPGAPI_LF is CR LF', split(raw('GET', '/crlf'))[2] == b'a\r\nb')

expected = {
    ('GET', '/headers'): b'HTTP/1.1 201 Created\r\nConnection: close\r\nContent-Type: text/plain; charset=utf-8\r\nX-Test: one two\r\nContent-Length: 7\r\n\r\nJ\xc3\xbcrgen',
    ('GET', '/accepted'): b'HTTP/1.1 202 Accepted\r\nConnection: close\r\nContent-Length: 6\r\n\r\nqueued',
    ('GET', '/crlf'): b'HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 4\r\n\r\na\r\nb',
    ('PATCH', '/items/5'): b'HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 9\r\n\r\npatched 5',
    ('GET', '/nothing'): b'HTTP/1.1 404 Not Found\r\nConnection: close\r\nContent-Length: 0\r\n\r\n',
}
for (method, path), want in expected.items():
    got = raw(method, path)
    check(f'{method} {path} byte for byte', got == want, got)
done()
