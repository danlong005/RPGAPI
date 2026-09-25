# TODO

## Blocked
- [ ] Run `make test` (needs iRPGUnit in library `RPGUNIT`). The integration
  tests (`tests/integration`, `make integration`) run without it. iRPGUnit is not
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
- [x] `app.sqlrpgle` used `/copy './qrpglesrc/rpgapi_h.rpgle'`, which only
  resolves when compiling from the checkout's root. It now includes
  `rpgapi_h.rpgle` through `INCDIR`, and a comment gives the build command.
  Verified on PUB400 (2026-09-25): compiled from `/home/LONGDM` it used to fail
  with a severity 40 error, now the program is created
- [x] The status line and headers are built by `RPGAPI_buildHead` (exported
  from the module, not the service program) instead of inside
  `RPGAPI_sendResponse`, and have unit tests (not run). Verified on PUB400
  (2026-09-25): five raw responses (custom and `Connection` headers, UTF-8
  body, 202, CR/LF, 404) are byte for byte the same before and after
- [x] `listen` had a backlog of 1, so connections arriving while the server was
  busy were refused. It is now `SOMAXCONN` (512). Verified on PUB400
  (2026-09-25): with one slow client being served, 9 of 10 clients connecting
  at once were reset; now all 10 are answered once it finishes
- [x] Handle several requests at once. `RPGAPI_start(app : port : jobs)`
  spawns jobs - 1 more jobs running the program the job was started with (found
  with `QWVRCSTK`); each inherits the listening socket, registers its routes and
  accepts from it. The socket is non-blocking and waited on with `poll`, so
  jobs that lose a connection to another go back to waiting; workers end within
  5s of the main job. Verified on PUB400 (2026-09-25): 8 requests that take 3s
  each took 24.4s with 1 job and 6.1s with 4 (2 per job); behind a client
  sending 1 byte every 2s, other requests were answered in 3.0s; all 4 jobs had
  the main job's name and library list; ending the main job ended the rest and
  freed the port. Request, route, timeout and backlog tests still pass with 1
- [x] Phase A, larger requests: requests over 32,000 bytes were cut off
  silently, chunked bodies arrived empty and `Expect: 100-continue` was never
  answered. The body is now read into the heap up to a limit (1MB,
  `RPGAPI_setMaxRequestSize`), from `Content-Length` or chunked encoding, and
  read with `RPGAPI_readBody` (text, never splitting a UTF-8 character) or
  `RPGAPI_readBodyBytes` (raw); `request.body` still has it when it fits. Too
  large gets 413 (before the body is sent, with 100-continue), headers over
  32,000 bytes 431, bad lengths or chunks 400, other transfer encodings 501.
  Verified on PUB400 (2026-09-25): a declared 2MB body used to reach the
  handler cut to 31,943 bytes with a 200, a chunked body arrived as `len=0`,
  and 100-continue went unanswered for 3s. Now: 500,000 and 256,000-byte
  binary bodies and a 300,000-byte chunked body (also sent in 3 pieces)
  arrive with matching checksums, 100,000 u-umlauts read as 100,000
  characters in 13 pieces, 100 Continue is immediate, and 413/431/400/501 go
  out where due, also with a 1,000-byte limit. All earlier tests pass, raw
  responses are unchanged and the service program keeps both earlier
  signatures
- [x] Phase B, large responses: bodies over 32,000 characters could not be
  sent at all. `RPGAPI_beginResponse` / `RPGAPI_write` (text, to UTF-8) /
  `RPGAPI_writeBytes` (raw) / `RPGAPI_endResponse` stream a body in 32KB
  chunks, or with a `Content-Length` when given, or until close for HTTP/1.0;
  `RPGAPI_sendFile` streams an IFS file with a Content-Type from its extension.
  Converters are now opened once per job instead of per call. Verified on
  PUB400 (2026-09-25): 50,000 lines (539KB chunked) in 1.6s, also through curl
  and over HTTP/1.0; a 20,000-row JSON array (1.29MB) parses with its u-umlaut
  and `| \ @` intact; 2MB and 20MB files arrive with matching SHA-256 (20MB in
  1.4s); missing files and `..` paths get the handler's 404; write without
  begin is a 500; a failure mid-stream leaves an incomplete chunked response.
  All earlier tests pass, raw responses are unchanged, and the service program
  keeps its earlier signatures
