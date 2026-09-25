"""TLS off (app: tls started without TLS): plain HTTP works and HTTPS
does not. The set-up failures are checked by the runner."""
from common import *
import subprocess

args = setup(__doc__)
status = get('/hello', 'X-Scheme: http')[0]
check('plain HTTP works without TLS', status == 200)
out = subprocess.run(['curl', '-s', '-k', '-m', '10', '-o', '/dev/null', '-w', '%{http_code}',
                      f'https://127.0.0.1:{args.port}/hello'], capture_output=True, text=True).stdout
check('HTTPS does not', out == '000', out)
done()
