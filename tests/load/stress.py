"""A light load test for an RPGAPI server: 1, 4 and 8 clients, on kept-open
connections and on a new connection per request. Prints requests a second
and response times for each step, and stops at the first step with errors.
Exits with 1 when a request failed."""
import argparse, http.client, sys, threading, time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--host', default='127.0.0.1')
parser.add_argument('--port', type=int, default=8080)
parser.add_argument('--path', default='/hello/Dan',
                    help='a GET route answering 200 with a body')
parser.add_argument('--limit', type=int, default=20,
                    help='seconds a step may take at most')
args = parser.parse_args()


def step(name, clients, per_client, keep_alive):
    times, errors, lock = [], [], threading.Lock()
    deadline = time.time() + args.limit

    def client():
        conn = None
        for _ in range(per_client):
            if time.time() > deadline:
                break
            start = time.time()
            try:
                if conn is None:
                    conn = http.client.HTTPConnection(args.host, args.port, timeout=15)
                conn.request('GET', args.path)
                response = conn.getresponse()
                body = response.read()
                if response.status != 200 or not body:
                    raise RuntimeError(f'status {response.status}, {len(body)} bytes')
                with lock:
                    times.append((time.time() - start) * 1000)
            except Exception as e:
                with lock:
                    errors.append(repr(e)[:80])
                if conn:
                    conn.close()
                conn = None
                continue
            if not keep_alive:
                conn.close()
                conn = None
        if conn:
            conn.close()

    began = time.time()
    threads = [threading.Thread(target=client) for _ in range(clients)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    took = time.time() - began
    times.sort()
    pct = lambda p: times[min(len(times) - 1, int(len(times) * p))] if times else float('nan')
    print(f'{name:<34} {len(times):>5} ok {len(errors):>3} err  {len(times) / took:7.1f} req/s  '
          f'p50 {pct(.5):6.1f}  p95 {pct(.95):6.1f}  p99 {pct(.99):6.1f}  '
          f'max {times[-1] if times else 0:7.1f} ms', flush=True)
    for e in sorted(set(errors))[:5]:
        print('    ', e, flush=True)
    return not errors


for step_args in [('1 client, kept-open', 1, 300, True),
                  ('1 client, new connection each', 1, 300, False),
                  ('4 clients, kept-open', 4, 100, True),
                  ('4 clients, new connection each', 4, 100, False),
                  ('8 clients, kept-open', 8, 60, True),
                  ('8 clients, new connection each', 8, 60, False)]:
    if not step(*step_args):
        print('errors: stopping here', flush=True)
        sys.exit(1)
    time.sleep(2)
