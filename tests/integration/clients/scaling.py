"""Jobs started and stopped with the load (app: jobs, logging at INFO).
Mode "range": RPGAPI_setJobs(app : 1 : 4 : 2). Jobs start while clients
wait, up to the most (with a WARN there), stop again when idle, never cut a
request off, and a failed one is replaced below the least only; ending the
main job ends them all. Mode "default": nothing set, 1 to 20 jobs. Mode
"quiet": logging off, 1 to 2 jobs: the WARN at the most is logged anyway."""
from common import *
import http.client, os, subprocess

args = setup(__doc__)
MAIN = os.environ.get('RPGAPI_TEST_JOB', '')

def sql(query):
    out = subprocess.run(['/QOpenSys/usr/bin/qsh', '-c', f'db2 "{query}"'],
                         capture_output=True, text=True).stdout
    return [line.strip() for line in out.split('\n')[3:] if line.strip() and 'RECORD(S)' not in line]

def workers():
    """The worker jobs running, by job name: the main job is the only BCH."""
    rows = sql("select job_name concat ' ' concat job_type from table("
               "qsys2.active_job_info(job_name_filter => 'JOBS')) x")
    return sorted(r.split()[0] for r in rows if r.endswith('BCI'))

def main_running():
    return any(r.endswith('BCH') for r in sql(
        "select job_name concat ' ' concat job_type from table("
        "qsys2.active_job_info(job_name_filter => 'JOBS')) x"))

def log(text):
    """The RPGAPI messages in the main job's log containing text."""
    rows = sql("select varchar(message_text, 300) from table(qsys2.joblog_info("
               f"'{MAIN}')) x where message_text like 'RPGAPI %'")
    return [r for r in rows if text in r]

def end_job(job, option):
    subprocess.run(['system', f'ENDJOB JOB({job}) OPTION({option})'], capture_output=True)

def wait_for(condition, seconds):
    until = time.time() + seconds
    while time.time() < until:
        if condition():
            return True
        time.sleep(0.25)
    return condition()

def slow(count, then=None):
    """count /slow requests (3 s each) at once, then() a second after they
    start. Returns their statuses, the jobs that answered, and the time."""
    statuses, jobs = [], []
    def one():
        try:
            status, headers, body = get('/slow')
            statuses.append(status)
            jobs.append(body.decode())
        except OSError:
            statuses.append(0)
    def later():
        time.sleep(1)
        then()
    start = time.time()
    in_threads(*([one] * count + ([later] if then else [])))
    return statuses, jobs, time.time() - start

check('starts with the least, 1 worker job', wait_for(lambda: len(workers()) == 1, 10), workers())

if args.mode == 'quiet':
    statuses, jobs, took = slow(6)
    check('logging off, 1 to 2 jobs, 6 clients: all answered', statuses == [200] * 6, statuses)
    every = log('')
    check('the WARN at the most is the one message logged',
          len(every) == 1 and '(the most) are busy' in every[0], every)
    done()

if args.mode == 'default':
    check('logs the range 1 to 20', len(log('in 1 to 20 job(s)')) == 1, log('serving port'))
    statuses, jobs, took = slow(3)
    check('3 clients at once: a job each, as jobs start', statuses == [200] * 3 and len(set(jobs)) == 3 and took < 5,
          (statuses, sorted(set(jobs)), round(took, 1)))
    done()

check('logs the range 1 to 4', len(log('in 1 to 4 job(s)')) == 1, log('serving port'))

statuses, jobs, took = slow(4)
check('4 clients at once: jobs start for them, each answered by its own',
      statuses == [200] * 4 and len(set(jobs)) == 4 and took < 5, (statuses, sorted(set(jobs)), round(took, 1)))
check('4 worker jobs running', len(workers()) == 4, workers())
check('each start logged', len(log('jobs busy and a client waited')) == 3, log('jobs busy'))

