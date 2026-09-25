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

/include 'testcfg.rpgle'
