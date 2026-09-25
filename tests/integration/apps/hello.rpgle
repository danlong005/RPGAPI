**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // the Quick Start app, and URL decoding, hostname, redirects and statuses
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/hello' : %paddr(hello));
RPGAPI_get(app : '/hello/{name}' : %paddr(hello));

   // serves requests until the job is ended
RPGAPI_get(app : '/conflict' : %paddr(extra));
RPGAPI_get(app : '/moved' : %paddr(extra));
RPGAPI_get(app : '/q' : %paddr(query));
RPGAPI_get(app : '/host' : %paddr(host));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;


dcl-proc hello;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
      // a new, empty response for every request: inz sets the status to 0
      // and leaves no headers from a previous request behind
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s name varchar(1024);

   name = RPGAPI_getParam(request : 'name');
   if name = '';
      name = 'world';
   endif;

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   response.body = 'hello ' + name;
   return response;
end-proc;

   // for checking the API documentation: a status without a constant, a
   // redirect, and framing headers a procedure sets
dcl-proc extra;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   if request.route = '/conflict';
      response.status = 409;
      RPGAPI_setHeader(response : 'Content-Length' : '999');
      RPGAPI_setHeader(response : 'Transfer-Encoding' : 'chunked');
      response.body = 'taken';
   else;
      response.status = HTTP_FOUND;
      RPGAPI_setHeader(response : 'Location' : '/hello');
   endif;
   return response;
end-proc;

   // query values, each between < and >, and the raw query string
dcl-proc query;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = 'x=<' + RPGAPI_getQueryParam(request : 'x') + '> ' +
                   'y=<' + RPGAPI_getQueryParam(request : 'y') + '> ' +
                   'z=<' + RPGAPI_getQueryParam(request : 'z') + '> ' +
                   'w=<' + RPGAPI_getQueryParam(request : 'w') + '> ' +
                   'u=<' + RPGAPI_getQueryParam(request : 'u') + '> ' +
                   'na me=<' + RPGAPI_getQueryParam(request : 'na me') + '> ' +
                   'raw=<' + %trim(request.query_string) + '>';
   return response;
end-proc;

dcl-proc host;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = 'hostname=<' + %trim(request.hostname) + '> Host=<' +
                   RPGAPI_getHeader(request : 'Host') + '>';
   return response;
end-proc;

/include 'testcfg.rpgle'
