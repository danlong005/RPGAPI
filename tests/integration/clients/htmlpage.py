"""The HTML page example (examples/html-page.rpgle): a list from the SQL
catalog rendered by views/tablelist.erpg, which includes views/pagetop.erpg,
compiled at runtime and gzipped for a browser."""
from common import *
import gzip

args = setup(__doc__)

status, headers, body = get('/tables/qsys2', 'Accept-Encoding: gzip')
page = gzip.decompress(dechunk(body)[0]).decode()
check('the page is HTML, gzipped', status == 200 and headers.get('content-type') == 'text/html; charset=utf-8' and
      headers.get('content-encoding') == 'gzip', headers)
check('pagetop: the head and the heading', page.startswith('<!DOCTYPE html>\n<html lang="en">') and
      '<title>Tables in QSYS2</title>' in page and '<h1>Tables in QSYS2</h1>' in page, page[:300])
rows = page.count('<tr><td>')
check('tablelist: a row for each table and view, and their count', rows > 100 and
      '<tr><td>SYSTABLES</td><td>View</td>' in page and page.count('<td>20') >= rows and f'<p>{rows} tables and views</p>' in page and
      page.endswith('</body>\n</html>\n'), (rows, page[-200:]))
status, headers, body = get('/tables/NOSUCHLIB')
page = dechunk(body)[0].decode()
check('a library with no tables: the page, with 0', '<p>0 tables and views</p>' in page and
      page.count('<tr><td>') == 0, page[-200:])
done()
