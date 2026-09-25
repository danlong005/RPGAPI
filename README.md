# RPGAPI

## Description
A small RPGLE web framework for building web APIs on IBM i, in the spirit of
Express. You register routes and middleware as RPG procedures, start the
server, and each request is handed to your procedure as a data structure.

- Routes with `{params}` for GET, POST, PUT, PATCH and DELETE, and middleware
  for all routes or a path and everything below it
- UTF-8 on the wire, converted to and from the job's CCSID
- Request bodies up to 1MB in memory by default, and larger uploads streamed
  from the connection, with `Content-Length` or chunked encoding
- Forms with files (`multipart/form-data`), read part by part and saved to the
  IFS without holding them in memory
- Streamed responses of any size, and IFS files with caching headers and
  range requests
- Several jobs serving one port, and timeouts so one slow client cannot hold a
  job
- HTTPS, with a certificate from Digital Certificate Manager (DCM)
- Logging to the job log at four levels, down to every request's headers and
  routing, to find out what happened when a problem is reported

See the [Quick Start](QuickStart.md) to write and run a first app, and the
[API Documentation](ApiDocumentation.md) for everything else.

## Requirements
- IBM i 7.3 with TR10, or 7.4 with TR4, or later. RPGAPI uses `%SPLIT`,
  `%UPPER` and `%LOWER`, which came with those Technology Refreshes (the ILE
  RPG compiler and runtime PTFs for them: 7.3 SI76100 / SI76098, 7.4 SI76101 /
  SI76099). It is developed and tested on 7.5.
- The ILE RPG compiler, and `make` from the IBM i open source packages
  (`yum install make`) to build it

## Installation

1. Clone the repository in a shell on the IBM i (QShell or SSH):
```bash
cd /home/[youruser]
git clone https://github.com/danlong005/RPGAPI.git
```

2. Point `IFS_PATH` at your clone. Either edit the Makefile, or pass it on the
command line of the build in step 4, which overrides the value in the file:
```bash
make all IFS_PATH=/home/[youruser]/RPGAPI
```

3. Make sure the target library exists. The build writes into `LIB`, it does not
create it, so create one once up front:
```bash
system "CRTLIB LIB(RPGAPI)"
```
Or skip this and build into a library you already own, which is what you want on
a shared system such as PUB400 where `CRTLIB` is not authorized:
```bash
make all LIB=MYLIB IFS_PATH=/home/[youruser]/RPGAPI
```

4. Build the project:
```bash
make all
```

This will:
- Create the binding directory
- Set the proper CCSID on source files
- Compile the RPGAPI module (`CRTRPGMOD ... TGTCCSID(*JOB)`)
- Create the service program
- Add it to the binding directory

If `LIB` does not exist the build stops immediately and tells you so, rather than
failing later with a confusing compile error.

5. (Optional) Run tests:
```bash
make test
```
This needs [iRPGUnit](https://github.com/tools-400/irpgunit) installed in library
`RPGUNIT`; the target fails immediately with `CPF2110` if it is missing.

6. (Optional) Remove the objects the build created (the module, service program,
binding directory and test program):
```bash
make clean
```
The library itself is never deleted. The build does not create it, so it does not
own it, and `LIB` is often a library holding your other work. Drop it yourself
with `DLTLIB` if you really mean to.

### Makefile variables
| Variable | Default | Purpose |
| --- | --- | --- |
| `LIB` | `RPGAPI` | Existing library the module, service program and binding directory are built into |
| `BNDDIR` | `RPGAPI` | Binding directory name. Kept separate from `LIB` so building into a shared library does not create a binding directory named after it |
| `IFS_PATH` | `/home/longdm/builds/RPGAPI` | Absolute IFS path of your clone |

## Building and running an app
Include `rpgapi_h.rpgle` from the clone's `qrpglesrc` directory, bind to the
`RPGAPI` binding directory, and compile with `TGTCCSID(*JOB)` (see Character
sets below):
```
CRTBNDRPG PGM(MYLIB/MYAPP) SRCSTMF('/home/[youruser]/myapp.rpgle')
          INCDIR('/home/[youruser]/RPGAPI/qrpglesrc') TGTCCSID(*JOB)
```
The library holding the binding directory has to be in the library list while
you compile, or name it in the program: `ctl-opt bnddir('MYLIB/RPGAPI')`.

`RPGAPI_start` serves requests until the job ends, so run the app in its own
job and end that job to stop it:
```
SBMJOB CMD(CALL PGM(MYLIB/MYAPP)) JOB(MYAPP)
ENDJOB JOB(MYAPP)
```
[QuickStart.md](QuickStart.md) walks through this with a first app, and
`qrpglesrc/app.sqlrpgle` is a larger example with middleware, a route param
and SQL.

### Character sets
RPGAPI sends and receives UTF-8, and converts it to and from the CCSID of the
job the server runs in. The library is compiled with `TGTCCSID(*JOB)` so that
its own text is in that CCSID too. Compile your application the same way, as
above. For SQL RPG use `CRTSQLRPGI ... CVTCCSID(*JOB) COMPILEOPT('TGTCCSID(*JOB)')`.

Without it, the literals of a program compiled from an IFS file are in CCSID 37
whatever the job's CCSID is. In a job that is not CCSID 37 (for example 273),
characters such as `[ ] { } @ \ |` and accented letters in those literals are
then sent wrong, and `{name}` route params do not match.

## HTTPS (TLS)
RPGAPI serves HTTPS through the IBM i Global Security Kit (GSKit), with a
certificate kept in Digital Certificate Manager (DCM). Without the setup below
it serves plain HTTP, as before.

> **Status:** the TLS code is built and bound against GSKit, and setting it up
> with a missing keystore or an unregistered application ID fails with the
> messages shown under Troubleshooting. A full HTTPS exchange with a DCM
> certificate has not been run yet: the system RPGAPI is developed on gives no
> access to DCM. Please report how it goes.

### What you need
- A user profile with `*ALLOBJ` and `*SECADM` special authority to work in
  DCM, once, for the setup. The job that runs your app does not need them.
- A server certificate: one from a public certificate authority (as a
  `.p12` / `.pfx` file with its private key), or one issued by a local CA that
  DCM creates for you (fine for internal use; clients must trust that CA).
- A port for HTTPS. 443 is often taken by the IBM HTTP Server; any free port,
  such as 8443, works.

### 1. Open DCM
Start the HTTP administration server, then open DCM in a browser:
```
STRTCPSVR SERVER(*HTTP) HTTPSVR(*ADMIN)
```
- IBM i 7.4 and later: `http://your-ibm-i:2001/dcm` (or
  `https://your-ibm-i:2010/dcm`)
- IBM i 7.3: `http://your-ibm-i:2001/QIBM/ICSS/Cert/Admin/qycucm1.ndm/main0`

### 2. Put a server certificate in the *SYSTEM store
Open the `*SYSTEM` certificate store (create it if DCM offers to, and note the
password you give it). Then either:
- **import** your CA's certificate: import the `.p12` / `.pfx` file, and the
  CA's own certificates (root and intermediates) if DCM asks for them; or
- **create** one: create a local certificate authority if there is none,
  then create a server certificate signed by it. Give it the host name
  clients will use as its common name.

A PKCS#12 file cannot be used by RPGAPI directly as a keystore (GSKit refuses
it); it has to be imported into a DCM store first.

