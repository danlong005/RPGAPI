**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // static files: the test site at /web, the test files at /assets, and
   // the site again in a group, at /v2/static. A route below /web answers
   // for a path with no file behind it

dcl-ds app likeds(RPGAPI_App);

clear app;
testSettings(app);
   // run with CORS "missing": a directory that is not there stops the app
if testCorsOrigins = 'missing';
   RPGAPI_serveStatic(app : '/gone' : testWorkDir + '/no-such-directory');
endif;
RPGAPI_serveStatic(app : '/web' : testWorkDir + '/site');
RPGAPI_serveStatic(app : '/assets/' : testWorkDir + '/files/');
RPGAPI_get(app : '/web/api' : %paddr(api));
RPGAPI_setPrefix(app : '/v2');
RPGAPI_serveStatic(app : '/static' : testWorkDir + '/site');
RPGAPI_setPrefix(app : '');
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc api;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = 'api route';
   return response;
end-proc;

/include 'testcfg.rpgle'
