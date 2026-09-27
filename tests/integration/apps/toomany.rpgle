**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // registers one route or middleware more than the app holds: must end
   // with an error instead of dropping it. Which one: the CORS setting,
   // routes or middleware

dcl-ds app likeds(RPGAPI_App);
dcl-s index int(10:0);

clear app;
testSettings(app);
if testCorsOrigins = 'middleware';
   for index = 1 to %elem(app.middlewares) + 1;
      RPGAPI_setMiddleware(app : '/m' + %char(index) : %paddr(pass));
   endfor;
else;
   for index = 1 to %elem(app.routes) + 1;
      RPGAPI_get(app : '/r' + %char(index) : %paddr(answer));
   endfor;
endif;
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc pass;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;
   return *on;
end-proc;

dcl-proc answer;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = 200;
   return response;
end-proc;

/include 'testcfg.rpgle'
