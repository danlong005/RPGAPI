**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // requests and responses: pieces, bodies, @, UTF-8 and CCSIDs
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/hello' : %paddr(HELLO));
RPGAPI_post(app : '/echo' : %paddr(ECHO));
RPGAPI_get(app : '/at' : %paddr(AT));
RPGAPI_post(app : '/show' : %paddr(SHOW));
RPGAPI_get(app : '/json' : %paddr(JSON));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc HELLO;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'hello';
   return response;
end-proc;

   // reports the body length and its first and last 5 characters
dcl-proc ECHO;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s length int(10:0);

   length = %len(request.body);
   response.status = 200;
   response.body = 'len=' + %char(length);
   if length >= 5;
      response.body += ' head=' + %subst(request.body : 1 : 5) +
                       ' tail=' + %subst(request.body : length - 4);
   endif;
   return response;
end-proc;

dcl-proc AT;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'user@example.com @@';
   return response;
end-proc;

   // the body with CR and LF written out as <CR> and <LF>, between < and >.
   // Only characters that are the same in CCSID 37 and 273
dcl-proc SHOW;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'len=' + %char(%len(request.body)) + ' <' +
                   %scanrpl(x'25' : '<LF>' :
                      %scanrpl(x'0d' : '<CR>' : request.body)) + '>';
   return response;
end-proc;

   // a JSON literal with every character that differs between CCSID 37 and 273
dcl-proc JSON;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = '{"list":[1,2],"mail":"a@b","path":"C:\\dir",' +
                   '"or":"a|b","name":"Jürgen"}';
   return response;
end-proc;

/include 'testcfg.rpgle'
