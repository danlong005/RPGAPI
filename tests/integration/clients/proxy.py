"""The client's address, request.remote_ip, and X-Forwarded-For from trusted
proxies (app: hello). Mode "none": no trusted proxies; "trusted": 127.0.0.1
and 10.0.0.1, so this client counts as a proxy; "any": '*'."""
from common import *

args = setup(__doc__)

def ip(*headers):
    return get('/ip', *headers)[2].decode()

LOCAL = '127.0.0.1'
check('without X-Forwarded-For: the connection\'s address', ip() == f'{LOCAL}|{LOCAL}', ip())

if args.mode == 'none':
    got = ip('X-Forwarded-For: 203.0.113.9')
    check('X-Forwarded-For from a client that is not a trusted proxy is ignored', got == f'{LOCAL}|{LOCAL}', got)

if args.mode == 'trusted':
    for forwarded, client in [('203.0.113.9', '203.0.113.9'),
                              ('6.6.6.6, 203.0.113.9', '203.0.113.9'),
                              ('203.0.113.9, 10.0.0.1', '203.0.113.9'),
                              ('10.0.0.1', '10.0.0.1'),
                              ('2001:db8::1', '2001:db8::1'),
                              ('203.0.113.9, unknown', LOCAL)]:
        got = ip(f'X-Forwarded-For: {forwarded}')
        check(f'X-Forwarded-For "{forwarded}" gives {client}', got == f'{client}|{LOCAL}', got)

if args.mode == 'any':
    got = ip('X-Forwarded-For: 6.6.6.6, 203.0.113.9')
    check('trusting any proxy: the leftmost address', got == f'6.6.6.6|{LOCAL}', got)
done()