# 12 clients on 4 jobs: three rounds of 3 s, clients waiting in the first
# 6 s, long enough for the WARN (waiting in 5 of 10 seconds). The count is
# taken a second in, while all 4 are busy
during = []
statuses, jobs, took = slow(12, lambda: during.append(len(workers())))
check('12 clients, at most 4 jobs: all answered, 8 after waiting',
      statuses == [200] * 12 and 8.5 < took < 13 and during == [4], (statuses, round(took, 1), during))
check('at the most, a WARN, once', len(log('(the most) are busy')) == 1, log('the most'))

check('idle jobs stop, down to the least', wait_for(lambda: len(workers()) == 1, 12), workers())
check('each stop logged', len(log('s: stopping it')) == 3, log('stopping it'))

# a client sending requests one after another on its connection keeps its
# job while others stop around it
slow(2)
answered, failed = [], []
conn = http.client.HTTPConnection('127.0.0.1', args.port, timeout=15)
until = time.time() + 5
while time.time() < until:
    try:
        conn.request('GET', '/libl')
        response = conn.getresponse()
        response.read()
        answered.append(response.status)
    except Exception as e:
        failed.append(repr(e)[:60])
        conn.close()
        conn = http.client.HTTPConnection('127.0.0.1', args.port, timeout=15)
    time.sleep(0.05)
conn.close()
check('requests go on while idle jobs stop: none cut off',
      answered and set(answered) == {200} and not failed, (len(answered), set(answered), failed[:3]))
check('the jobs stopped meanwhile', wait_for(lambda: len(workers()) == 1, 8), workers())

# short requests: 4 clients sending them back to back on kept connections.
# A waiting client is served after the next response, so none waits long,
# but jobs giving way to them start more, as fast as with long requests
quick, quick_failed, reached = [], [], []
def quick_client():
    conn = http.client.HTTPConnection('127.0.0.1', args.port, timeout=15)
    until = time.time() + 4
    while time.time() < until:
        try:
            conn.request('GET', '/libl')
            response = conn.getresponse()
            response.read()
            quick.append(response.status)
            if response.getheader('Connection', '').lower() == 'close':
                conn.close()
                conn = http.client.HTTPConnection('127.0.0.1', args.port, timeout=15)
        except Exception as e:
            quick_failed.append(repr(e)[:60])
            conn.close()
            conn = http.client.HTTPConnection('127.0.0.1', args.port, timeout=15)
    conn.close()
def watch():
    start = time.time()
    while time.time() - start < 4:
        if len(workers()) == 4:
            reached.append(round(time.time() - start, 1))
            return
        time.sleep(0.1)
in_threads(*([quick_client] * 4 + [watch]))
check('4 clients sending short requests: 4 jobs within 2 s', reached and reached[0] <= 2, reached)
check('short requests: all answered', quick and set(quick) == {200} and not quick_failed,
      (len(quick), set(quick), quick_failed[:3]))
check('starts for jobs giving way logged', len(log('gave way to a waiting client')) >= 1, log('gave way'))
check('back to the least after', wait_for(lambda: len(workers()) == 1, 12), workers())

# a worker that fails, at the least, is replaced
before = workers()
end_job(before[0], '*IMMED')
check('a failed worker at the least is replaced',
      wait_for(lambda: len(workers()) == 1 and workers() != before, 10), (before, workers()))
# the replacement can be seen running a moment before its message is logged
check('the failure logged',
      wait_for(lambda: len(log('ended, status')) == 1 and len(log('again (process')) == 1, 5),
      log('ended, status') + log('again (process'))

# above the least, one that fails is not replaced
slow(2)
two = workers()
end_job(two[-1], '*IMMED')
time.sleep(3)
check('a failed worker above the least is not replaced', len(workers()) == 1, (two, workers()))

# ending the main job while jobs start: requests in flight finish, all end
statuses, jobs, took = slow(3, lambda: end_job(MAIN, '*CNTRLD) DELAY(60'))
check('ENDJOB while jobs start: requests in flight finish', statuses == [200] * 3, statuses)
check('then every job ends', wait_for(lambda: not workers() and not main_running(), 15), workers())
done()
