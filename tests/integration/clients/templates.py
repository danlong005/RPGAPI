"""ERPG templates (app: templates): a page with a view in it, escaping,
loops, <%%, -%>, a page over 32K, a view over an SQL cursor; and ERPG
itself: the code it generates, and the templates it refuses."""
from common import *
import os, subprocess

args = setup(__doc__)
LIB = os.environ.get('RPGAPI_TEST_LIB', 'RPGAPI')
VIEWS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'apps', 'views')

def page(title, rows):
    """What views/listpage.erpg with views/heading.erpg should write."""
    items = ''.join(f'  <li id="row{n}">Row {n} of {rows}</li>\n' for n in range(1, rows + 1))
    return ('<!DOCTYPE html>\n'
            f'<html><head><title>{title}</title></head>\n'
            '<body>\n'
            f'<h1>{title}</h1>\n'
            '<ul>\n' + items + '</ul>\n'
            '<p>It\'s "quoted", a\ttab, and Grüße</p>\n'
            '<p>A literal <% tag, and &lt;b&gt;&amp;&lt;/b&gt; escaped, <b>raw</b> not</p>\n'
            '</body></html>\n').encode()

status, headers, body = get('/page?title=Orders&rows=3')
body = dechunk(body)[0]
check('a page from a template, with a view in it, byte for byte',
      status == 200 and headers.get('content-type') == 'text/html; charset=utf-8' and body == page('Orders', 3),
      body.decode(errors='replace'))

status, headers, body = get('/page?title=' + '%3Cscript%3E%26%22%27%C3%BC&rows=1')
body = dechunk(body)[0]
check('<%= %> escapes & < > " and \' of a value, in the page and in the view',
      body == page('&lt;script&gt;&amp;&quot;&#39;ü', 1), body[:160])

status, headers, body = get('/page?title=Big&rows=2000')
body, complete = dechunk(body)
check('a page over 32K streams whole', complete and len(body) > 60000 and body == page('Big', 2000), len(body))

status, headers, body = get('/page?title=None&rows=0')
check('a loop that runs no times', dechunk(body)[0] == page('None', 0))

status, headers, body = get('/tables/QSYS2')
body = dechunk(body)[0].decode()
rows = body.count('<tr>')
check('a view looping over an SQL cursor: 5 rows of QSYS2', status == 200 and rows == 5 and
      body.startswith('<table>\n') and body.endswith('</table>\n') and '<td>SYSCOLUMNS' not in body[:0], body[:300])

# ERPG itself
generated = open(os.path.join(VIEWS, 'listpage.erpg.rpgle'), 'rb').read().decode()
lines = generated.split('\n')
check('the generated file is **free, dcl-proc listpage ... end-proc',
      lines[0] == '**free' and 'dcl-proc listpage;' in lines and lines[-2] == 'end-proc;', lines[:5])
check('every generated line names its template line',
      all('// listpage.erpg:' in line for line in lines[4:-2] if line),
      [l for l in lines[4:-2] if '// listpage.erpg:' not in l][:3])
check('no generated line is longer than 100 characters (RPGPPOPT(*LVL2) copies them into a file of 100)',
      max(len(line) for line in lines) <= 100, max(lines, key=len))
check('the declarations come first', lines[4].startswith('   dcl-pi *n;'), lines[4])
check('text with quotes, a tab and umlauts: doubled quotes, x\'05\', UTF-8',
      "It''s \"quoted\", a' + x'05' + 'tab, and Grüße" in generated, [l for l in lines if 'quoted' in l])

def run_erpg(path):
    """Runs ERPG on the template at path; its messages."""
    result = subprocess.run(['system', f"CALL PGM({LIB}/ERPG) PARM('{path}')"], capture_output=True, text=True)
    return result.stdout + result.stderr

def erpg(name, text):
    """Runs ERPG on a template with that name and text (bytes as they are,
    or text as UTF-8); its messages."""
    path = os.path.join(args.work, name)
    open(path, 'wb').write(text if isinstance(text, bytes) else text.encode())
    return run_erpg(path)

long_text = erpg('longtext.erpg', '<p>' + "it's " * 100 + '\t' * 30 + 'x' * 300 + '</p>\n')
long_lines = open(os.path.join(args.work, 'longtext.erpg.rpgle'), 'rb').read().decode().split('\n')
check('nor for long text full of quotes and tabs', 'ERPG wrote' in long_text and
      max(len(line) for line in long_lines) <= 100, max(long_lines, key=len))
out = erpg('broken.erpg', '<p>\n<% if a = 1; %>\n<%= a \n</p>\n')
check('an unclosed tag: CPF9898 naming the template and line', 'CPF9898' in out and 'broken.erpg:3' in out and
      'never closed' in out, out)
out = erpg('empty.erpg', '<p><%=   %></p>\n')
check('an empty <%= %>: refused with its line', 'CPF9898' in out and 'empty.erpg:1' in out, out)
out = erpg('bad-name.erpg', '<p>hi</p>\n')
check('a name that is not an RPG name: refused', 'CPF9898' in out and 'RPG name' in out, out)
out = erpg('notutf8.erpg', b'<p>\xff\xfe bad</p>\n')
check('bytes that are not UTF-8: refused', 'CPF9898' in out and 'not UTF-8' in out, out)
out = run_erpg(os.path.join(args.work, 'missing.erpg'))
check('a template that does not exist: refused', 'CPF9898' in out and 'cannot be opened' in out, out)
out = erpg('crlf.erpg', '<p>\r\n<% if 1 = 1; -%>\r\n  <b>yes</b>\r\n<% endif; -%>\r\n</p>\r\n')
crlf = open(os.path.join(args.work, 'crlf.erpg.rpgle'), 'rb').read().decode() if 'ERPG wrote' in out else ''
check('Windows line breaks: no CR in the generated code, -%> drops CR LF',
      'ERPG wrote' in out and '\r' not in crlf and "RPGAPI_write('  <b>yes</b>' + x'25');" in crlf, crlf or out)
done()
