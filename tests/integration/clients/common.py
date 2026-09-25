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


def exchange(request, pieces=None, pause=0.5, timeout=60):
    """Sends request (in pieces, pause seconds apart, when given) and returns
    everything the server sends back until it closes."""
    s = connect(timeout)
    try:
        for i, piece in enumerate(pieces or [request]):
            if i:
                time.sleep(pause)
            s.sendall(piece)
    except OSError:
        pass
    data = receive_all(s)
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
