# Load Test Findings — 2026-10-23

A long-tail latency problem found while load testing `examples/hello.rpgle`
(`GET /hello`) with Postman: its cause, the fix, and how many jobs to run.

**Summary:** about 1% of requests waited 30–45 seconds. The cause was the
server's keep-alive handling with one job, not a lock, leak or timeout: a
client sending requests back to back kept the only job for 100 requests
while the others waited to be accepted. Branch `fix/keepalive-fairness`
makes a busy connection give its job up to a waiting client, which brought
the slowest request from 45.6 s to 1.4 s on one job. With 20 jobs for 20
clients, every target below is met.

## Test setup

| Setting | Value |
|---|---|
| Tool | Postman Performance runner (local machine) |
| Collection | `DalBMi`, one `GET` ("New Request") to `/hello` |
| Profile | Fixed, 20 virtual users, 2 minutes |
| Server | `examples/hello.rpgle` on the user's IBM i (DAIBMI, V7R6, Power Virtual Server) |
| Assertions | None, so "0% errors" means "a response came back" |

## Runs

| | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Code | before the fix | `fix/keepalive-fairness` | `fix/keepalive-fairness` |
| Jobs | 1 | 1 | 20 |
| Route | SSH tunnel, HTTP | internet, HTTPS (443) | internet, HTTPS (443) |
| Requests | 5,128 | 6,522 | 77,040 |
| Requests/second | 45.4 | 54.3 | 640.6 |
| Average | 381 ms | 360 ms | 21 ms |
| Min | 12 ms | 74 ms | 12 ms |
| P90 | 19 ms | 402 ms | 29 ms |
| P95 | 25 ms | 468 ms | 35 ms |
| P99 | 247 ms | 643 ms | 72 ms |
| Max | **45,629 ms** | 1,411 ms | 404 ms |
| Errors | 0 | 0 | 0 |

Runs 1 and 2 differ in route and protocol as well as code, so they are not
like for like; the shape of the times is what changed.

## Run 1: what went wrong

**Two-mode times.** About 99% of requests took ~20 ms, and about 1% (≈51
requests) took 30–45 s, so the average (381 ms) was above P99 (247 ms). The
average rose over the first ~45 s, then stayed high.

**Cause.** Traced through `qrpglesrc/rpgapi.rpgle`:

1. `hello.rpgle` calls `RPGAPI_start(app : 8080)`, so **one job** serves the
   port.
2. A job serves one connection at a time. After a response,
   `RPGAPI_waitForNextRequest` gives a kept-open connection up to a waiting
   client only after it has been quiet for 250 ms (`RPGAPI_REUSE_GRACE_MS`).
3. Postman sends each virtual user's next request at once, so the connection
   is never quiet: it keeps the job until the keep-alive request limit
   (**100**, `RPGAPI_keepOpen`).
4. The other 19 clients wait in the listen backlog, connected by TCP but not
   yet accepted. The read timeout (30 s) starts only after `accept`, so they
   never time out and no error is reported.

**The numbers fit exactly.** 120 s ÷ 5,128 ≈ 23 ms per request. Each client
gets 100 requests per turn, and the first of each waits for the other 19
turns: 19 × 100 × 23 ms ≈ 44 s, against a measured max of 45.6 s. One slow
request per 100 is the 1%, and 5,128 ÷ 100 ≈ 51 of them. The rising average
was the queue filling at the start, not something growing.

**Corrections to the first analysis.** The tail did not limit throughput:
one job answering one request at a time caps it at ~45/s however the waits
fall. And nothing accumulated over the run (no leak, cursor or handle).

## The fix (branch `fix/keepalive-fairness`)

`RPGAPI_keepOpen` now also checks `RPGAPI_clientWaiting`: a 0 ms `poll()` on
the listening socket and the connection. When a new client is waiting and
the current client has sent nothing more, the response says
`Connection: close`; the client connects again behind the one waiting, so
clients take turns a request each. A pipelined request already sent is
answered first, never cut off. With no client waiting, keep-alive is
unchanged.

**Verified on DAIBMI:** build clean; unit tests 59/59; integration suites
`keepalive` 17/17 (two new checks: a busy connection is closed for a waiting
client, which is answered next) and `hello` 99/99.

**Cost.** Under contention almost every request needs a new connection, and
over HTTPS a new TLS handshake: run 2's minimum went to 74 ms. Through the
SSH tunnel, 20 clients reconnecting at once were too much for the tunnel
(2.6 requests/s, ~70 s stalls, dropped connections), while the same load run
on the IBM i itself did 1,099 requests/s with a 77 ms max. Load tests should
not go through the tunnel.

## Run 2: one job with the fix

The 45 s hangs are gone: the slowest request is 1.4 s and the average stays
flat. Every request now waits its turn instead of 1% waiting for everyone's:
20 clients × ~18 ms each ≈ 360 ms, the average measured. The fix makes the
wait fair; it cannot make one job serve 20 clients faster.

## Run 3: 20 jobs

Every client has a job, so no connection is closed and each keeps its TLS
session: 14× run 1's throughput, a 21 ms average and a 404 ms max. The 20
jobs did the same work (1.65–1.68 s CPU each, ~0.43 ms per request) and
used about 29MB of temporary storage each. One interval at about 16:32:59
dropped to ~250 requests/s with a ~65 ms average and recovered at once,
without errors; its cause was not looked into.

## Targets

| Target | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| P95 < 100 ms | pass (25) | fail (468) | **pass (35)** |
| P99 < 500 ms | pass (247) | fail (643) | **pass (72)** |
| Errors < 1% | pass | pass | **pass** |
| Max under a few seconds | fail (45.6 s) | pass (1.4 s) | **pass (0.4 s)** |

## Recommendations

1. **Merge `fix/keepalive-fairness`.** Fewer jobs than busy clients should
   be slower, not a 45 s stall for 1% of requests.
2. **Run about as many jobs as clients that send requests at the same time**
   (`RPGAPI_start(app : port : jobs)` or `app.jobs`), up to 65. Added to
   ApiDocumentation.md as "How many jobs", with these runs as the example.
3. **Add assertions** to the Postman request: status 200 and
   `responseTime < 500`.
4. **Consider starting and stopping jobs with the load** instead of a fixed
   number. A worker job was measured serving HTTPS 49 ms after it was
   spawned, fast enough to help during a burst: see
   [JobScalingDesign.md](JobScalingDesign.md).

## Still to run

- The same profile for **10 minutes** with 20 jobs, to confirm the times
  stay flat.
- A **ramp-up** (5 → 50 users) against a fixed number of jobs, to see the
  times rise once clients outnumber jobs.

## Found along the way

- **git on DAIBMI crashes** (`Illegal instruction`, core dumps) and has no
  route to GitHub. The clone `/home/DLONG/RPGAPI` has 7 zero-byte files and a
  broken HEAD, probably from git dying mid-write; it was left untouched (its
  Makefile has two local fixes not in the repo). The tests ran from a copy of
  the branch in `/home/DLONG/RPGAPI-keepalive`.
- **Ports from the internet:** 22 and 443 reach the IBM i (150.238.11.43);
  80 and 8080 are filtered.
- **HTTPS works** with DCM application ID `RPGAPI` (certificate `RPGAPI`,
  self-signed: turn off certificate verification in Postman).
- **`QBATCH` runs one job at a time**, so a second server submitted there
  waits on the job queue until the first ends.
