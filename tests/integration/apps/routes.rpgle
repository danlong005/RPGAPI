**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // route and middleware matching
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setMiddleware(app : '/admin' : %paddr(DENY));
RPGAPI_setMiddleware(app : '/secret/*' : %paddr(DENY));
RPGAPI_get(app : '/api/users' : %paddr(USERS));
RPGAPI_get(app : '/api/users/{id}' : %paddr(USER));
RPGAPI_get(app : '/api/users/{userId}/orders/{orderId}' : %paddr(ORDER));
RPGAPI_get(app : '/' : %paddr(ROOT));

   // groups: /v1 needs a key, /shops/{shop} has a param in its prefix
RPGAPI_setPrefix(app : '/v1/');
RPGAPI_setMiddleware(app : '*' : %paddr(NEEDKEY));
RPGAPI_get(app : '/items' : %paddr(GROUPED));
RPGAPI_get(app : '/items/{id}' : %paddr(GROUPED));
RPGAPI_get(app : '/' : %paddr(GROUPED));
RPGAPI_setPrefix(app : 'shops/{shop}');
RPGAPI_get(app : 'items' : %paddr(GROUPED));
RPGAPI_setPrefix(app : '');
RPGAPI_get(app : '/items' : %paddr(GROUPED));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc DENY;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;

   response.status = 401;
   response.body = 'denied';
   return *off;
end-proc;

dcl-proc USERS;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'users';
   return response;
end-proc;

dcl-proc USER;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'user ' + RPGAPI_getParam(request : 'id');
   return response;
end-proc;

dcl-proc ORDER;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'order ' + RPGAPI_getParam(request : 'userId') + ' ' +
                   RPGAPI_getParam(request : 'orderId');
   return response;
end-proc;

dcl-proc ROOT;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'root';
   return response;
end-proc;

dcl-proc NEEDKEY;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;

   if RPGAPI_getHeader(request : 'X-Key') = 'k';
      return *on;
   endif;
   response.status = 401;
   response.body = 'no key';
   return *off;
end-proc;

   // which route answered, and its params
dcl-proc GROUPED;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'grouped ' + %trim(request.route) +
                   ' id=' + RPGAPI_getParam(request : 'id') +
                   ' shop=' + RPGAPI_getParam(request : 'shop');
   return response;
end-proc;

/include 'testcfg.rpgle'
