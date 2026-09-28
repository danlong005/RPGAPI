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

for cookie, name, want in [('a=1; session=abc%20def; quoted="x y"; empty=', 'session', 'abc def'),
                           ('a=1; session=abc%20def; quoted="x y"; empty=', 'quoted', 'x y'),
                           ('a=1; session=abc%20def; quoted="x y"; empty=', 'empty', ''),
                           ('a=1; session=abc%20def; quoted="x y"; empty=', 'missing', ''),
                           ('ab=2; a=1', 'a', '1'),
                           ('A=upper; a=lower', 'a', 'lower'),
                           ('u=J%C3%BCrgen', 'u', 'J\u00fcrgen')]:
    got = get(f'/cookie/get?name={name}', f'Cookie: {cookie}')[2].decode()
    check(f'getCookie {name} from "{cookie}"', got == f'<{want}>', got)
check('getCookie without a Cookie header', get('/cookie/get?name=a')[2] == b'<>')

import email.utils, re
data = exchange(b'GET /cookie/set HTTP/1.1\r\nHost: x\r\n\r\n')
lines = [l for l in data.split(CRLF + CRLF)[0].decode().split('\r\n') if l.lower().startswith('set-cookie:')]
check('two Set-Cookie headers', len(lines) == 2, lines)
session = lines[0][len('Set-Cookie: '):] if lines else ''
m = re.fullmatch(r'session=hello%20world; Max-Age=3600; Path=/app; Expires=(.+); HttpOnly; Secure; SameSite=Lax', session)
check('setCookie with every option', m is not None, session)
if m:
    expires = email.utils.parsedate_to_datetime(m.group(1)).timestamp()
    check('Expires is Max-Age from now', abs(expires - (time.time() + 3600)) < 10, m.group(1))
check('setCookie with no options: encoded, Path=/', len(lines) > 1 and
      lines[1] == 'Set-Cookie: plain=J%C3%BCrgen%3B%20x%3D1; Path=/', lines[1:])
data = exchange(b'GET /cookie/clear HTTP/1.1\r\nHost: x\r\n\r\n')
check('clearCookie', b'Set-Cookie: session=; Max-Age=0; Path=/app; Expires=Thu, 01 Jan 1970 00:00:00 GMT\r\n' in data,
      data.split(CRLF + CRLF)[0])
check('a cookie name with a space: 500', get('/cookie/bad')[0] == 500)

import subprocess, os
jar = args.work + '/cookies.txt'
base = f'http://127.0.0.1:{args.port}'
subprocess.run(['curl', '-s', '-c', jar, base + '/cookie/set'], capture_output=True)
got = subprocess.run(['curl', '-s', '-b', jar, base + '/cookie/get?name=plain'], capture_output=True).stdout.decode()
check('curl cookie jar round trip', got == '<J\u00fcrgen; x=1>', got)
if os.path.exists(jar):
    os.remove(jar)

    # the head and body go in one write: a body is not held back until the
    # client acknowledges the head (Nagle and delayed ACK, about 200ms)
for path in ['/hello/Dan', '/nope']:
    ms = curl_time(path)
    check(f'{path} arrives in under 50ms ({ms:.1f}ms)', ms < 50)

FORM = 'application/x-www-form-urlencoded'
def form(query, body, content_type=FORM):
    body = body.encode() if isinstance(body, str) else body
    return get(f'/form?{query}', f'Content-Type: {content_type}', f'Content-Length: {len(body)}',
               method='POST', body=body)[2].decode()
fields = 'name=J%C3%BCrgen+Long&comment=a%26b%3Dc+100%25&tag=x&tag=y&empty=&flag'
for query, want in [('field=name', 'J\u00fcrgen Long'), ('field=comment', 'a&b=c 100%'),
                    ('field=tag', 'x'), ('field=tag&n=2', 'y'), ('field=tag&n=3', ''),
                    ('field=NAME', 'J\u00fcrgen Long'), ('field=empty', ''), ('field=flag', ''),
                    ('field=missing', '')]:
    got = form(query, fields)
    check(f'getFormParam {query}', got == f'<{want}>', got)
check('Content-Type with a charset', form('field=tag', 'tag=z', FORM + '; charset=UTF-8') == '<z>')
check('a body that is not a form gives nothing', form('field=a', 'a=1', 'application/json') == '<>')
long_value = 'w' * 20000
got = form('field=text', 'text=' + long_value)
check('a 20,000-character field', got == f'<{long_value}>', len(got))
got = form('field=last', 'pad=' + 'p' * 40000 + '&last=end')
check('a field after 40,000 bytes of body', got == '<end>', got[:40])
import subprocess
out = subprocess.run(['curl', '-s', '--data-urlencode', 'comment=Gr\u00fc\u00dfe & more; 50% off',
                      f'http://127.0.0.1:{args.port}/form?field=comment'], capture_output=True).stdout.decode()
