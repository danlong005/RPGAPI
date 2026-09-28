**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // security headers. The CORS setting picks the Content-Security-Policy:
   // blank for the default, "custom" for one of its own, "none" for none

dcl-ds app likeds(RPGAPI_App);

clear app;
testSettings(app);
select;
when testCorsOrigins = 'custom';
   RPGAPI_setSecurityHeaders(app : 'default-src ''none''');
when testCorsOrigins = 'none';
   RPGAPI_setSecurityHeaders(app : '');
other;
   RPGAPI_setSecurityHeaders(app);
endsl;
RPGAPI_get(app : '/plain' : %paddr(plain));
RPGAPI_get(app : '/own' : %paddr(own));
RPGAPI_get(app : '/stream' : %paddr(stream));
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc plain;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = 'plain';
   return response;
end-proc;

   // sets two of the headers itself
dcl-proc own;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Security-Policy' : 'frame-ancestors *');
   RPGAPI_setHeader(response : 'x-frame-options' : 'ALLOW-FROM x');
   response.body = 'own';
   return response;
end-proc;

dcl-proc stream;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   RPGAPI_beginResponse(response);
   RPGAPI_write('streamed');
   RPGAPI_endResponse();
   return response;
end-proc;

/include 'testcfg.rpgle'
