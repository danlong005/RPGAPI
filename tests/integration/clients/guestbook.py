"""The guestbook example (examples/guestbook.rpgle): a view without SQL, its
list built row by row from an RPG array; a form posted back, escaped, and
refused with 400 when a field is missing."""
from common import *

args = setup(__doc__)
FORM = 'Content-Type: application/x-www-form-urlencoded'

def page():
    status, headers, body = get('/guestbook')
    return status, headers, dechunk(body)[0].decode()

status, headers, text = page()
check('an empty guestbook: the form, and no notes yet', status == 200 and
      headers.get('content-type') == 'text/html; charset=utf-8' and '<h1>Guestbook</h1>' in text and
      '<form method="post" action="/guestbook">' in text and 'No one has signed yet' in text, text[-400:])

status, headers, body = get('/guestbook', FORM, method='POST', body=b'name=Anna&message=%3Cb%3EHi%3C%2Fb%3E+%26+more')
check('signing: redirected back to the page (303)', status == 303 and headers.get('location') == '/guestbook',
      (status, headers))
status, headers, text = page()
check('the note, with what was typed escaped', '<p>&lt;b&gt;Hi&lt;/b&gt; &amp; more</p>' in text and
      '&mdash; Anna, ' in text and '1 note so far' in text and 'No one has signed' not in text, text[-500:])

get('/guestbook', FORM, method='POST', body=b'name=Bo&message=Second')
status, headers, text = page()
check('newest first, and the count', text.index('Second') < text.index('&lt;b&gt;Hi') and '2 notes so far' in text,
      text[-600:])

status, headers, body = get('/guestbook', FORM, method='POST', body=b'name=&message=Nobody')
text = dechunk(body)[0].decode()
check('a field missing: 400, the page with what is wrong', status == 400 and
      'Please give your name and a message.' in text and '2 notes so far' in text, (status, text[-400:]))
done()
