"""Request bodies (app: bodies). Modes:
memory  - default limits: bodies in memory, chunked, 100-continue, refusals
uploads - upload limit 100MB: streamed uploads, saveBody, memory use
limits  - request limit 1000 bytes, upload limit 3MB"""
from common import *
import hashlib, os, random, subprocess

args = setup(__doc__)
random.seed(1)
TE = b'Transfer-Encoding: chunked\r\n'

def post(path, length=None, extra=b''):
    h = b'POST ' + path + b' HTTP/1.1\r\nHost: x\r\n' + extra
    if length is not None:
        h += f'Content-Length: {length}\r\n'.encode()
    return h + CRLF

def send(head, body=b'', pieces=None, expect_continue=False, stall=0):
    """(status, body text, whether 100 Continue came first)."""
    s = connect(60)
    got_continue, data = False, b''
    try:
        s.sendall(head)
        if expect_continue:
            s.settimeout(3)
            try:
                first = s.recv(100)
            except socket.timeout:
                first = b''
            s.settimeout(60)
            if first.startswith(b'HTTP/1.1 100'):
                got_continue = True
            else:
                data, body, pieces = first, b'', None
        if stall:
            s.sendall(body)
            time.sleep(stall)
        else:
            for piece in (pieces or [body]):
                s.sendall(piece)
    except OSError:
        pass
    data += receive_all(s)
    s.close()
    status, _, text = split(data)
    return status, text.decode(errors='replace'), got_continue

def expect(name, result, status, text=None):
    ok = result[0] == status and (text is None or result[1] == text)
    check(name, ok, result[:2])

if args.mode == 'memory':
    expect('small body', send(post(b'/body', 12), b'hello world@'), 200,
           'body=12 bodyLength=12 head=hello tail=orld@')
    big = b'x' * 500000
    expect('500,000 bytes: not in request.body', send(post(b'/body', len(big)), big), 200,
           'body=0 bodyLength=500000')
    expect('500,000 bytes read as text', send(post(b'/text', len(big)), big), 200,
           'pieces=32 chars=500000 umlauts=0')
    expect('500,000 bytes read as bytes', send(post(b'/bytes', len(big)), big), 200,
           f'bytes=500000 checksum={checksum(big)} bodyLength=500000/500000')
    binary = bytes(range(256)) * 1000
    expect('256,000 binary bytes', send(post(b'/bytes', len(binary)), binary), 200,
           f'bytes=256000 checksum={checksum(binary)} bodyLength=256000/256000')
    umlauts = 'ü'.encode() * 100000
    expect('100,000 u-umlauts read as text', send(post(b'/text', len(umlauts)), umlauts), 200,
           'pieces=13 chars=100000 umlauts=100000')
    expect('2MB declared: 413', send(post(b'/bytes', 2000000), b'x' * 100000), 413)
    r = send(post(b'/bytes', 2000000, b'Expect: 100-continue\r\n'), b'x' * 100000, expect_continue=True)
    check('2MB with Expect: 413 before the body is sent', r[0] == 413 and not r[2], r)
    r = send(post(b'/body', 20, b'Expect: 100-continue\r\n'), b'a' * 20, expect_continue=True)
    check('20 bytes with Expect: 100 Continue, then 200', r[0] == 200 and r[2], r)
    expect('chunked "hello world" with extension and trailer',
           send(post(b'/body', extra=TE), b'5;name=v\r\nhello\r\n6\r\n world\r\n0\r\nX-Trailer: yes\r\n\r\n'),
           200, 'body=11 bodyLength=11 head=hello tail=world')
    cbody = bytes(random.randrange(256) for _ in range(300000))
    sizes = [random.randrange(1, 40000) for _ in range(40)]
    cb = chunked(cbody, sizes, b';ext=1')
    expect('chunked 300,000 random bytes', send(post(b'/bytes', extra=TE), cb), 200,
           f'bytes=300000 checksum={checksum(cbody)} bodyLength=300000/300000')
    expect('chunked, sent in 3 pieces', send(post(b'/bytes', extra=TE), pieces=[cb[:1000], cb[1000:150000], cb[150000:]]),
           200, f'bytes=300000 checksum={checksum(cbody)} bodyLength=300000/300000')
    expect('chunked 1.2MB: 413', send(post(b'/bytes', extra=TE), chunked(b'y' * 1200000, [100000] * 12)), 413)
    expect('bad chunk size: 400', send(post(b'/body', extra=TE), b'zz\r\nhello\r\n0\r\n\r\n'), 400)
    expect('Transfer-Encoding gzip: 501', send(post(b'/body', extra=b'Transfer-Encoding: gzip\r\n'), b'abc'), 501)
    expect('Content-Length abc: 400', send(post(b'/body', extra=b'Content-Length: abc\r\n'), b'abc'), 400)
    expect('40,000 bytes of headers: 431', send(post(b'/body', 0, b'X-Big: ' + b'h' * 40000 + b'\r\n')), 431)

