**free
   // Middleware: every path under /api needs the header X-Api-Key with the
   // right key, or gets 401 with a JSON error. /health stays public. Logging
   // at INFO puts one line per request in the job log.
   //
   // Build:
   //   CRTBNDRPG PGM(MYLIB/APIKEY) SRCSTMF('<clone>/examples/api-key.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // Run:
   //   SBMJOB CMD(CALL PGM(MYLIB/APIKEY)) JOB(APIKEY)
   // Try:
   //   curl http://your-ibm-i:8080/health                                 -> ok
   //   curl -i http://your-ibm-i:8080/api/orders                          -> 401
   //   curl -H 'X-Api-Key: change-me' http://your-ibm-i:8080/api/orders   -> the orders
   //   DSPJOBLOG for the APIKEY job, to see the log lines

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

   // keep a real key out of the source: read it from a data area or a table
dcl-c API_KEY 'change-me';

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setLogLevel(app : RPGAPI_LOG_INFO);
RPGAPI_setMiddleware(app : '/api' : %paddr(checkKey));
RPGAPI_get(app : '/health' : %paddr(health));
RPGAPI_get(app : '/api/orders' : %paddr(orders));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


   // runs before every route under /api. Returning *off ends the request
   // with the response set here
dcl-proc checkKey;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;

   if RPGAPI_getHeader(request : 'X-Api-Key') = API_KEY;
      return *on;
   endif;
   response.status = HTTP_UNAUTHORIZED;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = '{"error":"a valid X-Api-Key header is needed"}';
   return *off;
end-proc;


dcl-proc health;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = 'ok';
   return response;
end-proc;


dcl-proc orders;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = '[{"order":1001,"status":"shipped"},' +
                   '{"order":1002,"status":"open"}]';
   return response;
end-proc;
