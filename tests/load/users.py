"""A steady load on an RPGAPI server, like a load tester's fixed profile:
a number of users, each sending GET requests one after the other on a
connection it keeps open (and opens again when the server closes it), for a
number of seconds. Prints the requests answered, requests a second and
response times as Postman's performance runner does, and the failures by
kind. Exits with 1 when a request failed."""
import argparse, collections, http.client, ssl, sys, threading, time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--host', default='127.0.0.1')
parser.add_argument('--port', type=int, default=8080)
parser.add_argument('--path', default='/hello',
                    help='a GET route answering 200 with a body')
parser.add_argument('--users', type=int, default=20)
parser.add_argument('--seconds', type=int, default=60)
parser.add_argument('--pause-ms', type=int, default=0,
                    help='each user waits this long between requests')
parser.add_argument('--tls', action='store_true',
                    help='HTTPS, without checking the certificate')
args = parser.parse_args()

lock = threading.Lock()
times = []
failures = collections.Counter()
connections = [0]
context = ssl._create_unverified_context() if args.tls else None
end = time.time() + args.seconds


def connect():
    with lock:
        connections[0] += 1
    if args.tls:
        return http.client.HTTPSConnection(args.host, args.port, timeout=60, context=context)
    return http.client.HTTPConnection(args.host, args.port, timeout=60)


def user():
    conn = connect()
    while time.time() < end:
        start = time.time()
        try:
            conn.request('GET', args.path)
            response = conn.getresponse()
            body = response.read()
            if response.status != 200 or not body:
                raise RuntimeError(f'status {response.status}')
            with lock:
                times.append((time.time() - start) * 1000)
            if (response.getheader('Connection') or '').lower() == 'close':
                conn.close()
                conn = connect()
        except Exception as e:
            with lock:
                failures[type(e).__name__ + (f' {e}' if isinstance(e, RuntimeError) else '')] += 1
            conn.close()
            conn = connect()
        if args.pause_ms:
            time.sleep(args.pause_ms / 1000)
    conn.close()


began = time.time()
threads = [threading.Thread(target=user) for _ in range(args.users)]
for t in threads:
    t.start()
for t in threads:
    t.join()
took = time.time() - began

times.sort()
pct = lambda p: times[min(len(times) - 1, int(len(times) * p))]
failed = sum(failures.values())
print(f'{args.users} users, {args.seconds} s, {"https" if args.tls else "http"}://{args.host}:{args.port}{args.path}')
if times:
    print(f'requests {len(times) + failed}  failed {failed} '
          f'({100 * failed / (len(times) + failed):.2f}%)  per second {len(times) / took:.1f}')
    print(f'avg {sum(times) / len(times):.0f}  min {times[0]:.0f}  p50 {pct(.5):.0f}  p90 {pct(.9):.0f}  '
          f'p95 {pct(.95):.0f}  p99 {pct(.99):.0f}  max {times[-1]:.0f}  (ms)')
print(f'connections opened {connections[0]}')
for kind, count in failures.most_common():
    print(f'  {count:6}  {kind}')
sys.exit(1 if failed else 0)
