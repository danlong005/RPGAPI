# Quick Start

A first RPGAPI app: one route that answers `GET /hello`, built and run in a
batch job. It assumes RPGAPI is built into library `RPGAPI` from a clone in
`/home/[youruser]/RPGAPI` (see the [README](README.md)), and uses port 3017.

## 1. Write the program
Save this as `/home/[youruser]/hello.rpgle`:

```
**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI/RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/hello' : %paddr(hello));
RPGAPI_get(app : '/hello/{name}' : %paddr(hello));

   // serves requests until the job is ended
RPGAPI_start(app : 3017);

*inlr = *on;
return;


dcl-proc hello;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
      // a new, empty response for every request: inz sets the status to 0
      // and leaves no headers from a previous request behind
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s name varchar(1024);

   name = RPGAPI_getParam(request : 'name');
   if name = '';
      name = 'world';
   endif;

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   response.body = 'hello ' + name;
   return response;
end-proc;
```

## 2. Compile it
From a 5250 command line, or with `system "..."` in QShell:
```
CRTBNDRPG PGM(MYLIB/HELLO) SRCSTMF('/home/[youruser]/hello.rpgle')
          INCDIR('/home/[youruser]/RPGAPI/qrpglesrc') TGTCCSID(*JOB)
```
`TGTCCSID(*JOB)` keeps the program's text in the job's CCSID, which RPGAPI
expects (see Character sets in the README).

## 3. Run it
```
SBMJOB CMD(CALL PGM(MYLIB/HELLO)) JOB(HELLO)
```
and try it:
```bash
curl http://your-ibm-i:3017/hello           # hello world
curl http://your-ibm-i:3017/hello/Dan       # hello Dan
curl -i http://your-ibm-i:3017/nothing      # 404 Not Found
```

## 4. Stop it
```
ENDJOB JOB(HELLO)
```

## Next
- Serve several requests at once: `RPGAPI_start(app : 3017 : 4)` runs 4 jobs
- Read a JSON body with `request.body`, or stream large ones with
  `RPGAPI_readBody`
- Send large results with `RPGAPI_beginResponse` / `RPGAPI_write`, and files
  with `RPGAPI_sendFile`
- Serve HTTPS: set up a certificate in DCM and call `RPGAPI_setTlsApplication`
  before `RPGAPI_start` (see HTTPS (TLS) in the [README](README.md))

All of it is in the [API Documentation](ApiDocumentation.md).
