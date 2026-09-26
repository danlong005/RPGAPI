# Integration tests

These run RPGAPI for real: each suite compiles a small test app, starts it in
a batch job on the IBM i, sends it requests from Python, and checks what comes
back byte for byte, including timings, memory use and the job log. They cover
what the unit tests in `qtestsrc` cannot: sockets, several jobs, timeouts,
large and streamed bodies, files and TLS set-up.

## Running them
On the IBM i, in a clone of the repository, after building RPGAPI once
(see the main README):

```bash
sh tests/integration/run.sh                  # every suite
sh tests/integration/run.sh routes bodies    # some of them
make integration SUITES="routes bodies"      # the same through make
```

Every check prints `PASS` or `FAIL`, and the run ends with a count and the
list of failures. It exits with 1 when anything failed. A full run takes
about 15 minutes, mostly uploads of 50MB and waits for timeouts.

| Environment variable | Default | |
| --- | --- | --- |
| `LIB` | `RPGAPI` | Library to build RPGAPI and the test apps into. It must exist; it is not cleared |
| `PORT` | `41731` | Port the test apps listen on. It must be free |
| `WORK` | `tests/integration/work` | Work directory for test files and uploads (ignored by git) |
| `TIMEOUT` | `5` | Read and write timeout the apps are started with, in seconds |
| `PYTHON` | `/QOpenSys/pkgs/bin/python3` | Python 3 |
| `MAKE` | `/QOpenSys/pkgs/bin/make` | GNU make |

It needs Python 3 and curl (`yum install python3 curl`), and SQL services
(`QSYS2`, `SYSTOOLS`) to watch jobs, ports and job logs. The apps are
submitted with your job description's job queue; the suites run one app at a
time, so a queue that runs one job at a time is fine.

## Suites
| Suite | App | What it checks |
| --- | --- | --- |
| `basic` | `basic` | requests in pieces, bodies ending in `@`, line breaks and spaces kept, UTF-8 and CCSID conversion |
| `timeouts` | `basic` | clients that send nothing, part of a body, or a byte a second are cut off at the read timeout; 10 clients connecting at once are all answered |
| `routes` | `routes` | whole-path route matching, `{params}`, `*` segments, middleware prefixes |
| `misc` | `misc` | `setRoute`, `patch`, 202, CR/LF, and five complete responses byte for byte |
| `hello` | `hello` | the Quick Start app, URL decoding, `request.hostname`, requests without headers, redirects, statuses without a constant |
| `bodies` | `bodies` | bodies in memory, chunked, 100-continue and the 413/431/400/501 refusals; 50MB streamed uploads with flat memory, `saveBody`, stalled uploads (408); the request and upload limits |
| `multipart` | `bodies` | `multipart/form-data` from curl and by hand, in random pieces, with fake delimiters, skipped parts, bad bodies, and a 30MB file |
| `stream` | `stream` | streamed and chunked responses, HTTP/1.0, `sendFile` with types, 304/206/416 and `If-Range`, and the write timeout |
| `jobs` | `jobs` | 4 jobs share requests, a stalled client holds only one, all have the library list they were started with, and all end with the main job |
| `logging` | `logging` | the number and content of log messages at each level, credentials not logged, and a bad log level refused |
| `cors` | `cors` | `HEAD` routed to `GET` without a body (also streamed, and files in `stream`), automatic `OPTIONS` with `Allow`, CORS headers for allowed origins only, preflights answered before middleware, `*` |
| `tls` | `tls` | an unregistered application ID and a missing keystore stop the server with GSKit's reason; plain HTTP without TLS |

HTTPS itself is not tested: it needs a certificate assigned in Digital
Certificate Manager (see HTTPS in the main README).

## How it fits together
- `apps/` has one RPG program per suite. Each takes its settings (port, log
  level, limits, timeout, jobs, work directory, TLS) from the data area
  `TESTCFG` in its own library, through `testcfg_h.rpgle` and
  `testcfg.rpgle`, so the runner can start the same app with different
  settings.
- `clients/` has one Python script per suite, with `common.py` for HTTP over
  a socket and the `PASS`/`FAIL` checks.
- `run.sh` builds RPGAPI with `make`, compiles each app, writes `TESTCFG`,
  submits the app, waits until it listens, runs the client, ends the app and
  waits until its jobs have ended and the port is free.
