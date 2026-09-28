"""Security headers, RPGAPI_setSecurityHeaders (app: secure). Mode: blank
for the default Content-Security-Policy, "custom" or "none"."""
from common import *

args = setup(__doc__)

DEFAULT_CSP = ("default-src 'self';base-uri 'self';font-src 'self' https: data:;form-action 'self';"
               "frame-ancestors 'self';img-src 'self' data:;object-src 'none';script-src 'self';"
               "script-src-attr 'none';style-src 'self' https: 'unsafe-inline';upgrade-insecure-requests")
OTHERS = {'cross-origin-opener-policy': 'same-origin', 'cross-origin-resource-policy': 'same-origin',
          'origin-agent-cluster': '?1', 'referrer-policy': 'no-referrer', 'x-content-type-options': 'nosniff',
          'x-dns-prefetch-control': 'off', 'x-download-options': 'noopen', 'x-frame-options': 'SAMEORIGIN',
          'x-permitted-cross-domain-policies': 'none', 'x-xss-protection': '0'}
csp = {'': DEFAULT_CSP, 'custom': "default-src 'none'", 'none': None}[args.mode]

def head_lines(path, method='GET'):
    data = exchange(f'{method} {path} HTTP/1.1\r\nHost: x\r\n\r\n'.encode())
    lines = data.split(CRLF + CRLF)[0].decode().split('\r\n')[1:]
    return {l.split(':', 1)[0].lower(): l.split(':', 1)[1].strip() for l in lines}, lines

for path, method in [('/plain', 'GET'), ('/plain', 'HEAD'), ('/nothing', 'GET'), ('/stream', 'GET')]:
    headers, _ = head_lines(path, method)
    check(f'{method} {path}: the security headers',
          all(headers.get(k) == v for k, v in OTHERS.items()) and headers.get('content-security-policy') == csp,
          headers)
    check(f'{method} {path}: no Strict-Transport-Security over plain HTTP',
          'strict-transport-security' not in headers, headers)

headers, lines = head_lines('/own')
names = [l.split(':', 1)[0].lower() for l in lines]
check('headers a route sets itself win, and are not sent twice',
      headers.get('content-security-policy') == 'frame-ancestors *' and
      headers.get('x-frame-options') == 'ALLOW-FROM x' and
      names.count('content-security-policy') == 1 and names.count('x-frame-options') == 1 and
      headers.get('x-content-type-options') == 'nosniff', lines)
done()
