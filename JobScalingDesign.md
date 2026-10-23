# Design: starting and stopping jobs with the load

Status: proposal, 2026-10-23. Follows [LoadTestFindings.md](LoadTestFindings.md).

## Why

A job answers one connection at a time, so an app needs about as many jobs as
clients sending requests at once ("How many jobs" in ApiDocumentation.md).
The load tests showed what too few costs: 20 clients on 1 job averaged 360 ms,
on 20 jobs 21 ms. Today the number is fixed when the server starts, so it has
to be set for the busiest moment, all day.

This lets an app give a range instead: a number of jobs kept running, a
largest number, and how long an idle job is kept before it is stopped.

## Measured: how fast a job starts

On DAIBMI (V7R6, Power Virtual Server), idle otherwise, `examples/hello.rpgle`
with 20 jobs, timed from the main job's log (`starting 19 worker job(s)`) to
each worker's `worker job serving port`:

| | Time |
|---|---|
| One worker, from spawn to serving HTTPS (program start and TLS set-up included) | **49 ms** |
| Each further worker, spawned one after another | +15 ms (max 24 ms) |
| The main job's time spawning 19 workers, in which it serves no one | 291 ms |
| All 19 workers serving, first to last (3 runs each, HTTP / HTTPS) | 0.24–0.25 s / 0.29–0.31 s |

HTTPS started a little slower than plain HTTP, about 2 ms more a job. The
first start after compiling was the slowest (0.6 s from first to last), as the
program was loaded the first time.

So a new job helps within about 50 ms: soon enough that a burst is answered
by more jobs well before anyone notices. Under heavy CPU load these times
will be longer; they are worth measuring again then.

## The API

Scaling is on by default: an app that says nothing about jobs runs 1 to 20
jobs, and stops one that has been idle for 60 seconds. No line is needed for
that; `RPGAPI_setJobs` is for a different range, and a fixed number of jobs
stays available:

```rpgle
RPGAPI_start(app : 8080);              // the default: 1 to 20 jobs

RPGAPI_setJobs(app : 4 : 40);          // 4 to 40 jobs, idle ones stopped after 60s
RPGAPI_setJobs(app : 2 : 20 : 300);    // idle ones stopped after 5 minutes
RPGAPI_setJobs(app : 1 : 1);           // one job, as before scaling
RPGAPI_start(app : 8080 : 4);          // 4 jobs, fixed, as today
```

| Setting | Default | Field in `RPGAPI_App` |
|---|---|---|
| `min`: jobs kept running | 1 | `jobs` (already there) |
| `max`: the most jobs | 20 | `max_jobs` (new) |
| `idleSeconds`: idle time before a job above `min` is stopped | 60 | `job_idle_seconds` (new) |

Which an app gets, when `RPGAPI_start` runs:

| The app | Jobs |
|---|---|
| sets nothing (`jobs` and `max_jobs` 0 after `clear app`) | 1 to 20, scaling |
| calls `RPGAPI_setJobs(app : min : max)` with `max` above `min` | `min` to `max`, scaling |
| calls `RPGAPI_setJobs` with `max` equal to `min` | `min`, fixed |
| sets `app.jobs` or passes `RPGAPI_start`'s third parameter, and not `max_jobs` | that many, fixed, as today |

So an app that already chose a number of jobs keeps it. Only apps that left
it at the default, one job, change: they now scale (see Upgrading below).

- `min` at least 1, `max` at least `min` and at most 64 (see below);
  `idleSeconds` at least 1. Bad values end the program with an escape
  message, like the other setters (`RPGAPI_settingFailed`). `idleSeconds`
  left out keeps 60.
- The fields go at the end of `RPGAPI_App`, and `RPGAPI_SETJOBS` at the end
  of the binder source. The new export changes the service program's
  signature, so programs compiled against the old header fail to start with
  a signature error instead of passing a too-short `RPGAPI_App`.

### Why a most of 20

- **Enough for common callers.** A browser opens up to 6 connections to a
  server, so fewer than about 10 would be used up by two people loading
  pages at once; callers' connection pools are commonly 10 to 20. The load
  test needed 20 for 20 clients to meet every target.
