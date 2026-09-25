"""Route and middleware matching: whole paths, {params}, * segments,
middleware prefixes (app: routes)."""
from common import *

args = setup(__doc__)
cases = [('/api/users', 200, b'users'), ('/x/api/users/1', 404, b''), ('/api/users/1', 200, b'user 1'),
         ('/api/users/42/orders/7', 200, b'order 42 7'), ('/api/users/1/extra', 404, b''),
         ('/api/users/a(b', 200, b'user a(b'), ('/api/users/a.b', 200, b'user a.b'), ('/api/usersX', 404, b''),
         ('/admin', 401, b'denied'), ('/admin/x', 401, b'denied'), ('/x/admin', 404, b''),
         ('/administrator', 404, b''), ('/', 200, b'root'), ('/nothing', 404, b''),
         ('/api/users/', 200, b'users'), ('/api/users/7/', 200, b'user 7'),
         ('/secret', 404, b''), ('/secret/x', 401, b'denied')]
for path, status, body in cases:
    got_status, _, got_body = get(path)
    check(f'{path} -> {status}', (got_status, got_body) == (status, body), (got_status, got_body))
done()
