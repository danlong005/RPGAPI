**free
   // The smallest RPGAPI app: two routes, one with a param.
   //
   // Build (with the library holding the RPGAPI binding directory in your
   // library list):
   //   CRTBNDRPG PGM(MYLIB/HELLO) SRCSTMF('<clone>/examples/hello.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // Run, try, stop:
   //   SBMJOB CMD(CALL PGM(MYLIB/HELLO)) JOB(HELLO)
   //   curl http://your-ibm-i:8080/hello          -> hello world
   //   curl http://your-ibm-i:8080/hello/Anna     -> hello Anna
   //   ENDJOB JOB(HELLO)

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/hello' : %paddr(hello));
RPGAPI_get(app : '/hello/{name}' : %paddr(hello));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


dcl-proc hello;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
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
