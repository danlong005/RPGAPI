# Load tests

Two scripts send load to a running RPGAPI server and print what came back:

- `users.py`: a steady load, like a load tester's fixed profile. Each of a
  number of users sends requests one after the other on a connection it
  keeps open, for a number of seconds. Prints the requests answered,
  requests a second and response times (average, p50, p90, p95, p99, max),
  and the failures by kind.
- `stress.py`: a light check for shared systems such as PUB400. 1, 4 and 8
  clients, on kept-open connections and on a new connection per request,
  about 2,400 requests in all. Stops at the first step with errors.

Both need only Python 3, and exit with 1 when a request failed. Run them on
the IBM i against `127.0.0.1` to measure the server without the network, or
from another machine to measure what clients get:

```bash
# start an app first, e.g. examples/hello.rpgle (port 8080)
/QOpenSys/pkgs/bin/python3 tests/load/users.py --users 20 --seconds 60
/QOpenSys/pkgs/bin/python3 tests/load/stress.py --port 8080 --path /hello/Dan
```

| `users.py` option | Default | |
| --- | --- | --- |
| `--host`, `--port` | `127.0.0.1`, `8080` | |
| `--path` | `/hello` | A `GET` route answering 200 with a body |
| `--users` | `20` | Users sending requests at the same time |
| `--seconds` | `60` | How long |
| `--pause-ms` | `0` | Each user's pause between requests |
| `--tls` | off | HTTPS, without checking the certificate |

| `stress.py` option | Default | |
| --- | --- | --- |
| `--host`, `--port` | `127.0.0.1`, `8080` | |
| `--path` | `/hello/Dan` | A `GET` route answering 200 with a body |
| `--limit` | `20` | Seconds a step may take at most |

A server under load should log at WARN or less: at INFO and DEBUG every
request adds to the job log, and a full job message queue ends the job (see
Logging in ApiDocumentation.md).

## Results with Postman, 2026-10-23

`examples/hello.rpgle` over HTTPS on port 443, on an IBM i 7.6 partition in
IBM Power Virtual Server with 0.25 of a processor and 2GB of memory. The
load came from Postman's performance runner on a PC over the internet, 20
virtual users each sending `GET /hello` one after the other, so the times
include the network (the fastest request took 11 ms).

| Jobs | Profile | Requests | Per second | Average | p95 | p99 | Max | Failed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 20 users, 2 min | 6,522 | 54 | 360 ms | 468 ms | 643 ms | 1.4 s | 0 |
| 20, fixed | 20 users, 2 min | 77,040 | 641 | 21 ms | 35 ms | 72 ms | 0.4 s | 0 |
| 1 to 20, the default | 5 users, then up to 20 over 30 s, 2 min | 45,650 | 379 | 23 ms | 43 ms | 82 ms | 1.1 s | < 0.01% |
| 1 to 20, the default | 20 users, 10 min | 362,917 | 604 | 22 ms | 40 ms | 77 ms | 1.2 s | 0 |

- **1 job** answers one connection at a time, so the 20 users took turns:
  each request waited for the others (20 × 18 ms, about the 360 ms
  average), and most needed a new connection and TLS handshake. Throughput
  is what one job can do.
- **20 jobs, fixed** gave every user a job and a connection it kept.
- **The default** started jobs as the users came. In the ramp, they followed
  the users up to 20 within about 2 s each, so the response times stayed
  flat throughout; the lower rate is from the first 30 s with 5 users. In
  the 10-minute run, all 20 jobs were running 5 s after the users started,
  stayed for the whole run, and were stopped one a second about a minute
  after it ended. 20 jobs took about 600MB of temporary storage. The
  response times did not drift over the 10 minutes.

20 users from the IBM i itself (`users.py`'s first version, plain HTTP, one
job) got 1,099 requests a second with a 77 ms max: most of the time Postman
measured was the network.

Before keep-alive gave way to waiting clients, one job serving 20 users
held each user's connection for 100 requests while the others waited to be
accepted: 1% of the requests took 30 to 45 seconds. LoadTestFindings.md in
the repository root has that investigation and the runs since.

## Results on PUB400

`stress.py` against `examples/hello.rpgle` with one job, 2026-09-27 (commit
f6a3382), before keep-alive gave way to waiting clients:

| Step | OK | Errors | Req/s | p50 | p95 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 client, kept-open | 300 | 0 | 434 | 1.4 ms | 6.6 ms | 6.9 ms | 17 ms |
| 1 client, new connection each | 300 | 0 | 282 | 2.3 ms | 7.9 ms | 8.2 ms | 9 ms |
| 4 clients, kept-open | 400 | 0 | 447 | 1.4 ms | 6.6 ms | 17 ms | 670 ms |
| 4 clients, new connection each | 400 | 0 | 454 | 10 ms | 14 ms | 18 ms | 20 ms |
| 8 clients, kept-open | 480 | 0 | 361 | 1.8 ms | 7.0 ms | 488 ms | 1,153 ms |
| 8 clients, new connection each | 480 | 0 | 275 | 27 ms | 42 ms | 53 ms | 59 ms |

The slow tail of the kept-open steps is clients waiting while another kept
the job for its connection's 100 requests; a busy connection now gives its
job up when a client is waiting.
