**free
   // Every setting in one place, as for a server in production: several
   // jobs, limits, timeouts, logging and HTTPS. Each is optional; the
   // comments give the defaults.
   //
   // Build:
   //   CRTBNDRPG PGM(MYLIB/MYAPI) SRCSTMF('<clone>/examples/production.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // Run: every job serving the port runs this program, so start one and it
   // starts the rest; end that one and they all end.
   //   SBMJOB CMD(CALL PGM(MYLIB/MYAPI)) JOB(MYAPI)
   //   ENDJOB JOB(MYAPI)

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds app likeds(RPGAPI_App);

clear app;
app.port = 8443;                                // 3000
app.jobs = 4;                                   // 1: one request at a time
RPGAPI_setLogLevel(app : RPGAPI_LOG_WARN);      // off; INFO or DEBUG to look into a problem
RPGAPI_setMaxRequestSize(app : 2000000);        // 1MB of body read into memory
RPGAPI_setMaxUploadSize(app : 0);               // 0: no larger uploads
RPGAPI_setTimeouts(app : 20 : 60);              // 30 and 30 seconds
RPGAPI_setKeepAlive(app : 10 : 500);            // 5 seconds, 100 requests

   // HTTPS, with a certificate assigned to this application ID in Digital
   // Certificate Manager (see HTTPS in the README). Without it: plain HTTP
// RPGAPI_setTlsApplication(app : 'MYCO_RPGAPI_MYAPI');

RPGAPI_get(app : '/status' : %paddr(status));
RPGAPI_start(app);

*inlr = *on;
return;


dcl-proc status;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = '{"status":"up","host":"' + %trim(request.hostname) + '"}';
   return response;
end-proc;
