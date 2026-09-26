"""Several jobs (app: jobs). With 4 jobs, started with a library list of
--mode: spread of requests, stalled clients, library list, replacing a
worker that ends, and a controlled end while requests are in flight.
Mode "single", one job: a controlled end lets the request in flight
finish."""
from common import *
import os, subprocess

args = setup(__doc__)
MAIN = os.environ.get('RPGAPI_TEST_JOB', '')

def job_list():
    out = subprocess.run(['/QOpenSys/usr/bin/qsh', '-c', "db2 \"select job_name from table("
                          "qsys2.active_job_info(job_name_filter => 'JOBS')) x\""],
                         capture_output=True, text=True).stdout
    return sorted(line.strip() for line in out.split('\n') if '/JOBS' in line)

def end_job(job, option):
    subprocess.run(['system', f'ENDJOB JOB({job}) OPTION({option})'], capture_output=True)

def wait_for(condition, seconds):
    until = time.time() + seconds
    while time.time() < until:
        if condition():
            return True
        time.sleep(0.5)
    return condition()

def slow_requests(count, then=None):
    """count /slow requests at once; then() runs a second after they start.
    Returns their statuses."""
    statuses = []
    def one():
        try:
            statuses.append(get('/slow')[0])
        except OSError:
            statuses.append(0)
    def later():
        time.sleep(1)
        then()
    in_threads(*([one] * count + ([later] if then else [])))
    return statuses

if args.mode == 'single':
    statuses = slow_requests(1, lambda: end_job(MAIN, '*CNTRLD) DELAY(60'))
    check('controlled end: the request in flight finishes', statuses == [200], statuses)
    check('then the job ends and the port closes', wait_for(lambda: not job_list(), 10), job_list())
    done()

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
    try:
        for c in b'GET /slow HTTP/1.1\r\nHost: x\r\n\r\n':
            s.sendall(bytes([c]))
            time.sleep(1)
    except OSError:
        pass
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

before = job_list()
worker = next(job for job in before if job != MAIN)
end_job(worker, '*IMMED')
# the main job replaces it between its own requests: it may first finish
# the dripping client's request from above, which takes over 30s
check('a worker that ends is replaced', wait_for(lambda: len(job_list()) == 4 and worker not in job_list(), 60),
      (before, job_list()))
new = [job for job in job_list() if job not in before]
number = new[0].split('/')[0] if new else '?'
served = False
for _ in range(80):
    if get('/libl')[2].decode().startswith(f'job {number}:'):
        served = True
        break
check('the new worker job serves requests', served, number)

statuses = slow_requests(4, lambda: end_job(MAIN, '*CNTRLD) DELAY(60'))
check('controlled end of the main job: requests in flight finish', statuses == [200] * 4, statuses)
check('then every job ends', wait_for(lambda: not job_list(), 15), job_list())
done()
