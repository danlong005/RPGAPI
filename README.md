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

### Upgrading
New versions of the service program keep the signatures of the earlier ones,
so programs bound to an older RPGAPI keep running without being recompiled.
Recompile a program to use procedures added since.
