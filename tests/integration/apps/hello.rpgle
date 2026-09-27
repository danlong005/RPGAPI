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
RPGAPI_get(app : '/header' : %paddr(header));
RPGAPI_get(app : '/cookie/get' : %paddr(cookieGet));
RPGAPI_get(app : '/cookie/set' : %paddr(cookieSet));
RPGAPI_get(app : '/cookie/clear' : %paddr(cookieClear));
RPGAPI_get(app : '/cookie/bad' : %paddr(cookieBad));
RPGAPI_get(app : '/ip' : %paddr(ip));
RPGAPI_post(app : '/form' : %paddr(form));
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

   // the header named by ?name=: its length and its last 10 characters
dcl-proc header;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s value varchar(32000);

   value = RPGAPI_getHeader(request : RPGAPI_getQueryParam(request : 'name'));
   response.status = HTTP_OK;
   response.body = 'len=' + %char(%len(value));
   if %len(value) >= 10;
      response.body += ' tail=' + %subst(value : %len(value) - 9);
   endif;
   return response;
end-proc;

   // the cookie named by ?name=, between < and >
dcl-proc cookieGet;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = '<' + RPGAPI_getCookie(request :
                            RPGAPI_getQueryParam(request : 'name')) + '>';
   return response;
end-proc;

   // a session cookie with every option, and a plain one
dcl-proc cookieSet;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds options likeds(RPGAPI_CookieOptions) inz(*likeds);

   options.path = '/app';
   options.max_age = 3600;
   options.http_only = *on;
   options.secure = *on;
   options.same_site = 'Lax';
   RPGAPI_setCookie(response : 'session' : 'hello world' : options);
   RPGAPI_setCookie(response : 'plain' : 'Jürgen; x=1');
   response.status = HTTP_OK;
   response.body = 'set';
   return response;
end-proc;

dcl-proc cookieClear;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds options likeds(RPGAPI_CookieOptions) inz(*likeds);

   options.path = '/app';
   RPGAPI_clearCookie(response : 'session' : options);
   response.status = HTTP_OK;
   return response;
end-proc;

   // a name a cookie cannot have: ends the procedure with an error
dcl-proc cookieBad;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   RPGAPI_setCookie(response : 'a b' : 'x');
   response.status = HTTP_OK;
   return response;
end-proc;

   // the client's address and the connection's: remote|connection
dcl-proc ip;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   response.body = request.remote_ip + '|' + request.connection_ip;
   return response;
end-proc;

   // the form field ?field= (its ?n= th, 1 when left out), between < and >
dcl-proc form;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s field varchar(1024);
   dcl-s occurrence varchar(1024);

   field = RPGAPI_getQueryParam(request : 'field');
   occurrence = RPGAPI_getQueryParam(request : 'n');
   response.status = HTTP_OK;
   if occurrence = '';
      response.body = '<' + RPGAPI_getFormParam(request : field) + '>';
   else;
      response.body = '<' + RPGAPI_getFormParam(request : field :
                                                %int(occurrence)) + '>';
   endif;
   return response;
end-proc;

/include 'testcfg.rpgle'
