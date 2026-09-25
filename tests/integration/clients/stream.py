"""Streamed responses, sendFile with caching and ranges, and the write
timeout (app: stream, write timeout --timeout)."""
from common import *
import email.utils, hashlib, json, os, subprocess

args = setup(__doc__)
FILES = args.work + '/files/'

status, headers, body = get('/stream?rows=50000')
text, complete = dechunk(body)
lines = text.decode().split('\n')
check('50,000 lines streamed chunked', status == 200 and headers.get('transfer-encoding') == 'chunked'
      and complete and len(lines) == 50001 and lines[-2] == 'line 50000', (status, headers, len(lines)))
out = subprocess.run(f'curl -s http://127.0.0.1:{args.port}/stream?rows=50000 | wc -l', shell=True,
                     capture_output=True, text=True).stdout.strip()
check('curl reads all 50,000 lines', out == '50000', out)
status, headers, body = get('/stream?rows=1000', protocol='HTTP/1.0')
check('HTTP/1.0: no chunking, body until close', 'transfer-encoding' not in headers and 'content-length' not in headers
      and body.count(b'\n') == 1000, headers)
status, headers, body = get('/json?rows=20000')
text, complete = dechunk(body)
data = json.loads(text)
check('20,000-row JSON array parses', complete and len(data) == 20000 and
      data[-1] == {'id': 20000, 'name': 'Jürgen', 'tags': ['a|b', 'c\\d'], 'mail': 'x@y'}, data[-1])
status, headers, body = get('/length')
check('Content-Length stream', headers.get('content-length') == '11' and body == b'hello world', (headers, body))

for name, ctype in [('big.bin', 'application/octet-stream'), ('huge.bin', 'application/octet-stream'),
                    ('data.json', 'application/json'), ('pic.png', 'image/png'), ('notes.txt', 'text/plain; charset=utf-8')]:
    status, headers, body = get('/file?name=' + name)
    want = open(FILES + name, 'rb').read()
    check(f'sendFile {name}', status == 200 and headers.get('content-type') == ctype and
          headers.get('content-length') == str(len(want)) and hashlib.sha256(body).digest() == hashlib.sha256(want).digest(),
          (status, headers.get('content-type')))
for name in ['missing.txt', '../secret.txt', 'sub/../../secret.txt']:
    status, _, body = get('/file?name=' + name)
    check(f'sendFile {name}: the procedure answers 404', (status, body) == (404, b'no such file'), (status, body))
status, headers, body = get('/disposition')
check('sendFile keeps the procedure\'s headers', headers.get('content-type') == 'text/x-custom' and
      headers.get('cache-control') == 'no-store' and headers.get('content-disposition') == 'attachment; filename="notes.txt"',
      headers)
status, headers, body = get('/nobegin')
check('write without begin: 500', status == 500)
status, headers, body = get('/fail')
check('failure mid-stream: incomplete chunked response', status == 200 and not dechunk(body)[1])

# caching and ranges
big = open(FILES + 'big.bin', 'rb').read()
st = os.stat(FILES + 'big.bin')
etag = 'W/"%X-%X"' % (st.st_size, int(st.st_mtime))
modified = email.utils.formatdate(int(st.st_mtime), usegmt=True)
url = '/file?name=big.bin'
status, headers, body = get(url)
check('ETag and Last-Modified from the file', headers.get('etag') == etag and headers.get('last-modified') == modified and
      headers.get('accept-ranges') == 'bytes' and headers.get('cache-control') == 'public, max-age=0', headers)
def date(offset):
    return email.utils.formatdate(int(st.st_mtime) + offset, usegmt=True)
