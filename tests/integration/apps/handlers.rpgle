**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI/RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // custom 404 and error handlers: both answer with JSON

dcl-ds app likeds(RPGAPI_App);

clear app;
testSettings(app);
RPGAPI_setNotFound(app : %paddr(notFound));
RPGAPI_setErrorHandler(app : %paddr(failed));
RPGAPI_setMiddleware(app : '/guarded' : %paddr(failingMiddleware));
RPGAPI_get(app : '/ok' : %paddr(ok));
RPGAPI_get(app : '/items' : %paddr(ok));
RPGAPI_get(app : '/guarded' : %paddr(ok));
RPGAPI_get(app : '/fail' : %paddr(fail));
RPGAPI_get(app : '/handler-fails' : %paddr(fail));
RPGAPI_get(app : '/stream-fail' : %paddr(streamFail));
RPGAPI_post(app : '/read' : %paddr(readAll));
RPGAPI_start(app);

*inlr = *on;
return;


dcl-proc ok;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = 'ok';
   return response;
end-proc;

   // divides by zero: an escape message ends it
dcl-proc fail;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s zero int(10:0) inz(0);

   response.status = HTTP_OK;
   response.body = %char(1 / zero);
   return response;
end-proc;

dcl-proc failingMiddleware;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;
   dcl-s zero int(10:0) inz(0);

   return 1 / zero = 1;
end-proc;

   // fails once its response has begun
dcl-proc streamFail;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s zero int(10:0) inz(0);

   response.status = HTTP_OK;
   RPGAPI_beginResponse(response);
   RPGAPI_write('begun');
   RPGAPI_write(%char(1 / zero));
   return response;
end-proc;

   // reads the whole body, so a body over the upload limit fails in here
dcl-proc readAll;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s piece varchar(32000);
   dcl-s total int(10:0) inz(0);

   dou piece = '';
      piece = RPGAPI_readBody(request);
      total += %len(piece);
   enddo;
   response.status = HTTP_OK;
   response.body = %char(total);
   return response;
end-proc;

   // /zero leaves the status at 0: sent as 404
dcl-proc notFound;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   if %trim(request.route) = '/zero';
      response.body = 'zero';
      return response;
   endif;
   response.status = HTTP_NOT_FOUND;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = '{"error":"no route for ' + %trim(request.method) + ' ' +
                   %trim(request.route) + '"}';
   return response;
end-proc;

   // /handler-fails makes the handler fail too
dcl-proc failed;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
      error likeds(RPGAPI_Error) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s zero int(10:0) inz(0);

   if %trim(request.route) = '/handler-fails';
      response.body = %char(1 / zero);
   endif;
   response.status = error.status;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   RPGAPI_setHeader(response : 'X-Handled' : 'yes');
   response.body = '{"status":' + %char(error.status) +
                   ',"id":"' + %trim(error.message_id) +
                   '","message":"' + %scanrpl('"' : '\"' : error.message_text) +
                   '","method":"' + %trim(request.method) + '"}';
   return response;
end-proc;

/include 'testcfg.rpgle'
