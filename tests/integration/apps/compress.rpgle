**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // gzip compression (RPGAPI_setCompression, the default 1024 byte
   // threshold): bodies in memory, streamed, files, and responses that are
   // not to be gzipped
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/json' : %paddr(JSON));
RPGAPI_get(app : '/text' : %paddr(TEXT));
RPGAPI_get(app : '/png' : %paddr(PNG));
RPGAPI_get(app : '/encoded' : %paddr(ENCODED));
RPGAPI_get(app : '/notransform' : %paddr(NOTRANSFORM));
RPGAPI_get(app : '/stream' : %paddr(STREAM));
RPGAPI_get(app : '/length' : %paddr(LENGTH));
RPGAPI_get(app : '/file/{name}' : %paddr(FILE));
testSettings(app);
RPGAPI_setCompression(app);
RPGAPI_start(app);

*inlr = *on;
return;

   // a JSON body of about ?bytes=N bytes
dcl-proc JSON;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s bytes int(10:0);
   dcl-s index int(10:0) inz(0);

   bytes = %int(RPGAPI_getQueryParam(request : 'bytes'));
   response.body = '[';
   dow %len(response.body) < bytes - 40;
      index += 1;
      if index > 1;
         response.body += ',';
      endif;
      response.body += '{"id":' + %char(index) + ',"name":"item ' +
                       %char(index) + '"}';
   enddo;
   response.body += ']';
   response.status = 200;
   RPGAPI_setHeader(response : 'Content-Type' :
                    'application/json; charset=utf-8');
   return response;
end-proc;

   // ?word=w repeated ?times=n times, as text
dcl-proc TEXT;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s word varchar(1024);
   dcl-s index int(10:0);

   word = RPGAPI_getQueryParam(request : 'word');
   for index = 1 to %int(RPGAPI_getQueryParam(request : 'times'));
      response.body += word + ' ';
   endfor;
   response.status = 200;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   return response;
end-proc;

   // 5000 bytes of a type that is not text
dcl-proc PNG;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s filler char(5000) inz(*all'x');

   response.body = filler;
   response.status = 200;
   RPGAPI_setHeader(response : 'Content-Type' : 'image/png');
   return response;
end-proc;

   // text the procedure encoded itself
dcl-proc ENCODED;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response = TEXT(request);
   RPGAPI_setHeader(response : 'Content-Encoding' : 'identity');
   return response;
end-proc;

   // text a proxy must not change
dcl-proc NOTRANSFORM;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response = TEXT(request);
   RPGAPI_setHeader(response : 'Cache-Control' : 'no-transform');
   return response;
end-proc;

   // ?rows=N lines of CSV, streamed
dcl-proc STREAM;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s index int(10:0);

   RPGAPI_setHeader(response : 'Content-Type' : 'text/csv');
   RPGAPI_beginResponse(response);
   for index = 1 to %int(RPGAPI_getQueryParam(request : 'rows'));
      RPGAPI_write(%char(index) + ',row ' + %char(index) + ',' +
                   %char(index * 7) + x'25');
   endfor;
   RPGAPI_endResponse();
   return response;
end-proc;

   // 3000 bytes streamed with their length given
dcl-proc LENGTH;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s index int(10:0);
   dcl-s dashes char(99) inz(*all'-');

      // 30 lines of 100 bytes
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain');
   RPGAPI_beginResponse(response : 3000);
   for index = 1 to 30;
      RPGAPI_write(%subst('line ' + %char(index) + ' ' + dashes : 1 : 99) +
                   x'25');
   endfor;
   RPGAPI_endResponse();
   return response;
end-proc;

   // a file from the work directory's files
dcl-proc FILE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   if not RPGAPI_sendFile(response : testWorkDir + '/files/' +
                          RPGAPI_getParam(request : 'name'));
      response.status = 404;
   endif;
   return response;
end-proc;

/include 'testcfg.rpgle'
