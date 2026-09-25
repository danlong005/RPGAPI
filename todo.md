# TODO

## In progress: socket buffer bug
`data` in `RPGAPI_acceptRequest` / `RPGAPI_sendResponse` and the `QDCXLATE`
prototype were `varchar`, so `%addr(data)` pointed at the length prefix and every
request/response was off by two bytes.
- [x] Change them back to `char(32766)`
- [x] Compiles on PUB400
- [x] Verified at runtime on PUB400 (2026-09-25): `GET /hello` returns
  a clean `HTTP/1.1 200 OK` status line and the handler's headers and body, and
  an unknown route returns `404 Not Found`. The body still has an extra CRLF in
  front of it, a separate bug (fixed below)
- [ ] Run `make test` on PUB400 (needs iRPGUnit in library `RPGUNIT`)
- [x] Committed (438fbd8)

## Done
- [x] `Content-Length` counted the status line and headers, not just the body, and
  an extra CRLF was sent before the body (`\r\nhello`). Both fixed in
  `RPGAPI_sendResponse`. Verified on PUB400 (2026-09-25): `GET /hello` sends
  `Content-Length: 5` and exactly `hello`; the 404 sends `Content-Length: 0` and
  no body. Committed (438fbd8)

## Small fixes (independent)
- [ ] 404s send the `Connection` header twice (`Connection: close` from
  `RPGAPI_sendResponse`, `Connection: Close` from `RPGAPI_setResponse`)
- [ ] `on-error` in `RPGAPI_start` builds a 500 but never sends it or closes the
  client socket, so the client hangs and the descriptor leaks
- [ ] Header and query values are cut off after a second `:` or `=`
  (`Host: localhost:3000` becomes `localhost`, `a=b=c` becomes `b`); split on the
  first separator only (`RPGAPI_parse`)
- [ ] `SO_REUSEADDR` is sent with `option_val` = 0, so it is off (`RPGAPI_setup`)

## Larger fixes
- [ ] Middleware re-runs for every route checked before a match, up to 250 times per
  request. Run middleware once, then match the route (`RPGAPI_start`)
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