elif args.mode == 'uploads':
    def storage():
        out = subprocess.run(['/QOpenSys/usr/bin/qsh', '-c', "db2 \"select temporary_storage from table("
                              "qsys2.active_job_info(job_name_filter => 'BODIES', detailed_info => 'ALL')) x\""],
                             capture_output=True, text=True).stdout.split('\n')
        try:
            return int(out[3].strip())
        except (IndexError, ValueError):
            return None
    fifty = random.randbytes(50000000)
    before, samples = storage(), []
    def sample():
        for _ in range(6):
            time.sleep(0.5)
            samples.append(storage())
    result = {}
    in_threads(sample, lambda: result.update(r=send(post(b'/bytes', len(fifty)), fifty)))
    expect('50MB upload read in pieces', result['r'], 200,
           f'bytes=50000000 checksum={checksum(fifty)} bodyLength=50000000/50000000')
    if before is not None and None not in samples:
        check('memory stays flat during a 50MB upload', max(samples) - before < 20, (before, samples))
    expect('50MB upload with saveBody', send(post(b'/save', len(fifty)), fifty), 201, 'saved 50000000')
    saved = open(args.work + '/uploads/up.bin', 'rb').read()
    check('saved file matches the upload', hashlib.sha256(saved).digest() == hashlib.sha256(fifty).digest())
    five = fifty[:5000000]
    sizes = [random.randrange(1, 300000) for _ in range(60)]
    expect('5MB chunked switches to streaming', send(post(b'/bytes', extra=TE), chunked(five, sizes)), 200,
           f'bytes=5000000 checksum={checksum(five)} bodyLength=-1/5000000')
    expect('5MB chunked with saveBody', send(post(b'/save', extra=TE), chunked(five, sizes)), 201, 'saved 5000000')
    check('saved chunked file matches', open(args.work + '/uploads/up.bin', 'rb').read() == five)
    umlauts = 'ü'.encode() * 1500000
    expect('1.5M u-umlauts streamed', send(post(b'/text', len(umlauts)), umlauts), 200,
           'pieces=188 chars=1500000 umlauts=1500000')
    expect('1.5M u-umlauts chunked oddly', send(post(b'/text', extra=TE), chunked(umlauts, [99999, 77777, 333333] * 20)),
           200, 'pieces=200 chars=1500000 umlauts=1500000')
    expect('200MB declared over a 100MB limit: 413', send(post(b'/bytes', 200000000), b'x' * 100000), 413)
    r = send(post(b'/reject', len(fifty), b'Expect: 100-continue\r\n'), fifty, expect_continue=True)
    check('refused without reading: 403, no 100 Continue', r[:2] == (403, 'not you') and not r[2], r)
    r = send(post(b'/bytes', len(fifty), b'Expect: 100-continue\r\n'), fifty, expect_continue=True)
    check('read with Expect: 100 Continue on the first read', r[0] == 200 and r[2], r)
    expect('10MB body the procedure ignores: response intact', send(post(b'/ignore', 10000000), fifty[:10000000]), 200, 'ignored')
    expect('small body still in request.body', send(post(b'/body', 12), b'hello world@'), 200,
           'body=12 bodyLength=12 head=hello tail=orld@')
    expect('streamed upload that stalls: 408', send(post(b'/bytes', 1048577), fifty[:500000], stall=args.timeout + 5), 408)

elif args.mode == 'limits':
    expect('900 bytes under a 1000-byte limit', send(post(b'/bytes', 900), b'a' * 900), 200)
    four = random.randbytes(4000000)
    expect('4MB over a 3MB upload limit: 413', send(post(b'/bytes', len(four)), four), 413)
    expect('4MB chunked over a 3MB upload limit: 413', send(post(b'/bytes', extra=TE), chunked(four, [500000] * 8)), 413)
    expect('2.5MB chunked under it', send(post(b'/bytes', extra=TE), chunked(four[:2500000], [300000] * 9)), 200,
           f'bytes=2500000 checksum={checksum(four[:2500000])} bodyLength=-1/2500000')
done()
