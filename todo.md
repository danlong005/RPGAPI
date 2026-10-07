# TODO

## Blocked
- [ ] Run `make test` (needs iRPGUnit in library `RPGUNIT`). The integration
  tests (`tests/integration`, `make integration`) run without it. iRPGUnit is not
  installed on PUB400. Needs another IBM i that has it, or iRPGUnit installed into
  a library we own on PUB400 (the Makefile hard-codes `RPGUNIT`)
  The test program is compiled with the default `TGTCCSID`, so on a system
  whose job CCSID is not 37 it probably needs `TGTCCSID(*JOB)` as well

## Features
- [ ] Run HTTPS end to end on a system with DCM access: assign a certificate to
  an application ID, `RPGAPI_setTlsApplication`, then the request, upload,
  streaming, file and worker tests over `https://` (curl, a browser). PUB400
  gives no DCM access, and GSKit there refuses a PKCS#12 file made with
  OpenSSL (GSKit 406, errno 3474), so this has not been run

- [ ] Get the unit tests running: make the iRPGUnit library a Makefile
  variable, try installing iRPGUnit into a library we own on PUB400, and run
  the tests added since (they have never been compiled)


## Cleanup
- [ ] The unit tests in `qtestsrc` have never been compiled or run: check they
  still match the code (e.g. `RPGAPI_urlDecode` now takes 32,000 characters)
  when iRPGUnit is available (see Features)

## PUB400
- [ ] `BUILD`, `QRPGLESRC` and `RPGWEB` in library `RPGAPI` survive `CLRLIB`
  (`LONGDM` is not authorized to them). Removing them needs their owner, or
  authority granted to `LONGDM`
