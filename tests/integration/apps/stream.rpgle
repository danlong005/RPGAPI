**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // streamed responses, sendFile, ranges and caching, write timeout
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/stream' : %paddr(STREAM));
RPGAPI_get(app : '/json' : %paddr(JSON));
RPGAPI_get(app : '/length' : %paddr(LENGTH));
RPGAPI_get(app : '/file' : %paddr(FILE));
RPGAPI_get(app : '/disposition' : %paddr(DISPOSITION));
RPGAPI_get(app : '/nobegin' : %paddr(NOBEGIN));
RPGAPI_get(app : '/fail' : %paddr(FAIL));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

   // ?rows=N lines of text
dcl-proc STREAM;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s rows int(10:0);
   dcl-s index int(10:0);

   rows = %int(RPGAPI_getQueryParam(request : 'rows'));
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   RPGAPI_beginResponse(response);
   for index = 1 to rows;
      RPGAPI_write('line ' + %char(index) + x'25');
   endfor;
   RPGAPI_endResponse();
   return response;
end-proc;

   // a JSON array of ?rows=N objects, written one at a time
dcl-proc JSON;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s rows int(10:0);
   dcl-s index int(10:0);

   rows = %int(RPGAPI_getQueryParam(request : 'rows'));
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   RPGAPI_beginResponse(response);
   RPGAPI_write('[');
   for index = 1 to rows;
      if index > 1;
         RPGAPI_write(',');
      endif;
      RPGAPI_write('{"id":' + %char(index) + ',"name":"Jürgen",' +
                   '"tags":["a|b","c\\d"],"mail":"x@y"}');
   endfor;
   RPGAPI_write(']');
      // not ended here: RPGAPI_start ends it
   return response;
end-proc;

dcl-proc LENGTH;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   RPGAPI_beginResponse(response : 11);
   RPGAPI_write('hello ');
   RPGAPI_write('world');
   RPGAPI_endResponse();
   return response;
end-proc;

   // ?name= a file in FILES, or 404
dcl-proc FILE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   if not RPGAPI_sendFile(response :
                          testWorkDir + '/files/' + RPGAPI_getQueryParam(request : 'name'));
      response.status = HTTP_NOT_FOUND;
      response.body = 'no such file';
   endif;
   return response;
end-proc;

dcl-proc DISPOSITION;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   RPGAPI_setHeader(response : 'Content-Type' : 'text/x-custom');
   RPGAPI_setHeader(response : 'Cache-Control' : 'no-store');
   RPGAPI_setHeader(response : 'Content-Disposition' :
                    'attachment; filename="notes.txt"');
   RPGAPI_sendFile(response : testWorkDir + '/files/' + 'notes.txt');
   return response;
end-proc;

dcl-proc NOBEGIN;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   RPGAPI_write('never sent');
   return response;
end-proc;

   // begins a response, then fails
dcl-proc FAIL;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s zero int(10:0) inz(0);

   RPGAPI_beginResponse(response);
   RPGAPI_write('partial');
   response.status = 1 / zero;
   return response;
end-proc;

/include 'testcfg.rpgle'
