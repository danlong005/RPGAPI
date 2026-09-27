"""Route and middleware matching: whole paths, {params}, * segments,
middleware prefixes, route groups (app: routes)."""
from common import *

args = setup(__doc__)
cases = [('/api/users', 200, b'users'), ('/x/api/users/1', 404, b''), ('/api/users/1', 200, b'user 1'),
         ('/api/users/42/orders/7', 200, b'order 42 7'), ('/api/users/1/extra', 404, b''),
         ('/api/users/a(b', 200, b'user a(b'), ('/api/users/a.b', 200, b'user a.b'), ('/api/usersX', 404, b''),
         ('/admin', 401, b'denied'), ('/admin/x', 401, b'denied'), ('/x/admin', 404, b''),
         ('/administrator', 404, b''), ('/', 200, b'root'), ('/nothing', 404, b''),
         ('/api/users/', 200, b'users'), ('/api/users/7/', 200, b'user 7'),
         ('/secret', 404, b''), ('/secret/x', 401, b'denied')]
KEY = 'X-Key: k'
cases += [('/v1/items', 401, b'no key'),
          ('/items', 200, b'grouped /items id= shop=')]
keyed = [('/v1/items', 200, b'grouped /v1/items id= shop='),
         ('/v1/items/5', 200, b'grouped /v1/items/5 id=5 shop='),
         ('/v1', 200, b'grouped /v1 id= shop='),
         ('/v1/', 200, b'grouped /v1/ id= shop='),
         ('/shops/abc/items', 200, b'grouped /shops/abc/items id= shop=abc'),
         ('/v1x/items', 404, b''),
         ('/v1/shops/abc/items', 404, b'')]
for path, status, body in keyed:
    got_status, _, got_body = get(path, KEY)
    check(f'with a key: {path} -> {status}', (got_status, got_body) == (status, body), (got_status, got_body))
for path, status, body in cases:
    got_status, _, got_body = get(path)
    check(f'{path} -> {status}', (got_status, got_body) == (status, body), (got_status, got_body))
done()
