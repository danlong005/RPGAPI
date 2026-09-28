"""Views (app: templates): RPGAPI_render compiling templates at runtime and
passing them the route's data structure. A page byte for byte, with a view
for its heading and one for each row (given pointers to parts of the data);
escaping; a page over 32K; numbers and dates read in place; a view with no
data and its own SQL; the route's status and headers; a view compiled again
when it or its copybook changes; the error pages; ERPG ahead of time."""
from common import *
import os, subprocess, time

args = setup(__doc__)
LIB = os.environ.get('RPGAPI_TEST_LIB', 'RPGAPI')
VIEWS = os.path.join(args.work, 'views')

def body_of(response):
    status, headers, body = response
    if headers.get('transfer-encoding') == 'chunked':
        body = dechunk(body)[0]
    return status, headers, body

def page(title, rows):
    """What views/listpage.erpg with views/heading.erpg should write."""
    items = ''.join(f'  <li id="row{n}">Row {n}</li>\n' for n in range(1, rows + 1))
    return ('<!DOCTYPE html>\n'
            f'<html><head><title>{title}</title></head>\n'
            '<body>\n'
            f'<h1>{title}</h1>\n'
            '<ul>\n' + items + '</ul>\n'
            '<p>It\'s "quoted", a\ttab, and Grüße</p>\n'
            '<p>A literal <% tag, and &lt;b&gt;&amp;&lt;/b&gt; escaped, <b>raw</b> not</p>\n'
            '</body></html>\n').encode()

def write_view(name, text):
    open(os.path.join(VIEWS, name), 'wb').write(text.encode())

def erpg(name):
    result = subprocess.run(['system', f"CALL PGM({LIB}/ERPG) PARM('{os.path.join(VIEWS, name)}' '{LIB}')"],
                            capture_output=True, text=True)
    return result.stdout + result.stderr

# the first request compiles listpage.erpg, heading.erpg and item.erpg
start = time.time()
status, headers, body = body_of(get('/page?title=Orders&rows=3'))
first = time.time() - start
check('a page from a template, with views for its heading and each row, byte for byte',
      status == 200 and headers.get('content-type') == 'text/html; charset=utf-8' and body == page('Orders', 3),
      (status, headers, body.decode(errors='replace')))
start = time.time()
status, headers, body = body_of(get('/page?title=Orders&rows=3'))
again = time.time() - start
check('the next request uses the compiled programs: no compile', body == page('Orders', 3) and again < 2,
      (round(first, 1), round(again, 1)))

status, headers, body = body_of(get('/page?title=' + '%3Cscript%3E%26%22%27%C3%BC&rows=1'))
check('<%= %> escapes & < > " and \' of a value, in the page and in the included view',
      body == page('&lt;script&gt;&amp;&quot;&#39;ü', 1), body[:160])
status, headers, body = body_of(get('/page?title=Big&rows=2000'))
check('a page over 32K: 2000 rows, each a view given its own row', len(body) > 60000 and body == page('Big', 2000), len(body))
status, headers, body = body_of(get('/page?title=None&rows=0'))
check('an empty list: no rows', body == page('None', 0), body[:200])

status, headers, body = body_of(get('/people?max=4'))
check('numbers and dates read in place from the route\'s data structure',
      body == b'1|Anna &amp; Co|13.50|31.01.2024\n2|&lt;b&gt;|-2.00|01.06.2025\n3|Cy|1.00|01.01.0001\n'
              b'count=3\n', body.decode(errors='replace'))
status, headers, body = body_of(get('/people?max=1'))
check('the count the route set', body == b'1|Anna &amp; Co|13.50|31.01.2024\ncount=1\n', body.decode(errors='replace'))

status, headers, body = body_of(get('/nodata/sqlview'))
text = body.decode(errors='replace')
check("a view with no data and its own SQL (compiled with CRTSQLRPGI)",
      status == 200 and text.count('<li>') == 3 and text.endswith('<p>3 tables</p>\n'), text)

status, headers, body = body_of(get('/custom'))
check("the route's status and headers", status == 201 and headers.get('x-view') == 'custom' and
      headers.get('content-type') == 'text/plain; charset=utf-8' and body == b'<h1>Custom</h1>\n', (status, headers, body))

# text of only blanks between tags stays where it is (a varchar of blanks
# compares equal to '' in RPG)
write_view('blanks.erpg', "<%= 'a' %> <%= 'b' %>  <%- 'c' %>\n <% if 1 = 1; %> <% endif; %>|\n")
status, headers, body = body_of(get('/nodata/blanks'))
check('blanks between tags are written where they are', body == b'a b  c\n  |\n', body)

# a template that changes is compiled again
TITLE = "<%! dcl-s title varchar(100) based(RPGAPI_data); -%>\n"
write_view('changed.erpg', TITLE + "one <%= title %>\n")
one = body_of(get('/view/changed'))[2]
time.sleep(1.1)
write_view('changed.erpg', TITLE + "two <%= title %>\n")
two = body_of(get('/view/changed'))[2]
check('a template that changes is compiled again', (one, two) == (b'one T\n', b'two T\n'), (one, two))

write_view('greeting.rpgleinc', "**free\ndcl-c GREETING 'hello';\n")
write_view('greet.erpg', "<%! /include 'greeting.rpgleinc' -%>\n<%= GREETING %>\n")
one = body_of(get('/nodata/greet'))[2]
time.sleep(1.1)
write_view('greeting.rpgleinc', "**free\ndcl-c GREETING 'bye';\n")
two = body_of(get('/nodata/greet'))[2]
check('a view is compiled again when only its copybook changes', (one, two) == (b'hello\n', b'bye\n'), (one, two))

write_view('broken.erpg', "<p>\n<%! dcl-s shown int(10:0); -%>\n<%= nosuchname %>\n</p>\n")
status, headers, body = body_of(get('/view/broken'))
text = body.decode(errors='replace')
check('a template that does not compile: 500 with the error at its template line',
      status == 500 and 'broken.erpg:3' in text and 'RNF7030' in text and 'NOSUCHNAME' in text.upper(), text)
write_view('unclosed.erpg', "<p>\n<% if 1 = 1;\n</p>\n")
status, headers, body = body_of(get('/view/unclosed'))
text = body.decode(errors='replace')
check('an unclosed tag: 500 naming its line', status == 500 and 'unclosed.erpg:2' in text and 'never closed' in text,
      text)
status, headers, body = body_of(get('/view/missing'))
check('a template that does not exist: 500', status == 500 and b'cannot be read' in body, body[:300])
status, headers, body = body_of(get('/page?title=After&rows=1'))
check('pages still render after the errors', body == page('After', 1), body[:100])

# ERPG, ahead of time
out = erpg('heading.erpg')
check('ERPG compiles a view ahead of time', 'CPF9897' in out and 'ERPG compiled' in out and f'{LIB}/RV' in out, out)
out = erpg('broken.erpg')
check('ERPG on a template that does not compile: CPF9898 with the error at its line',
      'CPF9898' in out and 'broken.erpg:3' in out, out)
done()
