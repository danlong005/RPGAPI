"""Several jobs (app: jobs, 4 jobs, started with a library list of
--mode): spread of requests, stalled clients, library list."""
from common import *
import subprocess

args = setup(__doc__)
results = {}
def slow(n):
    def run():
        start = time.time()
        body = get('/slow')[2].decode()
        results[n] = (time.time() - start, body)
    return run
start = time.time()
in_threads(*[slow(n) for n in range(8)])
took = time.time() - start
jobs = {body for _, body in results.values()}
check('8 three-second requests in 4 jobs take about 6s', took < 10 and len(jobs) == 4, (round(took, 1), jobs))

results.clear()
def drip():
    s = connect(60)
    for c in b'GET /slow HTTP/1.1\r\nHost: x\r\n\r\n':
        s.sendall(bytes([c]))
        time.sleep(1)
    s.close()
def others():
    time.sleep(1)
    in_threads(*[slow(n) for n in range(3)])
threading.Thread(target=drip, daemon=True).start()
others()
check('requests behind a client sending a byte a second are answered by other jobs',
      all(t < 6 for t, _ in results.values()), results)

libraries = set()
for _ in range(40):
    libraries.add(get('/libl')[2].decode().partition(': ')[2])
wanted = args.mode.split()
check('every job has the library list it was started with',
      len(libraries) == 1 and all(lib in next(iter(libraries)).split() for lib in wanted), libraries)
done()
