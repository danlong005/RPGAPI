# Load test

`stress.py` sends a light load to a running RPGAPI server: 1, 4 and 8
clients, first on kept-open connections and then on a new connection per
request. That is about 2,400 requests in all, and each step stops after 20
seconds at most. For each step it prints the requests answered, errors,
requests a second and response times (p50, p95, p99, max). It stops at the
first step with errors and then exits with 1.

It is kept light on purpose, for shared systems such as PUB400. Run it on
the IBM i itself against `127.0.0.1`, so that the network does not hide the
server's own times:

```bash
# start an app first, e.g. examples/hello.rpgle (port 8080, one job)
/QOpenSys/pkgs/bin/python3 tests/load/stress.py --port 8080 --path /hello/Dan
```

| Option | Default | |
| --- | --- | --- |
| `--host` | `127.0.0.1` | |
| `--port` | `8080` | |
| `--path` | `/hello/Dan` | A `GET` route answering 200 with a body |
| `--limit` | `20` | Seconds a step may take at most |

## Results on PUB400

`examples/hello.rpgle` with one job, 2026-09-27 (commit f6a3382):

| Step | OK | Errors | Req/s | p50 | p95 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 client, kept-open | 300 | 0 | 434 | 1.4 ms | 6.6 ms | 6.9 ms | 17 ms |
| 1 client, new connection each | 300 | 0 | 282 | 2.3 ms | 7.9 ms | 8.2 ms | 9 ms |
| 4 clients, kept-open | 400 | 0 | 447 | 1.4 ms | 6.6 ms | 17 ms | 670 ms |
| 4 clients, new connection each | 400 | 0 | 454 | 10 ms | 14 ms | 18 ms | 20 ms |
| 8 clients, kept-open | 480 | 0 | 361 | 1.8 ms | 7.0 ms | 488 ms | 1,153 ms |
| 8 clients, new connection each | 480 | 0 | 275 | 27 ms | 42 ms | 53 ms | 59 ms |

A job serves one connection at a time, and a client that keeps sending on
its connection keeps the job until the connection's request limit (100 by
default). With more busy clients than jobs, the others wait: that is the
slow tail of the kept-open steps. Start more jobs
(`RPGAPI_start(app : port : 4)`) for more clients at once.
