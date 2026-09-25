"""multipart/form-data (app: bodies, with a 100MB upload limit)."""
from common import *
import hashlib, os, random, subprocess

args = setup(__doc__)
UP, FILES = args.work + '/uploads/', args.work + '/files/'
random.seed(7)

def same(n, data):
    return hashlib.sha256(open(UP + f'part{n}.bin', 'rb').read()).digest() == hashlib.sha256(data).digest()

def send(path, content_type, body, pieces=1):
    head = (b'POST ' + path + b' HTTP/1.1\r\nHost: x\r\nContent-Type: ' + content_type +
            f'\r\nContent-Length: {len(body)}\r\n\r\n'.encode())
    cuts = sorted(random.sample(range(1, len(body)), pieces - 1)) if pieces > 1 else []
    parts, last = [head], 0
    for c in cuts + [len(body)]:
        parts.append(body[last:c]); last = c
    status, _, text = split(exchange(None, parts, pause=0))
    return status, text.decode(errors='replace')

big = open(FILES + 'big.bin', 'rb').read()
pic = open(FILES + 'pic.png', 'rb').read()
out = subprocess.run(['curl', '-s', '-F', 'name=Jürgen', '-F', f'file=@{FILES}big.bin', '-F',
                      f'pic=@{FILES}pic.png;type=image/png', '-F', 'empty=', f'http://127.0.0.1:{args.port}/form'],
                     capture_output=True).stdout.decode()
check('curl -F with a field, two files and an empty field',
      out == 'parts=4 [name|||value=Jürgen][file|big.bin|application/octet-stream|saved=2000000]'
             '[pic|pic.png|image/png|saved=50004][empty|||value=]', out)
check('files from curl -F saved intact', same(2, big) and same(3, pic))

b = b'----X7abc'
blob = bytearray(random.randbytes(3000000))
for pos in range(1000, 3000000, 100000):
    fake = b'\r\n--' + b[:random.randrange(0, len(b))]
    blob[pos:pos + len(fake)] = fake
blob = bytes(blob)
tricky = b'line1\r\nline2 --' + b + b'x \r\n-' + b
body = (b'This is the preamble.\r\n--' + b + b'\r\n'
        b'Content-Disposition: form-data; name="note"\r\n\r\n' + tricky + b'\r\n--' + b + b'\r\n'
        b'content-disposition: form-data; filename="Gr\xc3\xbc\xc3\x9fe;1.txt"; name="doc"\r\n'
        b'Content-Type: application/octet-stream\r\n\r\n' + blob + b'\r\n--' + b + b'\r\n'
        b'Content-Disposition: form-data; name="last"\r\n\r\nend\r\n--' + b + b'--\r\nepilogue, ignored')
ct = b'multipart/form-data; boundary="' + b + b'"'
want = ('parts=3 [note|||value=line1<CRLF>line2 ------X7abcx <CRLF>-----X7abc]'
        '[doc|Grüße;1.txt|application/octet-stream|saved=3000000][last|||value=end]')
for pieces in [1, 40]:
    status, got = send(b'/form', ct, body, pieces)
    check(f'body by hand in {pieces} piece(s): fields, filename, near-boundaries', (status, got) == (200, want), got)
    check(f'body by hand in {pieces} piece(s): file with fake delimiters saved intact', same(2, blob))
status, got = send(b'/partbytes', ct, body, 40)
check('readPartBytes checksum', got == f'[doc bytes=3000000 checksum={checksum(blob)}]', got)
check('reading only the third part', send(b'/third', ct, body, 7) == (200, 'third=last value=end'))
check('not multipart: no parts', send(b'/form', b'application/json', b'{"a": 1}') == (200, 'parts=0'))
check('no closing boundary: 400', send(b'/form', ct, body[:body.index(b'\r\n--' + b + b'--')])[0] == 400)
check('no boundary at all: 400', send(b'/form', ct, b'just text\r\n')[0] == 400)

thirty = os.urandom(30000000)
open(args.work + '/big30.bin', 'wb').write(thirty)
out = subprocess.run(['curl', '-s', '-F', 'who=me', '-F', f'file=@{args.work}/big30.bin',
                      f'http://127.0.0.1:{args.port}/form'], capture_output=True).stdout.decode()
check('30MB file through curl -F, streamed',
      out == 'parts=2 [who|||value=me][file|big30.bin|application/octet-stream|saved=30000000]' and same(2, thirty), out)
os.remove(args.work + '/big30.bin')
done()
