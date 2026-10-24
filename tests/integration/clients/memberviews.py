"""The guestbook example kept in source members (app: EXGUESTM, built by
run.sh): the app, and the copybooks its views include, are members of
LIB/QTESTSRC; only the templates are in the IFS. The page works, a view is
not compiled again while nothing changes, and is when only a member it
includes changes."""
from common import *
import os, subprocess

args = setup(__doc__)
LIB = os.environ.get('RPGAPI_TEST_LIB', 'RPGAPI')


def views():
    """The view programs in LIB compiled from a template named guestbook.erpg."""
    out = subprocess.run(['/QOpenSys/usr/bin/qsh', '-c', "db2 \"select objname from table("
                          f"qsys2.object_statistics('{LIB}', '*PGM')) x where objname like 'RV%' "
                          "and objtext like '% guestbook.erpg%'\""], capture_output=True, text=True).stdout
    return {line.strip() for line in out.split('\n') if line.strip().startswith('RV')}


status, headers, body = get('/guestbook')
text = body.decode(errors='replace')
check('a page from views that include members, for an app in a member',
      status == 200 and '<form method="post" action="/guestbook">' in text and 'No one has signed yet' in text,
      (status, text[-300:]))
status, headers, body = get('/guestbook', 'Content-Type: application/x-www-form-urlencoded',
                            method='POST', body=b'name=Anna&message=Hello')
status, headers, body = get('/guestbook')
check('a note signed is on the page', status == 200 and 'Anna' in body.decode(errors='replace'), status)

before = views()
get('/guestbook')
check('nothing changed: not compiled again', views() == before, (before, views()))

# a comment more in the member the guestbook view includes: the view's
# source is the same, only its copybook changed
copybook = os.path.join(args.work, 'guestbook_t.rpgleinc')
with open(copybook, 'a') as f:
    f.write('   // changed by the test\n')
subprocess.run(['system', f"CPYFRMSTMF FROMSTMF('{copybook}') "
                f"TOMBR('/QSYS.LIB/{LIB}.LIB/QTESTSRC.FILE/GUEST_T.MBR') MBROPT(*REPLACE)"],
               capture_output=True)
status, headers, body = get('/guestbook')
after = views()
check('a member it includes changed: compiled again, and the older version deleted',
      status == 200 and len(after - before) == 1 and len(before - after) == 1, (before, after))
check('and the page is the same', 'Anna' in body.decode(errors='replace'), status)
done()
