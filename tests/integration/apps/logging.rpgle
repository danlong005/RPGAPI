**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // logging at each level, and the parse of headers and query params
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setMiddleware(app : '*' : %paddr(audit));
RPGAPI_get(app : '/hello' : %paddr(hello));
RPGAPI_get(app : '/hello/{name}' : %paddr(hello));
RPGAPI_get(app : '/boom' : %paddr(boom));
RPGAPI_post(app : '/echo' : %paddr(echo));
RPGAPI_get(app : '/count' : %paddr(count));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc audit;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;
   return *on;
end-proc;

dcl-proc hello;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = HTTP_OK;
   response.body = 'hello ' + RPGAPI_getParam(request : 'name');
   return response;
end-proc;

dcl-proc boom;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s zero int(10:0) inz(0);
   response.status = 10 / zero;
   return response;
end-proc;

dcl-proc echo;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = HTTP_OK;
   response.body = 'got ' + %char(RPGAPI_bodyLength(request));
   return response;
end-proc;

   // the headers and query params the request was parsed into
dcl-proc count;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s index int(10:0);

   response.status = HTTP_OK;
   response.body = 'headers:';
   for index = 1 to %elem(request.headers);
      if request.headers(index).name = *blanks;
         leave;
      endif;
      response.body += ' <' + %trim(request.headers(index).name) + '>';
   endfor;
   response.body += ' query:';
   for index = 1 to %elem(request.query_params);
      if request.query_params(index).name = *blanks;
         leave;
      endif;
      response.body += ' <' + %trim(request.query_params(index).name) + '>';
   endfor;
   return response;
end-proc;

/include 'testcfg.rpgle'
