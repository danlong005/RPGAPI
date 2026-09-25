"""Logging (app: logging). Mode is the log level the app was started with:
sends one of each kind of event, then counts and checks the RPGAPI
messages in the app's job log."""
from common import *
import subprocess

args = setup(__doc__)
level = int(args.mode)

def req(raw, wait=0, close=False):
    s = connect(15)
    if raw:
        s.sendall(raw)
    if close:
        s.shutdown(socket.SHUT_WR)
    if wait:
        time.sleep(wait)
    data = receive_all(s)
    s.close()
    return split(data)[0]

H = b'Host: example.com:41731\r\n'
statuses = [req(b'GET /hello HTTP/1.1\r\n' + H + b'Authorization: Bearer SECRET123\r\n\r\n'),
            req(b'GET /hello/Dan?x=1 HTTP/1.1\r\n' + H + CRLF),
            req(b'GET /nothing HTTP/1.1\r\n' + H + CRLF),
            req(b'GET /boom HTTP/1.1\r\n' + H + CRLF),
            req(b'POST /echo HTTP/1.1\r\n' + H + b'Content-Length: 500\r\n\r\n' + b'x' * 500),
            req(b'POST /echo HTTP/1.1\r\n' + H + b'Content-Length: 2000\r\n\r\n' + b'x' * 2000),
            req(b'POST /echo HTTP/1.1\r\n' + H + b'Transfer-Encoding: gzip\r\n\r\n'),
            req(b'', wait=args.timeout + 2),
            req(None, close=True)]
check('responses', statuses == [200, 200, 404, 500, 200, 413, 501, 0, 0], statuses)

def messages():
    job = subprocess.run(['/QOpenSys/usr/bin/qsh', '-c', "db2 \"select job_name from table(qsys2.active_job_info("
                          "job_name_filter => 'LOGGING')) x\""], capture_output=True, text=True).stdout.split('\n')[3].strip()
    out = subprocess.run(['/QOpenSys/usr/bin/qsh', '-c', f"db2 \"select varchar(message_text, 300) from table("
                          f"qsys2.joblog_info('{job}')) x where message_text like 'RPGAPI %'\""],
                         capture_output=True, text=True).stdout
    return [line.strip() for line in out.split('\n') if line.strip().startswith('RPGAPI ')]

log = messages()
expected = {0: 0, 1: 1, 2: 4, 3: 12, 4: 51}[level]
check(f'level {level} logs {expected} messages', len(log) == expected, f'{len(log)}: {log[:5]}')
if level >= 1:
    check('ERROR names the exception', any('failed: MCH1211' in m for m in log if m.startswith('RPGAPI ERROR')), log)
if level >= 2:
    check('WARN gives the 413 and 501 reasons', any('answered 413' in m for m in log) and any('answered 501' in m for m in log))
if level >= 3:
    check('INFO line per request', any(m.startswith('RPGAPI INFO #1: GET /hello -> 200, ') and m.endswith(' ms') for m in log), log)
if level >= 4:
    check('Authorization is not logged', not any('SECRET123' in m for m in log) and
          any('Authorization: (not logged)' in m for m in log))
    check('no leftover request-line parts among the headers', not any('header HTTP/1.1' in m for m in log))

# request line parts no longer turn up as query params or headers
body = get('/count?a=1&b=2', 'X-One: 1')[2].decode()
check('query params and headers are only the real ones', body.endswith('query: <a> <b>') and '<X-One>' in body, body)
done()
