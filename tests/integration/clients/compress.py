"""gzip compression (app: compress): which clients and responses get gzip,
bodies in memory, streamed (chunked, with a length given, HTTP/1.0), files
with ranges and 304, HEAD, and keep-alive."""
from common import *
import gzip, os

args = setup(__doc__)
GZIP = 'Accept-Encoding: gzip'

def gunzip(data):
    try:
        return gzip.decompress(data)
    except Exception as e:
        return f'not gzip: {e}'.encode()

def body_of(headers, body):
    """The body as sent, without chunking."""
    if headers.get('transfer-encoding') == 'chunked':
        data, complete = dechunk(body)
        return data if complete else b'incomplete chunks'
    return body

# a body in memory
plain = get('/json?bytes=5000')
status, headers, body = get('/json?bytes=5000', GZIP)
check('JSON of 5000 bytes is gzipped for a client that accepts it',
      status == 200 and headers.get('content-encoding') == 'gzip' and
      headers.get('vary') == 'Accept-Encoding' and 'transfer-encoding' not in headers, headers)
check('its Content-Length is the gzipped length', headers.get('content-length') == str(len(body)),
      (headers.get('content-length'), len(body)))
check('it unzips to the body sent without gzip', gunzip(body) == plain[2] and len(plain[2]) > 4900,
      (len(plain[2]), gunzip(body)[:60]))
