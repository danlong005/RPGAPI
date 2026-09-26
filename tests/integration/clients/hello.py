"""The Quick Start app as documented, URL decoding, request.hostname,
redirects, statuses without a constant, requests without headers
(app: hello)."""
from common import *

args = setup(__doc__)

def body(path):
    return get(path)[2].decode()

check('/hello', body('/hello') == 'hello world')
check('/hello/{name}', body('/hello/Dan') == 'hello Dan')
check('unknown path is 404', get('/nothing')[0] == 404)
for path, want in [('/hello/J%C3%BCrgen', 'hello J\u00fcrgen'), ('/hello/a%20b', 'hello a b'),
                   ('/hello/a+b', 'hello a+b'), ('/hello/a%2Fb', 'hello a/b'), ('/hello/100%25', 'hello 100%'),
                   ('/hello/%FF', 'hello %FF'), ('/hello/%zz', 'hello %zz')]:
    got = body(path)
    check(f'param {path}', got == want, got)
got = body('/q?x=a+b&y=c%26d&z=%zz&w=100%25&u=J%C3%BCrgen&na%20me=v')
want = ('x=<a b> y=<c&d> z=<%zz> w=<100%> u=<J\u00fcrgen> na me=<v> '
        'raw=<x=a+b&y=c%26d&z=%zz&w=100%25&u=J%C3%BCrgen&na%20me=v>')
check('query names and values are decoded, query_string is not', got == want, got)
check('encoded = in a query value', 'y=<a=b>' in body('/q?y=a%3Db'))

for host, want in [('example.com:8080', 'example.com'), ('Api.Example.COM', 'Api.Example.COM'),
                   ('[::1]:41731', '[::1]'), ('[2001:db8::1]', '[2001:db8::1]')]:
    got = split(exchange(f'GET /host HTTP/1.0\r\nHost: {host}\r\n\r\n'.encode()))[2].decode()
    check(f'hostname for Host: {host}', got.startswith(f'hostname=<{want}>'), got)
status, _, got = split(exchange(b'GET /host HTTP/1.0\r\n\r\n'))
check('request with no headers at all', status == 200 and got.startswith(b'hostname=<>'), (status, got))

token = 'x' * 4990 + '0123456789'
got = get('/header?name=Authorization', f'Authorization: Bearer {token}')[2].decode()
check('5,007-character Authorization header arrives whole', got == 'len=5007 tail=0123456789', got)
cookie = 'a=' + 'y' * 2988 + 'ABCDEFGHIJ'
got = get('/header?name=cookie', f'Cookie: {cookie}')[2].decode()
check('3,000-character Cookie header arrives whole', got == 'len=3000 tail=ABCDEFGHIJ', got)
got = get('/header?name=X-Short', 'X-Short: abc')[2].decode()
check('short header', got == 'len=3', got)
got = get('/header?name=X-Missing')[2].decode()
check('missing header is empty', got == 'len=0', got)

status, headers, _ = get('/moved')
check('302 with Location', status == 302 and headers.get('location') == '/hello', (status, headers))
data = exchange(b'GET /conflict HTTP/1.1\r\nHost: x\r\n\r\n')
status, headers, got = split(data)
check('status without a constant (409) is sent', data.startswith(b'HTTP/1.1 409 \r\n') and got == b'taken', data[:40])
check('Content-Length / Transfer-Encoding set by a procedure are left out',
      headers.get('content-length') == '5' and 'transfer-encoding' not in headers, headers)
done()
