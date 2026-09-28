"""Static files: RPGAPI_serveStatic (app: static, the site run.sh makes in
the work directory)."""
from common import *

args = setup(__doc__)

def fetch(path, *headers, method='GET'):
    s = connect()
    s.sendall(f'{method} {path} HTTP/1.1\r\nHost: x\r\n'.encode() +
              b''.join(h.encode() + CRLF for h in headers) + CRLF)
    data = read_response(s, method.encode())
    s.close()
    return split(data)

for path, body, ctype in [('/web/', b'<h1>home</h1>', 'text/html; charset=utf-8'),
                          ('/web/index.html', b'<h1>home</h1>', 'text/html; charset=utf-8'),
                          ('/web/sub/', b'<h1>sub</h1>', 'text/html; charset=utf-8'),
                          ('/web/sub/page.txt', b'page', 'text/plain; charset=utf-8'),
                          ('/web/a%20b.txt', b'space', 'text/plain; charset=utf-8'),
                          ('/web/Gr%C3%BC%C3%9Fe.txt', b'umlauts', 'text/plain; charset=utf-8'),
                          ('/v2/static/sub/page.txt', b'page', 'text/plain; charset=utf-8'),
                          ('/assets/data.json', b'{"a": [1, 2, 3], "b": "x@y"}', 'application/json')]:
    status, headers, got = fetch(path)
    check(f'{path}: the file', (status, got, headers.get('content-type')) == (200, body, ctype),
          (status, got[:40], headers.get('content-type')))

for path, location in [('/web', '/web/'), ('/web?x=1', '/web/?x=1'), ('/web/sub', '/web/sub/')]:
    status, headers, _ = fetch(path)
    check(f'{path}: a directory without its / is redirected', (status, headers.get('location')) == (301, location),
          (status, headers))

for path in ['/web/.env', '/web/sub/../../secret.txt', '/web/%2e%2e/secret.txt', '/web/..%2fsecret.txt',
             '/web/sub/..%5c..%5csecret.txt', '/web/%00', '/web/nosub/', '/web/missing.txt', '/webx/index.html',
             '/web/.%2e/secret.txt']:
    status, _, got = fetch(path)
    check(f'{path}: not served', status == 404 and b'secret' not in got, (status, got[:40]))

status, _, got = fetch('/web/api')
check('a path with no file falls through to the routes', (status, got) == (200, b'api route'), (status, got))
status, _, _ = fetch('/web/index.html', method='POST')
check('POST is not served', status == 404, status)
status, headers, got = fetch('/web/sub/page.txt', method='HEAD')
check('HEAD: the length, no body', (status, headers.get('content-length'), got) == (200, '4', b''), (status, headers))
status, headers, _ = fetch('/assets/notes.txt')
etag = headers.get('etag', '')
status, _, got = fetch('/assets/notes.txt', f'If-None-Match: {etag}')
check('a conditional GET gets 304', etag != '' and status == 304, (etag, status))
status, headers, got = fetch('/assets/big.bin', 'Range: bytes=0-9')
check('a range gets 206', status == 206 and len(got) == 10, (status, len(got)))
done()