- **Safe on a small partition.** The most is also how far a problem spreads:
  a procedure stuck on a record lock, or clients that connect and send
  nothing, take jobs up to the most, each with its own SQL connection, open
  files and locks. More jobs do not add CPU, only room for waiting clients:
  one job answered 1,099 requests a second on DAIBMI. 20 jobs of
  `examples/hello.rpgle` took about 580MB, and only while busy.
- **Easy to find when too low:** see the WARN under "Starting a job".

## How it works

### The main job supervises and does not serve

With scaling on, the job that calls `RPGAPI_start` opens the port, starts
`min` workers, and then only watches them. Today it also serves requests and
looks after the workers only between requests. That would not do here: it
must notice that every job is busy exactly when it is busiest, and spawning
takes it 15 ms a job. So with scaling on, `jobs` and `min` count the jobs
serving, and there is one more job, the supervisor. With scaling off, the main
job serves as it does now.

The worker limit stays at 64 (`RPGAPI_worker_pids`), so `max` is at most 64.

### Two new pipes

Workers already inherit the listening socket (descriptor 0) and the shutdown
pipe (3 and 4). They also get:

- **a status pipe**, shared, write end at descriptor 5. A worker writes a
  2-byte message on each change: its state and its slot number (from a new
  environment variable, `RPGAPI_WORKER_SLOT`). Writes this small are atomic,
  so messages from different workers never mix. The states:
  - `R` ready: serving, idle
  - `B` busy: it accepted a connection
  - `I` idle: the connection was closed
  - `S` stopping: it was asked to stop and is ending
- **a control pipe of its own**, read end at descriptor 6. The supervisor
  writes `Q` to it to ask that one worker to stop. The worker polls it with
  the listening socket and the shutdown pipe, where it waits for connections
  (`RPGAPI_acceptConnection`) and between requests on a kept-open connection
  (`RPGAPI_waitForNextRequest`).

Messages are per connection, not per request: a kept-open connection is one
`B` and one `I`, however many requests it carries.

### Starting a job

The supervisor knows each slot's state from the status pipe. It starts one
more worker when all three hold:

