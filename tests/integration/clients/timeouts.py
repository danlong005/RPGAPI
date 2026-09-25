"""Stalled clients and the connection queue (app: basic, one job, read
timeout --timeout): a queued request is answered once the stalled client
is cut off, and connections arriving while busy wait instead of being
refused."""
from common import *

args = setup(__doc__)
T = args.timeout
limit = T + 6

def stalled_then_queued(name, send):
    result = {}
    def stalled():
        s = connect(T * 4)
        try:
            send(s)
        except OSError:
            pass
        result['stalled'] = receive_all(s)
        s.close()
    def queued():
        time.sleep(1)
        start = time.time()
        data = exchange(b'GET /hello HTTP/1.1\r\nHost: x\r\n\r\n', timeout=T * 4)
        result['queued'] = (split(data)[0], time.time() - start)
    in_threads(stalled, queued)
    status, seconds = result['queued']
    check(f'{name}: queued request answered within {limit}s',
          status == 200 and seconds < limit, f'status {status} after {seconds:.1f}s')
    check(f'{name}: stalled client gets no response', result['stalled'] == b'', result['stalled'][:40])

stalled_then_queued('silent client', lambda s: time.sleep(T * 2))
stalled_then_queued('client sending 10 of 100 body bytes',
                    lambda s: (s.sendall(b'POST /echo HTTP/1.1\r\nHost: x\r\nContent-Length: 100\r\n\r\n0123456789'),
                               time.sleep(T * 2)))
def drip(s):
    for c in b'GET /hello HTTP/1.1\r\nHost: x\r\n\r\n':
        s.sendall(bytes([c]))
        time.sleep(1)
stalled_then_queued('client sending a byte a second', drip)

# while one client holds the job for a few seconds, 10 more connect at once
results = []
def slow():
    s = connect(30)
    for piece in [b'GET /hello HTTP/1.1\r\n', b'Host: x\r\n', CRLF]:
        s.sendall(piece)
        time.sleep(1.5)
    receive_all(s)
    s.close()
def quick():
    try:
        results.append(split(exchange(b'GET /hello HTTP/1.1\r\nHost: x\r\n\r\n', timeout=30))[0])
    except OSError:
        results.append(0)
def burst():
    time.sleep(0.5)
    in_threads(*[quick] * 10)
in_threads(slow, burst)
check('10 clients connecting while the job is busy are all answered',
      results.count(200) == 10, results)
done()
