"""Helpers for the integration test clients: raw HTTP over a socket, and
PASS/FAIL checks. Every client takes --port and --work (the runner's work
directory) and exits with 1 when a check fails."""
import argparse, socket, sys, time, threading

CRLF = b'\r\n'
args = None
failures = 0


def setup(description):
    global args
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('--port', type=int, default=41731)
    parser.add_argument('--work', default='.')
    parser.add_argument('--timeout', type=int, default=5,
                        help='the read/write timeout the app was started with')
    parser.add_argument('mode', nargs='?', default='')
    args = parser.parse_args()
    return args


def check(name, ok, detail=''):
    global failures
    if ok:
        print(f'PASS {name}')
    else:
        failures += 1
        print(f'FAIL {name}: {detail}')
    sys.stdout.flush()
    return ok


def done():
    sys.exit(1 if failures else 0)


def connect(timeout=60):
    return socket.create_connection(('127.0.0.1', args.port), timeout=timeout)


def receive_all(s):
    data = b''
    try:
        while chunk := s.recv(262144):
            data += chunk
    except OSError:
        pass
    return data


def read_response(s, method=b'GET', pending=None):
    """Reads one response from s, as an HTTP client does: up to its
    Content-Length, its last chunk, or (for neither) the close. HEAD, 1xx,
    204 and 304 have no body. pending holds bytes already read and gets what
    was read past this response. Returns b'' when the server closed first."""
    buf = pending.pop() if pending else b''
    def more():
        nonlocal buf
        try:
            chunk = s.recv(262144)
        except OSError:
            chunk = b''
        buf += chunk
        return bool(chunk)
    while CRLF + CRLF not in buf:
        if not more():
            return buf
    head, _, rest = buf.partition(CRLF + CRLF)
    status, headers, _ = split(head + CRLF + CRLF)
    if 100 <= status < 200:
        if pending is not None:
            pending.append(rest)
        return read_response(s, method, [rest] if pending is None else pending)
    if method == b'HEAD' or status in (204, 304):
        length = 0
    elif 'content-length' in headers:
        length = int(headers['content-length'])
    elif headers.get('transfer-encoding') == 'chunked':
        while not dechunk_end(rest):
            if not more():
                break
            rest = buf.partition(CRLF + CRLF)[2]
        length = dechunk_end(rest) or len(rest)
    else:
        while more():
            pass
        rest = buf.partition(CRLF + CRLF)[2]
        length = len(rest)
    while len(rest) < length:
        if not more():
            break
        rest = buf.partition(CRLF + CRLF)[2]
    if pending is not None:
        pending.append(rest[length:])
    return head + CRLF + CRLF + rest[:length]


def dechunk_end(body):
    """The length of a chunked body up to and with its last chunk, or 0 when
    it has not all arrived."""
    at = 0
    while True:
        line_end = body.find(CRLF, at)
        if line_end < 0:
            return 0
        size = int(body[at:line_end].split(b';')[0] or b'0', 16)
        at = line_end + 2 + size + 2
        if size == 0:
            end = body.find(CRLF + CRLF, line_end)
            return end + 4 if end >= 0 else 0
        if at > len(body):
            return 0


def exchange(request, pieces=None, pause=0.5, timeout=60):
    """Sends request (in pieces, pause seconds apart, when given) and returns
    the response to it."""
    s = connect(timeout)
    first = (pieces or [request])[0]
    try:
        for i, piece in enumerate(pieces or [request]):
            if i:
                time.sleep(pause)
            s.sendall(piece)
    except OSError:
        pass
    data = read_response(s, first.split(b' ', 1)[0] if first else b'GET')
    s.close()
    return data


def split(data):
    """(status code, headers as a lower-case dict, body) of a response."""
    head, _, body = data.partition(CRLF + CRLF)
    lines = head.decode(errors='replace').split('\r\n')
    try:
        status = int(lines[0].split(' ')[1])
    except (IndexError, ValueError):
        status = 0
    headers = {}
    for line in lines[1:]:
        if ':' in line:
            name, value = line.split(':', 1)
            headers[name.strip().lower()] = value.strip()
    return status, headers, body


def get(path, *headers, method='GET', body=b'', protocol='HTTP/1.1'):
    request = (f'{method} {path} {protocol}\r\nHost: x\r\n'.encode() +
               b''.join(h.encode() + CRLF for h in headers))
    if body:
        request += f'Content-Length: {len(body)}\r\n'.encode()
    return split(exchange(request + CRLF + body))


def dechunk(body):
    """(data, whether it ended with the last chunk) of a chunked body."""
    out, rest = b'', body
    while True:
        line, sep, rest = rest.partition(CRLF)
        if not sep:
            return out, False
        size = int(line.split(b';')[0], 16)
        if size == 0:
            return out, rest == CRLF
        out += rest[:size]
        if rest[size:size + 2] != CRLF:
            return out, False
        rest = rest[size + 2:]


def chunked(data, sizes, extension=b''):
    out, i = [], 0
    for n in sizes:
        part = data[i:i + n]
        i += n
        if not part:
            break
        out.append(format(len(part), 'x').encode() + extension + CRLF + part + CRLF)
    if i < len(data):
        out.append(format(len(data) - i, 'X').encode() + CRLF + data[i:] + CRLF)
    return b''.join(out) + b'0' + CRLF + CRLF


def checksum(data):
    """Sums each byte weighted by its position mod 7, as the apps do."""
    return sum((k + 1) * sum(data[k::7]) for k in range(7))


def in_threads(*targets):
    threads = [threading.Thread(target=t) for t in targets]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
