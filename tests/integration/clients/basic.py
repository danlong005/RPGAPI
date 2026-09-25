"""Requests and responses: requests in pieces, bodies, trailing @, UTF-8
and CCSID conversion (app: basic)."""
from common import *

args = setup(__doc__)
H = b'Host: x\r\n'
BIG = b'START' + b'x' * 19990 + b'END@@'

def body(data):
    return split(data)[2]

check('GET in one piece', body(exchange(b'GET /hello HTTP/1.1\r\n' + H + CRLF)) == b'hello')
check('request line split across reads',
      body(exchange(None, [b'GET /hel', b'lo HTTP/1.1\r\n' + H + CRLF])) == b'hello')

def post(length):
    return b'POST /echo HTTP/1.1\r\n' + H + f'Content-Length: {length}\r\n\r\n'.encode()

got = body(exchange(post(12) + b'hello world@'))
check('small body ending in @', got == b'len=12 head=hello tail=orld@', got)
got = body(exchange(None, [post(len(BIG)), BIG]))
check('20,000-byte body after the headers', got == b'len=20000 head=START tail=END@@', got)
got = body(exchange(None, [post(len(BIG)) + BIG[:7000], BIG[7000:14000], BIG[14000:]]))
check('20,000-byte body in 3 pieces', got == b'len=20000 head=START tail=END@@', got)

status, headers, got = split(exchange(b'GET /at HTTP/1.1\r\n' + H + CRLF))
check('response ending in @@ is sent whole',
      got == b'user@example.com @@' and headers.get('content-length') == '19', (headers, got))

def show(data):
    return body(exchange(b'POST /show HTTP/1.1\r\n' + H +
                         f'Content-Length: {len(data)}\r\n\r\n'.encode() + data))

got = show(b'{\r\n  "name": "john",\n  "age": 30\r\n}')
check('multi-line body keeps its line breaks',
      got == b'len=35 <{<CR><LF>  "name": "john",<LF>  "age": 30<CR><LF>}>', got)
got = show(b'  two spaces each side  ')
check('body keeps its edge spaces', got == b'len=24 <  two spaces each side  >', got)
got = show('{"name":"J\u00fcrgen"}'.encode())
check('UTF-8 request body arrives as 17 characters',
      got == 'len=17 <{"name":"J\u00fcrgen"}>'.encode(), got)

status, headers, got = split(exchange(b'GET /json HTTP/1.1\r\n' + H + CRLF))
expected = '{"list":[1,2],"mail":"a@b","path":"C:\\\\dir","or":"a|b","name":"J\u00fcrgen"}'.encode()
check('JSON literal with [ ] { } @ \\ | and a u-umlaut is sent as UTF-8',
      got == expected and headers.get('content-length') == str(len(expected)), got)
done()