check('curl --data-urlencode round trip', out == '<Gr\u00fc\u00dfe & more; 50% off>', out)

import base64
def auth(value=None):
    status, headers, body = get('/auth', *([f'Authorization: {value}'] if value is not None else []))
    return status, body.decode(), headers
def basic(text):
    return 'Basic ' + base64.b64encode(text.encode()).decode()
for header, want in [(basic('user:pass'), 'basic:user|pass'),
                     (basic('a:b:c'), 'basic:a|b:c'),
                     (basic('user:'), 'basic:user|'),
                     (basic('J\u00fcrgen:Gr\u00fc\u00dfe'), 'basic:J\u00fcrgen|Gr\u00fc\u00dfe'),
                     ('basic ' + base64.b64encode(b'lower:case').decode(), 'basic:lower|case'),
                     ('Bearer abc.def-ghi_jkl', 'bearer:abc.def-ghi_jkl'),
                     ('bearer   spaced', 'bearer:spaced')]:
    status, body, _ = auth(header)
    check(f'Authorization "{header[:30]}" gives {want}', (status, body) == (200, want), (status, body))
for header in [None, 'Basic !!!notbase64', basic('nocolon'), 'Basic ', 'Bearer ', 'Digest x=1', 'Bearerabc']:
    status, body, headers = auth(header)
    check(f'Authorization {header!r}: nothing, 401 with a challenge',
          (status, body) == (401, 'none') and headers.get('www-authenticate') == 'Basic realm="test"', (status, body))
token = 'e' * 5000
check('a 5,000-character bearer token', auth('Bearer ' + token)[1] == 'bearer:' + token)
import subprocess
out = subprocess.run(['curl', '-s', '-u', 'curl user:p@ss:w0rd', f'http://127.0.0.1:{args.port}/auth'],
                     capture_output=True).stdout.decode()
check('curl -u', out == 'basic:curl user|p@ss:w0rd', out)

    # IBM i user profiles. Never a wrong password for a real profile: it
    # counts toward QMAXSIGN and could disable it
import os
def profile(user, password):
    return get('/profile', 'Authorization: ' + basic(f'{user}:{password}'))[2].decode()
got = profile('NOSUCHU1', 'whatever')
check('a user that does not exist: no, CPF22E2 as for a wrong password', got == 'no:CPF22E2', got)
for user, password in [('LONGDM', '*NOPWD'), ('longdm', ' *nopwdchk '), ('LONGDM', '*NOPWDSTS'),
                       ('*CURRENT', 'x'), ('LONGDM', ''), ('TOOLONGNAME1', 'x'), ('A B', 'x')]:
    got = profile(user, password)
    check(f'refused before asking the system: {user!r} / {password!r}', got == 'no:', got)
if os.environ.get('RPGAPI_TEST_USER') and os.environ.get('RPGAPI_TEST_PASSWORD'):
    got = profile(os.environ['RPGAPI_TEST_USER'], os.environ['RPGAPI_TEST_PASSWORD'])
    check('the right password for RPGAPI_TEST_USER', got == 'ok', got)
else:
    print('SKIP the right password: set RPGAPI_TEST_USER and RPGAPI_TEST_PASSWORD for a test profile')

    # request data in a response header cannot add headers or end the head
data = exchange(b'GET /echo-header?v=a%0D%0AX-Injected:%20yes%0d%0a%0d%0a<html> HTTP/1.1\r\nHost: x\r\n\r\n')
head = data.split(CRLF + CRLF)[0].decode(errors='replace').split('\r\n')
check('CR LF in a header value cannot inject a header',
      not any(line.lower().startswith('x-injected') for line in head) and
      any(line.startswith('X-Echo: a') and 'X-Injected' in line for line in head) and
      data.endswith(b'echoed'), head)

check('no security headers unless the app asks for them',
      not any(h in get('/hello')[1] for h in ['x-content-type-options', 'content-security-policy', 'x-frame-options']))

status, headers, _ = get('/moved')
check('302 with Location', status == 302 and headers.get('location') == '/hello', (status, headers))
data = exchange(b'GET /conflict HTTP/1.1\r\nHost: x\r\n\r\n')
status, headers, got = split(data)
check('status without a constant (409) is sent', data.startswith(b'HTTP/1.1 409 \r\n') and got == b'taken', data[:40])
check('Content-Length / Transfer-Encoding set by a procedure are left out',
      headers.get('content-length') == '5' and 'transfer-encoding' not in headers, headers)
done()