- [x] No write timeout: a client that stopped reading a large response held
  its job in `write()` for as long as it liked. Connections now stay
  non-blocking, and `RPGAPI_sendAll` waits for room with `poll(POLLOUT)` for up
  to 30s (`RPGAPI_WRITE_TIMEOUT`) with no progress before giving up; later
  writes to that connection do nothing (not even the conversion). Verified on
  PUB400 (2026-09-25): with one job, a request queued behind a client that
  stopped reading a 22MB stream got no answer in 65s; now it is answered after
  34s. A slow but steady reader still gets the whole 1.09MB. All earlier tests
  pass and raw responses are unchanged
- [x] `RPGAPI_sendFile` ranges and caching: it now sends `Last-Modified`, a weak
  `ETag` from size and mtime (`fstat`), `Accept-Ranges` and a default
  `Cache-Control`; answers `If-None-Match` / `If-Modified-Since` with 304, a
  single `Range` with 206 (416 outside the file) and honours `If-Range`.
  Verified on PUB400 (2026-09-25) against a 2MB file: ETag and Last-Modified
  match the file's stat; 304 for a matching ETag, one in a list, `*`, and a
  date at or after the mtime; 200 for others, a junk date, and when
  If-None-Match does not match even if the date would; 206 with exact bytes for
  `0-99`, `1999900-`, `-500` and an end past the file; 416 for `5000000-`;
  the whole file for `100-50`, several ranges and `items=`; If-Range by ETag or
  date; a handler's Cache-Control kept; after touching the file the old ETag
  gets a 200. All earlier tests pass and raw responses are unchanged
- [x] Phase C, uploads beyond the in-memory limit: with
  `RPGAPI_setMaxUploadSize` (off by default), a body over the request limit is
  left on the connection and read by the procedure through `RPGAPI_readBody` /
  `RPGAPI_readBodyBytes` / the new `RPGAPI_saveBody` (to an IFS file); chunked
  bodies switch over when they outgrow memory. 100 Continue waits for the
  first read; too large, bad or stalled bodies end the procedure and get 413,
  400 or 408; unread bodies are drained briefly before the close. Verified on
  PUB400 (2026-09-25): 50MB uploads arrive intact (checksum, and SHA-256 of the
  saved file) with the job's temporary storage at 22MB throughout (19MB
  before); 5MB chunked switches over (bodyLength -1, then 5,000,000); 1.5M
  u-umlauts across socket reads count 1.5M; 200MB declared gets 413 at once;
  with Expect, a refusing handler's 403 arrives without 100 Continue; an
  ignored 10MB body still lets the response through; a stalled upload gets
  408; with a 3MB limit, 4MB gets 413 (declared and chunked) and 2.5MB chunked
  passes. All earlier tests pass, raw responses are unchanged, and the service
  program keeps its earlier signatures
- [x] A response with a status that has no reason phrase in `HTTP_messages`
  (409, 418, ...) failed with a 500: the table had no `inz`, so looking the
  status up ran into entries of blanks, which are not valid zoned numbers.
  This was also the real cause of the earlier 202 failure. Verified on PUB400
  (2026-09-25): a 409 handler used to get `500 Internal Server Error`, now
  `HTTP/1.1 409` with its body; earlier tests pass and raw responses are
  unchanged
- [x] Route params and query names and values were handed over as sent. They
  are now URL decoded (`RPGAPI_urlDecode`): `%XX` escapes as UTF-8 bytes,
  converted to the job's CCSID, and `+` as a space in queries only; invalid
  escapes or bytes are left as sent. Matching still uses the raw path, and
  `request.route` / `query_string` stay raw. Verified on PUB400 (2026-09-25):
  `J%C3%BCrgen`, `a%20b`, `a%2Fb` (one segment) and `100%25` used to arrive
  as sent and now arrive as `Jurgen` with u-umlaut, `a b`, `a/b` and `100%`;
  `a+b` stays in a param; query `a+b`, `c%26d`, `a%3Db` and the key `na%20me`
  decode; `%FF` and `%zz` stay. Unit tests added (not run). Earlier tests pass
  and raw responses are unchanged
- [x] A request with no headers at all (`GET / HTTP/1.0` and a blank line)
  got a 500: `RPGAPI_parse` cut the headers out with a negative length. It now
  takes them as empty. Verified on PUB400 (2026-09-25): 500 before, 200 now.
  Unit test added (not run)
- [x] `request.hostname` was never filled in. It is now the `Host` header
  without its port, as Express's `req.hostname`, keeping an IPv6 address in
  its brackets. Verified on PUB400 (2026-09-25): blank before for every Host;
  now `127.0.0.1:41731` gives `127.0.0.1`, `example.com:8080` `example.com`,
  `[::1]:41731` `[::1]`, `[2001:db8::1]` itself, a lower-case `host:` header
  works, the case is kept, and no Host gives blank. Unit test added (not run).
  Earlier tests pass and raw responses are unchanged
