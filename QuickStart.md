```
       ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI')
              dftactgrp(*no);

      /include '/home/[youruser]/RPGAPI/qrpglesrc/rpgapi_h.rpgle'

       dcl-ds request likeds(RPGAPI_Request);
       dcl-ds response likeds(RPGAPI_Response);
       dcl-ds app likeds(RPGAPI_App);

       clear app;

       RPGAPI_get(app : '/hello' : %paddr(test_proc));

       RPGAPI_start(app: 3017);

       *inlr = *on;
       return;


       dcl-proc test_proc;
         dcl-pi *n likeds(RPGAPI_Response);
           request likeds(RPGAPI_Request) const;
         end-pi;

         response.body = 'hello';
         response.status = HTTP_OK;
         RPGAPI_setHeader(response : 'Content-Type' : 'application/text');

         return response;
       end-proc;
```