**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // HEAD, OPTIONS and CORS. /items needs an X-Key, so a preflight that
   // reached the middleware would be refused

dcl-ds app likeds(RPGAPI_App);

clear app;
testSettings(app);
RPGAPI_setCors(app : testCorsOrigins);
if testCorsOrigins <> '*';
   app.cors_credentials = *on;
   app.cors_max_age = 600;
   app.cors_expose_headers = 'X-Total';
endif;
RPGAPI_setMiddleware(app : '/items' : %paddr(needKey));
RPGAPI_get(app : '/items' : %paddr(items));
RPGAPI_post(app : '/items' : %paddr(items));
RPGAPI_get(app : '/items/{id}' : %paddr(items));
RPGAPI_put(app : '/items/{id}' : %paddr(items));
RPGAPI_setRoute(app : HTTP_OPTIONS : '/custom' : %paddr(custom));
RPGAPI_get(app : '/stream' : %paddr(stream));
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc needKey;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;
   if RPGAPI_getHeader(request : 'X-Key') = 'k';
      return *on;
   endif;
   response.status = HTTP_UNAUTHORIZED;
   response.body = 'key needed';
   return *off;
end-proc;

dcl-proc items;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'X-Total' : '2');
   response.body = %trim(request.method) + ' items ' +
                   RPGAPI_getParam(request : 'id');
   return response;
end-proc;

dcl-proc custom;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = HTTP_OK;
   response.body = 'custom options';
   return response;
end-proc;

dcl-proc stream;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s index int(10:0);
   RPGAPI_beginResponse(response);
   for index = 1 to 1000;
      RPGAPI_write('line ' + %char(index) + x'25');
   endfor;
   RPGAPI_endResponse();
   return response;
end-proc;

/include 'testcfg.rpgle'