check('and is much smaller', len(body) < len(plain[2]) // 3, (len(body), len(plain[2])))
check('without Accept-Encoding: as it is, with Vary', 'content-encoding' not in plain[1] and
      plain[1].get('vary') == 'Accept-Encoding' and plain[1].get('content-length') == str(len(plain[2])), plain[1])

for accept, gzipped in [('gzip;q=0', False), ('deflate, br', False), ('*', True), ('GZIP', True),
                        ('br;q=1.0, gzip;q=0.5', True), ('*;q=0.5, gzip;q=0', False),
                        ('identity', False), ('x-gzip', True), ('gzip; q=0.000', False), ('gzip;q=0.001', True)]:
    status, headers, body = get('/json?bytes=5000', f'Accept-Encoding: {accept}')
    check(f'Accept-Encoding: {accept}: ' + ('gzipped' if gzipped else 'as it is'),
          (headers.get('content-encoding') == 'gzip') == gzipped and
          (gunzip(body) if gzipped else body) == plain[2], headers)

status, headers, body = get('/json?bytes=500', GZIP)
check('500 bytes, under the 1024 byte threshold: as it is, with Vary',
      'content-encoding' not in headers and headers.get('vary') == 'Accept-Encoding' and body.startswith(b'['), headers)

status, headers, body = get('/text?word=Gr%C3%BC%C3%9Fe&times=500', GZIP)
text = gunzip(body)
check('UTF-8 text is gzipped as UTF-8', headers.get('content-encoding') == 'gzip' and
      text == ('Grüße ' * 500).encode(), text[:40])

status, headers, body = get('/png', GZIP)
check('image/png: as it is, without Vary', 'content-encoding' not in headers and 'vary' not in headers and
      len(body) == 5000, headers)
status, headers, body = get('/encoded?word=abc&times=1000', GZIP)
check('a Content-Encoding the procedure set: left as it is', headers.get('content-encoding') == 'identity' and
      body == b'abc ' * 1000, headers)
status, headers, body = get('/notransform?word=abc&times=1000', GZIP)
check('Cache-Control: no-transform: as it is', 'content-encoding' not in headers and body == b'abc ' * 1000, headers)

status, headers, body = get('/json?bytes=5000', GZIP, method='HEAD')
gzipped_length = len(get('/json?bytes=5000', GZIP)[2])
check('HEAD: the headers of the gzipped GET, no body', headers.get('content-encoding') == 'gzip' and
      headers.get('content-length') == str(gzipped_length) and body == b'', (headers, len(body)))

# streamed
plain = get('/stream?rows=2000')
status, headers, body = get('/stream?rows=2000', GZIP)
check('a stream is gzipped in chunks', headers.get('content-encoding') == 'gzip' and
      headers.get('transfer-encoding') == 'chunked' and headers.get('vary') == 'Accept-Encoding', headers)
check('it unzips to the stream sent without gzip', gunzip(body_of(headers, body)) == body_of(plain[1], plain[2]) and
      plain[2].count(b'\n') >= 2000, len(plain[2]))
status, headers, body = get('/stream?rows=100000', GZIP)
lines = gunzip(body_of(headers, body)).split(b'\n')
check('a stream of 100,000 rows (1.9MB) unzips whole', len(lines) == 100001 and lines[99999] == b'100000,row 100000,700000',
      (len(lines), lines[-2:]))

status, headers, body = get('/length')
check('a stream with a length given, not gzipped: that Content-Length', headers.get('content-length') == '3000' and
      len(body) == 3000, headers)
plain_length = body
status, headers, body = get('/length', GZIP)
check('gzipped: chunked instead, and unzips to the same', headers.get('content-encoding') == 'gzip' and
      'content-length' not in headers and headers.get('transfer-encoding') == 'chunked' and
      gunzip(body_of(headers, body)) == plain_length, headers)

status, headers, body = split(exchange(b'GET /stream?rows=2000 HTTP/1.0\r\nAccept-Encoding: gzip\r\n\r\n'))
check('HTTP/1.0: gzipped to the close, not chunked', headers.get('content-encoding') == 'gzip' and
      'transfer-encoding' not in headers and gunzip(body) == body_of(plain[1], plain[2]), headers)

# files
content = open(os.path.join(args.work, 'files', 'big.txt'), 'rb').read()
status, headers, body = get('/file/big.txt', GZIP)
check('a text file is gzipped, without Accept-Ranges', headers.get('content-encoding') == 'gzip' and
      'accept-ranges' not in headers and headers.get('etag', '').startswith('W/') and
      headers.get('content-type', '').startswith('text/plain'), headers)
check('it unzips to the file', gunzip(body_of(headers, body)) == content, len(body))
etag = headers.get('etag')
status, headers, body = get('/file/big.txt')
check('without Accept-Encoding: the file as it is, with Accept-Ranges', 'content-encoding' not in headers and
      headers.get('accept-ranges') == 'bytes' and body == content, headers)
status, headers, body = get('/file/big.txt', GZIP, 'Range: bytes=0-99')
check('a Range with gzip: the whole file, gzipped (200)', status == 200 and 'content-range' not in headers and
      gunzip(body_of(headers, body)) == content, (status, headers))
status, headers, body = get('/file/big.txt', 'Range: bytes=0-99')
check('a Range without gzip: 206 as before', status == 206 and body == content[:100], (status, headers))
status, headers, body = get('/file/big.txt', GZIP, f'If-None-Match: {etag}')
check('If-None-Match with gzip: 304, with Vary', status == 304 and body == b'' and
      headers.get('vary') == 'Accept-Encoding' and 'content-encoding' not in headers, (status, headers))
status, headers, body = get('/file/big.txt', GZIP, method='HEAD')
check('HEAD of a gzipped file: its headers, no body', status == 200 and headers.get('content-encoding') == 'gzip' and
      body == b'', (status, headers))
status, headers, body = get('/file/pic.png', GZIP)
check('a .png file: as it is, with Accept-Ranges', 'content-encoding' not in headers and
      headers.get('accept-ranges') == 'bytes', headers)
status, headers, body = get('/file/notes.txt', GZIP)
check('a text file under the threshold: as it is', 'content-encoding' not in headers and
      body == 'hello Jürgen\n'.encode(), headers)

# several on one connection
s = connect(30)
pending = []
answers = []
for path in [b'/json?bytes=5000', b'/stream?rows=500', b'/file/big.txt', b'/json?bytes=100']:
    s.sendall(b'GET ' + path + b' HTTP/1.1\r\nHost: x\r\nAccept-Encoding: gzip\r\n\r\n')
    answers.append(split(read_response(s, b'GET', pending)))
s.close()
check('gzipped responses one after another on a kept-open connection',
      [a[1].get('content-encoding') for a in answers] == ['gzip', 'gzip', 'gzip', None] and
      gunzip(body_of(answers[2][1], answers[2][2])) == content and
      gunzip(answers[0][2]).startswith(b'[{"id":1,') and answers[3][2].startswith(b'['),
      [a[1] for a in answers])
done()