- [x] `multipart/form-data`: `RPGAPI_nextPart` walks the parts of the body
  (name, filename, content type in `RPGAPI_Part`), and `RPGAPI_readPart`
  (text) / `RPGAPI_readPartBytes` / `RPGAPI_savePart` (IFS file) read the
  current one; unread data is skipped. Parts stream over the body readers, so
  in-memory, streamed and chunked bodies all work, with a lookahead buffer
  that finds delimiters split across reads. Not multipart gives no parts;
  invalid multipart a 400. Verified on PUB400 (2026-09-25): curl -F with a
  UTF-8 field, a 2MB file, a PNG and an empty field (files match); a body by
  hand with preamble, epilogue, quoted boundary, a field with CR LF and
  near-boundaries, and 3MB with fake delimiters, sent whole and in 40 pieces
  (file matches, readPartBytes checksum matches, `Gruesse;1.txt` name with its
  u-umlaut and `;` kept); only the third part; JSON gives 0 parts; missing
  closing boundary and no boundary give 400; a 30MB file through curl -F,
  streamed, matches. All earlier tests pass and raw responses are unchanged
- [x] Integration tests in `tests/integration`: the PUB400 test apps and
  clients, made into suites that start each app in a batch job with settings
  from a data area and print PASS/FAIL, run by `run.sh` (or `make
  integration`) with LIB, PORT and WORK as settings. Every check that was run
  by hand for the fixes and features above is in them
- [x] Settings in `RPGAPI_App`, and logging. The app now holds `jobs`,
  `log_level`, `max_request_size`, `max_upload_size`, `read_timeout`,
  `write_timeout` and the TLS settings (0/blank: defaults); the setters take
  the app first, `RPGAPI_setLogLevel` and `RPGAPI_setTimeouts` are new, and the
  timeouts are settable. Breaking: programs must be recompiled, so the `*PRV`
  export lists were dropped. Logging (off, ERROR, WARN, INFO, DEBUG) writes
  `RPGAPI <LEVEL> #n:` informational messages to the serving job's log: failures
  with the exception message (from `QMHRCVPM`), refusals and timeouts, one line
  per request, and at DEBUG connections, headers (credentials masked), routing,
  body handling, parts and sendFile decisions. Verified on PUB400 (2026-09-25):
  for the same 9 events, OFF 0 messages, ERROR 1 (the handler's MCH1211),
  WARN 4, INFO 12, DEBUG 51; route `{name}` prints as sent in the job log;
  `app.jobs = 2` runs 2 jobs, each logging, both ending with the main job; a
  3s read timeout closes an idle client after 3s; TLS setup errors unchanged;
  all earlier tests pass and raw responses are unchanged
- [x] `RPGAPI_parse` split the request line, the query string and the headers
  into one array, and `%split` leaves the elements it does not fill as they
  were: parts of the request line turned up as extra query params (`?a=1&b=2`
  also had one named `HTTP/1.1`) and headers. The array is cleared before each
  split. Found through the new DEBUG logging. Verified on PUB400 (2026-09-25):
  the extra query param is gone; routes, URL decoding and request tests pass,
  raw responses unchanged. Unit test added (not run)
- [x] TLS (HTTPS) through GSKit: `RPGAPI_setTlsApplication` (DCM application
  ID) or `RPGAPI_setTlsKeystore` (store, password, label) before
  `RPGAPI_start`; each job opens a server environment, each connection gets a
  handshake (30s limit, failures dropped), and all reads and writes go through
  `RPGAPI_connectionRead` / `Write`, which use GSKit for TLS. Verified on
  PUB400 (2026-09-25) as far as it allows: builds and binds against GSKit;
  setup failures end `RPGAPI_start` with GSKit's reason (unregistered ID:
  6002, missing keystore: 202, a .p12: 406 with the errno text); without TLS
  every earlier test passes, over the new read/write layer, and raw responses
  are unchanged. The README has the DCM setup steps

## Features
- [ ] Run HTTPS end to end on a system with DCM access: assign a certificate to
  an application ID, `RPGAPI_setTlsApplication`, then the request, upload,
  streaming, file and worker tests over `https://` (curl, a browser). PUB400
  gives no DCM access, and GSKit there refuses a PKCS#12 file made with
  OpenSSL (GSKit 406, errno 3474), so this has not been run

## Cleanup

## PUB400
- [ ] `BUILD`, `QRPGLESRC` and `RPGWEB` in library `RPGAPI` survive `CLRLIB`
  (`LONGDM` is not authorized to them). Removing them needs their owner, or
  authority granted to `LONGDM`
