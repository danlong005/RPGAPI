**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // TLS set-up: the failures, and plain HTTP without it
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/hello' : %paddr(hello));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc hello;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = 'hello over ' + RPGAPI_getHeader(request : 'X-Scheme');
   return response;
end-proc;

/include 'testcfg.rpgle'