for name, hdrs, status_want in [
        ('If-None-Match: its ETag', [f'If-None-Match: {etag}'], 304),
        ('If-None-Match: in a list', [f'If-None-Match: "other", {etag}'], 304),
        ('If-None-Match: other', ['If-None-Match: "other"'], 200),
        ('If-None-Match: *', ['If-None-Match: *'], 304),
        ('If-Modified-Since: same', [f'If-Modified-Since: {modified}'], 304),
        ('If-Modified-Since: later', [f'If-Modified-Since: {date(3600)}'], 304),
        ('If-Modified-Since: earlier', [f'If-Modified-Since: {date(-3600)}'], 200),
        ('If-Modified-Since: junk', ['If-Modified-Since: yesterday'], 200),
        ('If-None-Match other beats If-Modified-Since', ['If-None-Match: "other"', f'If-Modified-Since: {modified}'], 200),
        ('Range 100-50 is ignored', ['Range: bytes=100-50'], 200),
        ('several ranges get the whole file', ['Range: bytes=0-1,5-6'], 200),
        ('items= range is ignored', ['Range: items=0-5'], 200),
        ('If-Range other ETag: whole file', ['Range: bytes=0-9', 'If-Range: W/"1-1"'], 200),
        ('If-Range earlier date: whole file', ['Range: bytes=0-9', f'If-Range: {date(-3600)}'], 200)]:
    status, headers, body = get(url, *hdrs)
    ok = status == status_want and (len(body) == (0 if status == 304 else 2000000))
    check(name, ok, (status, len(body)))
for name, hdrs, first, last in [('Range 0-99', ['Range: bytes=0-99'], 0, 99),
                                ('Range 1999900-', ['Range: bytes=1999900-'], 1999900, 1999999),
                                ('Range -500', ['Range: bytes=-500'], 1999500, 1999999),
                                ('Range past the end', ['Range: bytes=1000-2999999'], 1000, 1999999),
                                ('If-Range its ETag', ['Range: bytes=0-9', f'If-Range: {etag}'], 0, 9),
                                ('If-Range same date', ['Range: bytes=0-9', f'If-Range: {modified}'], 0, 9)]:
    status, headers, body = get(url, *hdrs)
    check(name, status == 206 and headers.get('content-range') == f'bytes {first}-{last}/2000000' and
          body == big[first:last + 1], (status, headers.get('content-range')))
status, headers, body = get(url, 'Range: bytes=5000000-')
check('Range outside the file: 416', status == 416 and headers.get('content-range') == 'bytes */2000000')
time.sleep(1.1)
os.utime(FILES + 'big.bin')
status, headers, body = get(url, f'If-None-Match: {etag}')
check('after the file changes the old ETag gets a 200', status == 200 and headers.get('etag') != etag)

# the write timeout: a client that stops reading, and one that reads slowly
T = args.timeout
result = {}
def stalled():
    s = connect(T * 6)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
    s.sendall(b'GET /stream?rows=2000000 HTTP/1.1\r\nHost: x\r\n\r\n')
    s.recv(65536)
    time.sleep(T * 3)
    s.settimeout(1)
    try:
        while s.recv(1 << 20):
            pass
        result['stalled'] = 'closed'
    except socket.timeout:
        result['stalled'] = 'open'
    except OSError:
        result['stalled'] = 'closed'
    s.close()
def queued():
    time.sleep(2)
    start = time.time()
    status = split(exchange(b'GET /length HTTP/1.1\r\nHost: x\r\n\r\n', timeout=T * 6))[0]
    result['queued'] = (status, time.time() - start)
in_threads(stalled, queued)
check('client that stops reading is given up on', result['stalled'] == 'closed', result)
check(f'request queued behind it answered within {T * 2 + 20}s',
      result['queued'][0] == 200 and result['queued'][1] < T * 2 + 20, result)
s = connect(60)
s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
s.sendall(b'GET /stream?rows=100000 HTTP/1.1\r\nHost: x\r\n\r\n')
data = b''
while chunk := s.recv(65536):
    data += chunk
    time.sleep(0.25)
s.close()
check('slow but steady reader gets the whole response', dechunk(split(data)[2])[1])
done()
