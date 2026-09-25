# TODO

## Blocked
- [ ] Run `make test` (needs iRPGUnit in library `RPGUNIT`). iRPGUnit is not
  installed on PUB400. Needs another IBM i that has it, or iRPGUnit installed into
  a library we own on PUB400 (the Makefile hard-codes `RPGUNIT`)

## Done
- [x] Socket buffers: `data` in `RPGAPI_acceptRequest` / `RPGAPI_sendResponse` and
  the `QDCXLATE` prototype were `varchar`, so `%addr(data)` pointed at the length
  prefix and every request/response was off by two bytes. Changed back to
  `char(32766)`. Verified on PUB400 (2026-09-25): clean `HTTP/1.1 200 OK` and
  `404 Not Found` responses. Committed (438fbd8)
- [x] `Content-Length` counted the status line and headers, not just the body, and
  an extra CRLF was sent before the body (`\r\nhello`). Both fixed in
  `RPGAPI_sendResponse`. Verified on PUB400 (2026-09-25): `GET /hello` sends
  `Content-Length: 5` and exactly `hello`; the 404 sends `Content-Length: 0` and
  no body. Committed (438fbd8)
- [x] 404s sent the `Connection` header twice. `RPGAPI_setResponse` no longer adds
  one, and `RPGAPI_sendResponse` skips any `Connection` header a handler sets,
  since it always sends `Connection: close` itself. Verified on PUB400
  (2026-09-25): 404 and a handler setting `Connection: keep-alive` both send a
  single `Connection: close`; other handler headers still go out
- [x] A failing handler left the client hanging: `on-error` in `RPGAPI_start`
  built a 500 but never sent it or closed the socket. It now sends the 500, and
  just closes the socket if sending fails too. Verified on PUB400 (2026-09-25):
  a divide-by-zero handler used to time out the client after 10s, now returns
  `500 Internal Server Error` and the server keeps serving
- [x] Header and query values were cut off after a second `:` or `=`.
  `RPGAPI_parse` now splits on the first separator only. Verified on PUB400
  (2026-09-25): `?x=a=b` with `Host: 127.0.0.1:41731` used to give `x=a` and
  `host=127.0.0.1`, now gives `x=a=b` and `host=127.0.0.1:41731`. Unit tests
  added but not run (no iRPGUnit on PUB400)
- [x] `SO_REUSEADDR` was sent with `option_val` = 0, so it was off, and a restart
  soon after a run could not bind the port. `RPGAPI_setup` now passes 1 from a
  local variable, and `option_val` is gone from the public header. Verified on
  PUB400 (2026-09-25): restarting right after serving requests used to leave the
  server not listening; it now serves normally
- [x] Middleware re-ran for every route checked before a match, up to 250 times
  per request. `RPGAPI_start` now runs the matching middleware once, then looks
  for the route, and both loops stop at the first empty slot. Verified on PUB400
  (2026-09-25): with 6 routes, a global middleware ran 6 times for a request to
  the 6th route and 250 times for a 404; it now runs once per request, and a
  middleware returning `*off` still ends the request with its 401

## Small fixes (independent)
- [ ] `RPGAPI_setup` ignores the return codes of `socket`, `bind` and `listen`. When
  `bind` failed on PUB400 the job kept running but never listened, and every
  request was refused. It should fail loudly (or retry) instead

## Larger fixes
- [ ] Route matching: the `REGEXP_INSTR` pattern is not anchored (`/api/users` matches
  `/x/api/users/1`), and request values are put into the pattern before matching.
  Match segment by segment instead, which also removes the need for SQL
  (`RPGAPI_routeMatches` / `RPGAPI_mwMatches`)
- [ ] Only one `read()` per request, so anything larger than one packet is cut off.
  Read until the end of the headers, then `Content-Length` bytes of body
  (`RPGAPI_acceptRequest`)

## Features
- [ ] TLS for HTTPS traffic. On IBM i this likely means the GSKit secure sockets
  APIs (`gsk_*`) wrapped around the accepted socket, with the certificate coming
  from a DCM application ID or a keystore. Plain HTTP should still work.
- [ ] Handle multiple requests at a time. Right now `RPGAPI_start` is a single job
  that accepts, handles, and closes one connection before accepting the next, with
  a `listen` backlog of 1. Options: hand accepted sockets to a pool of worker jobs
  (`givedescriptor` / `takedescriptor`), or run threads (RPG procedures and
  handlers would need `thread(*concurrent)` or `*serialize`, and the global
  `RPGAPI_callback_ptr` / `RPGAPI_mwCallback_ptr` and `HTTP_messages` would have
  to stop being shared state).

## Cleanup
- [ ] `RPGAPI_CR` / `RPGAPI_LF` names are swapped (`rpgapi_h.rpgle`)
- [ ] `RPGAPI_setRoute` is documented but not exported in `RPGAPI_b.bnd`
- [ ] Add `RPGAPI_patch` (`HTTP_PATCH` exists but has no helper)
- [ ] Add a reason phrase for 202 `HTTP_ACCEPTED` in `RPGAPI_initHttp`
- [ ] `app.sqlrpgle` uses a relative `/copy './qrpglesrc/...'` path
- [ ] Move the response builder out of `RPGAPI_sendResponse` so the tests can reach it

## PUB400
- [ ] `BUILD`, `QRPGLESRC` and `RPGWEB` in library `RPGAPI` survive `CLRLIB`
  (`LONGDM` is not authorized to them). Removing them needs their owner, or
  authority granted to `LONGDM`
