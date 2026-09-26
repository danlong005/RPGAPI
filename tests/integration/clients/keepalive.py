"""Keep-alive (app: hello). Mode "on": kept open 2s, 3 requests per
connection; "off": keep-alive turned off."""
from common import *

args = setup(__doc__)

def open_connection():
    return connect(30), []

def ask(s, pending, raw, method=b'GET'):
    s.sendall(raw)
    return split(read_response(s, method, pending))

def closed(s, wait=1.0):
    """Whether the server has closed s (within wait seconds)."""
    s.settimeout(wait)
    try:
        return s.recv(1) == b''
    except socket.timeout:
        return False
    except OSError:
        return True
    finally:
        s.settimeout(30)

GET = b'GET /hello HTTP/1.1\r\nHost: x\r\n\r\n'

if args.mode == 'off':
    s, p = open_connection()
    status, headers, body = ask(s, p, GET)
    check('keep-alive off: Connection: close, and closed', headers.get('connection') == 'close' and closed(s), headers)
    done()

s, p = open_connection()
status, headers, body = ask(s, p, GET)
check('first response keeps the connection', status == 200 and headers.get('connection') == 'keep-alive' and
      headers.get('keep-alive') == 'timeout=2' and body == b'hello world', (status, headers))
status, headers, body = ask(s, p, b'GET /hello/Anna HTTP/1.1\r\nHost: x\r\n\r\n')
check('second request on the same connection', (status, body) == (200, b'hello Anna'))
status, headers, body = ask(s, p, GET)
check('third (the limit) says Connection: close and closes',
      status == 200 and headers.get('connection') == 'close' and closed(s), headers)
s.close()

s, p = open_connection()
s.sendall(GET + b'GET /hello/Bo HTTP/1.1\r\nHost: x\r\n\r\n')
first = split(read_response(s, b'GET', p))
second = split(read_response(s, b'GET', p))
check('two pipelined requests answered in order', first[2] == b'hello world' and second[2] == b'hello Bo', (first[2], second[2]))
s.close()

s, p = open_connection()
status, headers, body = ask(s, p, b'GET /hello HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n')
check('Connection: close from the client is honoured', headers.get('connection') == 'close' and closed(s))
s.close()
s, p = open_connection()
status, headers, body = ask(s, p, b'GET /hello HTTP/1.0\r\nHost: x\r\n\r\n')
check('HTTP/1.0 without keep-alive: closed', headers.get('connection') == 'close' and closed(s))
s.close()
s, p = open_connection()
status, headers, body = ask(s, p, b'GET /hello HTTP/1.0\r\nHost: x\r\nConnection: keep-alive\r\n\r\n')
check('HTTP/1.0 asking for keep-alive: kept', headers.get('connection') == 'keep-alive' and not closed(s, 0.5))
s.close()

s, p = open_connection()
ask(s, p, GET)
start = time.time()
gone = closed(s, 5)
check('idle connection closed after the 2s timeout', gone and 1.5 < time.time() - start < 4, round(time.time() - start, 1))
s.close()

idle, p = open_connection()
ask(idle, p, GET)
start = time.time()
status = get('/hello')[0]
took = time.time() - start
check('a new client is served at once, not after the idle one', status == 200 and took < 1.5, round(took, 2))
check('the idle connection was closed for it', closed(idle, 1))
idle.close()

s, p = open_connection()
status, headers, body = ask(s, p, b'GET /header?name=X-A HTTP/1.1\r\nHost: x\r\nX-A: one\r\n\r\n')
status2, headers2, body2 = ask(s, p, b'GET /header?name=X-A HTTP/1.1\r\nHost: x\r\n\r\n')
check('headers of one request do not carry over to the next', body == b'len=3' and body2 == b'len=0', (body, body2))
s.close()

s, p = open_connection()
status, headers, body = ask(s, p, b'GET /nothing HTTP/1.1\r\nHost: x\r\n\r\n')
status2, headers2, body2 = ask(s, p, b'HEAD /hello HTTP/1.1\r\nHost: x\r\n\r\n', b'HEAD')
check('404 and HEAD keep the connection too', status == 404 and headers.get('connection') == 'keep-alive' and
      status2 == 200 and headers2.get('content-length') == '11' and body2 == b'')
s.close()
done()