### 3. Create an application definition
In DCM, create a **server** application definition for your app, and pick an
application ID. IBM's convention is upper case, company and product, such as
`MYCO_RPGAPI_ORDERS`. Each app, or each port, can have its own.

### 4. Assign the certificate to it
Assign the certificate from step 2 to the application ID from step 3
(Update certificate assignment in DCM).

### 5. Use it in your app
Before `RPGAPI_start`:
```
RPGAPI_setTlsApplication(app : 'MYCO_RPGAPI_ORDERS');
RPGAPI_start(app : 8443);
```
Protocols and ciphers are those the system allows (system values `QSSLPCL`
and `QSSLCSL`, and any limits on the application definition). With several
jobs (`RPGAPI_start(app : 8443 : 4)`) each job sets up TLS the same way, as
they run your program too.

Instead of an application ID you can name a certificate store file, its
password, and the label of the certificate in it (its default certificate
when left out). This needs no application definition, but puts the password
in your program:
```
RPGAPI_setTlsKeystore(app : '/QIBM/USERDATA/ICSS/CERT/SERVER/DEFAULT.KDB' :
                      'store password' : 'MYCO_ORDERS_CERT');
```

### 6. Test it
```bash
curl -v https://your-ibm-i:8443/hello
# a local CA's certificate: give curl the CA certificate, exported from DCM
curl --cacert local-ca.pem https://your-ibm-i:8443/hello
```

### Troubleshooting
If TLS cannot be set up, `RPGAPI_start` ends with escape message `CPF9898`
giving GSKit's reason, like:
```
TLS could not be set up, gsk_environment_init failed: Application identifier
is not registered to use TLS. (GSKit 6002).
```
| GSKit | Meaning, and what to check |
| --- | --- |
| 6002 | The application ID is not registered: check its spelling, and that the definition exists in DCM (step 3) |
| 6003 | The job's user profile may not use the certificate or store: check its authority to the application definition and the certificate store file |
| 202 | The keystore file was not found (`RPGAPI_setTlsKeystore`) |
| 408 | The keystore password is wrong |
| 403 | No certificate is assigned (step 4), or the label names none |
| 406 | An I/O error; the message adds the system's reason. A `.p12` file named as a keystore gives this |

A client whose handshake fails, such as one sending plain `http://` to the
HTTPS port, is disconnected without an answer; the server carries on. With
`RPGAPI_setLogLevel(app : RPGAPI_LOG_WARN)` or more, such handshakes are
logged with GSKit's reason.

### Upgrading
**The settings moved into `RPGAPI_App`.** Programs compiled against an
earlier `rpgapi_h.rpgle` have to be recompiled; they fail to start with a
signature error until they are. The setters now take the app first:
`RPGAPI_setMaxRequestSize(app : bytes)`, `RPGAPI_setMaxUploadSize(app : bytes)`,
`RPGAPI_setTlsApplication(app : id)` and `RPGAPI_setTlsKeystore(app : ...)`.
See Settings in the [API Documentation](ApiDocumentation.md).
