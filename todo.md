# TODO

## Blocked
- [ ] Run `make test` (needs iRPGUnit in library `RPGUNIT`). iRPGUnit is not
  installed on PUB400. Needs another IBM i that has it, or iRPGUnit installed into
  a library we own on PUB400 (the Makefile hard-codes `RPGUNIT`)
  The test program is compiled with the default `TGTCCSID`, so on a system
  whose job CCSID is not 37 it probably needs `TGTCCSID(*JOB)` as well

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
- [x] `RPGAPI_setup` ignored the return codes of `socket`, `setsockopt`, `bind`
  and `listen`, so a server whose port was taken kept running without listening.
  Each failure now closes the socket and ends `RPGAPI_start` with `CPF9898`
  naming the call, port and `errno` text. Verified on PUB400 (2026-09-25): a
  second server on a port already in use used to stay active with nothing in
  its job log; it now ends at once with `bind() failed for port 41731: Address
  already in use. (errno 3420).` and the first server keeps serving
- [x] Route matching used an unanchored `REGEXP_INSTR` pattern with request
  values put into it. `RPGAPI_routeMatches` / `RPGAPI_mwMatches` now compare
  `/` segments (`{name}` captures one, `*` matches one): routes must match the
  whole path, middleware its leading segments. No SQL is left, so the module is
  now `rpgapi.rpgle` built with `CRTRPGMOD`; built with `CRTSQLRPGI` it read
  `{`/`}` differently from a `CRTBNDRPG` app in CCSID 273, and `{name}` never
  matched. Verified on PUB400 (2026-09-25): `/api/users` used to answer
  `/x/api/users/1`, `/api/users/1`, `/api/usersX` and the `{id}` routes, an
  `/admin` middleware blocked `/administrator` and `/x/admin`, and a `/` route
  answered every path. Now each goes to the right route or 404s, params with
  `(` or `.` work, `/admin/x` still gets the 401. Unit tests added but not run
- [x] `RPGAPI_acceptRequest` did one `read()`, so a request in more than one
  piece was cut off, and it translated `%len(%trim(data))` bytes of ASCII,
  dropping a trailing `@` (x'40', the EBCDIC blank). It now reads until the end
  of the headers, then until `Content-Length` bytes of body (up to the 32000
  bytes `RPGAPI_parse` takes), and translates exactly what arrived. Verified on
  PUB400 (2026-09-25) with a client sending pieces 0.5s apart: a split request
  line used to get a 500 and a 20000-byte body sent after the headers arrived
  as `len=0` (7000 when sent in 3 pieces); now both work and the body is all
  20000 bytes, as is `hello world@` (was 11 bytes)
- [x] `RPGAPI_sendResponse` wrote `%len(%trim(data))` bytes after translating
  to ASCII, so a trailing `@` (x'40', the EBCDIC blank) was not sent although
  `Content-Length` counted it. The length is now taken before translating.
  Verified on PUB400 (2026-09-25): a body `user@example.com @@` used to arrive
  as 17 bytes against `Content-Length: 19`; now all 19 arrive
- [x] `RPGAPI_parse` passed the body through `RPGAPI_cleanString`, which removed
  every CR and LF and trimmed it. The body is now everything after the blank
  line, as sent. Verified on PUB400 (2026-09-25): a 35-byte multi-line JSON
  body used to arrive as 30 bytes on one line, and `  two spaces each side  `
  lost its edge spaces; both now arrive unchanged. Unit test added but not run
- [x] Requests and responses were translated byte for byte with the `QDCXLATE`
  tables `QTCPEBC` / `QTCPASC`: no UTF-8, `Content-Length` counted EBCDIC
  characters, and `[ ] |` came out wrong. They are now converted between UTF-8
  and the job's CCSID with `iconv` (`RPGAPI_convert`), and `Content-Length` is
  the UTF-8 byte count. The library is compiled with `TGTCCSID(*JOB)`, and apps
  have to be too (README, Character sets): from an IFS file the default gives
  CCSID 37 literals whatever the job CCSID. Verified on PUB400 (2026-09-25, job
  CCSID 273): a JSON literal with `[ ] { } @ \ |` and `ü` used to go out with
  `[` as x'9B', `]` as `!`, `|` as x'D9' and `ü` as x'F5'; now it is exact
  UTF-8 with a matching `Content-Length`, and a UTF-8 `Jürgen` in a request
  arrives as 6 characters, not 7. The earlier request, `@` and route tests still
  pass. A default-compiled app on a 273 system now loses `{name}` routes (seen)
- [x] No read timeout: a client that sent nothing, less than its
  `Content-Length`, or one byte at a time held the server (one connection at a
  time) for as long as it liked. `RPGAPI_acceptRequest` now `poll`s before each
  read against a 30-second deadline for the whole request
  (`RPGAPI_READ_TIMEOUT`), and `RPGAPI_start` closes the connection without a
  response when no complete headers arrived. Verified on PUB400 (2026-09-25):
  with each kind of stalled client, a GET queued behind it got no answer in 65s
  (the dripping client held the server 65s); now it is answered 29s after it
  connects. Earlier request, CCSID and route tests still pass
- [x] `RPGAPI_CR` was x'25' (LF) and `RPGAPI_LF` x'0D' (CR). Swapped. Verified
  on PUB400 (2026-09-25): a body `'a' + RPGAPI_CR + RPGAPI_LF + 'b'` used to go
  out as `a\n\rb`, now `a\r\nb`
- [x] 202 `HTTP_ACCEPTED` had no reason phrase in `RPGAPI_initHttp`, and a
  response with that status failed with a 500. Added `Accepted`. Verified on
  PUB400 (2026-09-25): a 202 handler used to get `500 Internal Server Error`,
  now `202 Accepted` with its body
- [x] `RPGAPI_setRoute` was documented but not exported, so an app calling it
  failed to bind, and `HTTP_PATCH` had no helper. Both are exported now
  (`RPGAPI_patch` is new); the old export list is kept as `PGMLVL(*PRV)`, so
  programs bound before keep running. Verified on PUB400 (2026-09-25): a test
  app using both used to fail to build; now a PATCH route added with each
  answers, a GET to it 404s, and the old build's signature is the new service
  program's previous one

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
- [ ] `app.sqlrpgle` uses a relative `/copy './qrpglesrc/...'` path
- [ ] Move the response builder out of `RPGAPI_sendResponse` so the tests can reach it

## PUB400
- [ ] `BUILD`, `QRPGLESRC` and `RPGWEB` in library `RPGAPI` survive `CLRLIB`
  (`LONGDM` is not authorized to them). Removing them needs their owner, or
  authority granted to `LONGDM`