1. every running worker is busy,
2. a client has been waiting: the listening socket stayed readable, checked
   every 10 ms, for 50 ms (about one job's start-up time), and
3. fewer than `max` workers are running, and no worker it started is still
   starting (not yet `R`).

Condition 3 keeps it from starting 20 jobs for a burst that one more job
would have served; while a burst lasts, it starts one about every 60 ms
(start-up plus the wait), so 20 jobs in a little over a second. Each start is
logged at INFO: `all 8 jobs busy and a client waited 50 ms: starting job 9`.

**At the most.** When conditions 1 and 2 hold but `max` workers are running,
no job is started, and the supervisor logs a WARN in its job log, at most
once a minute. It is logged even with logging off (the default), the one
message that is: the apps that need it are the ones that left the settings
alone, and once a minute cannot fill a job log.

```
RPGAPI WARN: all 20 jobs (the most) are busy and clients are waiting: raise
the most with RPGAPI_setJobs
```

A default only works if people find out when it is too low for them; this
turns "the API got slow" into a message in the job log naming the fix.

Meanwhile the waiting client is served by the fairness rule
(`fix/keepalive-fairness`): a busy connection gives its job up after its next
response, also while a new job is starting.

### Stopping a job

When more than `min` workers run, and one has been idle (`R` or `I`, no
connection) for `idleSeconds`, the supervisor writes `Q` to that worker's
control pipe, the one idle longest, and stops one at a time. The worker:

- idle: answers `S` and ends at once,
- holding a connection it accepted just before `Q` arrived: answers that
  request, closes the connection with `Connection: close`, then ends.

A request is never cut off. The supervisor marks the slot as stopped on
purpose, so that when `waitpid` reports the job ended it does not count as a
failure or get replaced. Each stop is logged at INFO:
`job 9 idle for 60 s: stopped (8 jobs)`.

The idle time is the hysteresis: a job started for a burst stays for at least
`idleSeconds`, so a load that comes and goes does not start and stop jobs over
and over.

### Jobs that end on their own

As today, the supervisor reaps workers with `waitpid` once a second, and
clears the slot's state: a worker that failed while busy no longer counts as
busy. It starts a replacement only while fewer than `min` run; above `min`,
the scaling rules decide. The limit of 5 replacements a minute stays.

### Stopping the server

Unchanged: `ENDJOB` of the main job, or `RPGAPI_shutdown`, writes the
shutdown pipe; every worker finishes its request and ends, and the
supervisor waits for them all.

## What else changes

- **`RPGAPI_start`**: decides fixed or scaling by the table under "The API"
  (`RPGAPI_applySettings` fills in 1, 20 and 60), and with scaling runs the
  supervisor loop (`RPGAPI_supervise`) instead of the request loop in the
  main job. The INFO line it logs at start says which: `serving port 8080 in
  1 to 20 job(s)` or `in 4 job(s)`.
- **`RPGAPI_spawnWorker`**: maps descriptors 5 and 6, and sets
  `RPGAPI_WORKER_SLOT`.
- **`RPGAPI_acceptConnection`, `RPGAPI_closeClient`**: write `B` and `I`.
- **`RPGAPI_acceptConnection`, `RPGAPI_waitForNextRequest`**: poll the
  control pipe as well, and end on `Q`.
- **`RPGAPI_checkWorkers`**: replace only up to `min`, and not slots stopped
  on purpose.
- **Docs**: `RPGAPI_setJobs` in the API reference, the defaults in the
  `RPGAPI_App` table, "Several jobs" and "How many jobs" rewritten for a
  range, the Quick Start's line on jobs, and the README's Upgrading note.

## Upgrading

Scaling by default changes how an app that never set a number of jobs runs.
The README's Upgrading section says, in short:

> **Apps scale by default.** An app that does not set a number of jobs now
> runs 1 to 20 of them as the load needs, with one more job watching them.
> Recompile your programs (the service program's signature changed). Then
> check two things, and if either applies, keep one job with
> `RPGAPI_setJobs(app : 1 : 1)`:
> - **Data kept between requests** in the program, such as a counter, a
>   cache or an array, is per job: requests answered by different jobs see
>   different copies.
> - **Code before `RPGAPI_start`** runs again in every job, also whenever one
>   is started for load: it must be safe to repeat (no clearing a work file,
>   no notices sent), and the program must need no parameters.
>
> An app that sets its number of jobs (`app.jobs`, or `RPGAPI_start`'s third
> parameter) runs that many, as before.

## Tests

A new integration suite, `scaling`, with an app at `RPGAPI_setJobs(app : 1 :
4 : 2)`:

1. 4 clients each holding a connection: 4 jobs within 1 s; all answered.
2. 6 clients: stays at 4 jobs; all answered (fairness).
3. Load stops: back to 1 job within about 3 s (2 s idle plus a check).
4. A slow streamed response on a job above `min`: the job is not stopped
   until it ends, and the response is complete.
5. A worker ended with `*IMMED` while above `min`: not replaced; below
   `min`: replaced.
6. `ENDJOB` of the main job while jobs are starting, and while one is
   stopping: every job ends, no request in progress is cut off.
7. The INFO messages for each start and stop.
8. At the most: 6 clients holding connections to the 4 jobs log the WARN
   once, not again within the minute.

And a second app that sets nothing about jobs:

9. It starts with 1 job and a supervisor, logs `in 1 to 20 job(s)`, and
   grows under load.
10. With `app.jobs = 4` instead: 4 jobs, fixed, no supervisor, as today.

The existing suites set their number of jobs through `TESTCFG` (1 unless the
suite needs more), so they keep testing what they test now; the `jobs` suite
passes unchanged. Unit tests for `RPGAPI_setJobs`'s checks and for which
setting gives fixed or scaling jobs. Then a Postman ramp (5 → 50 users,
`RPGAPI_setJobs(app : 4 : 40)`): times like run 3's in LoadTestFindings.md
while jobs are below 40, and the job count following the users up and down.

## Decisions

1. **Timings:** 60 s idle before a job is stopped, a client waiting 50 ms
   before a job is started, one job starting at a time.
2. **Fairness while growing:** unchanged. A busy connection is closed for a
   waiting client at once, also while a new job is starting.
3. **The supervisor job:** yes. Its 29MB buys reacting while every worker
   is busy, which is when it matters.
4. **64 workers is the most**, as today.
5. **Scaling is on by default**, 1 to 20 jobs with 60 s idle, so no line is
   needed. An app that sets a number of jobs keeps exactly that many.
6. **A WARN at the most**, at most once a minute, naming `RPGAPI_setJobs`,
   logged even with logging off.
