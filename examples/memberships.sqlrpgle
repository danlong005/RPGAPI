**free

   // Middleware on all routes and on one path, a route param, and SQL that
   // builds the JSON (JSON_OBJECT escapes the names, so quotes and
   // backslashes in them are safe). MBR_show reads a table TESTDTA
   // (ID, FNAME, LNAME) in the library list that you provide, such as:
   //   CREATE TABLE MYLIB.TESTDTA (ID DECIMAL(11, 0) NOT NULL PRIMARY KEY,
   //                               FNAME CHAR(25), LNAME CHAR(25))
   // Build it with the RPGAPI binding directory's library in the library list:
   //   CRTSQLRPGI OBJ(MYLIB/APP) SRCSTMF('<clone>/examples/memberships.sqlrpgle')
   //              CVTCCSID(*JOB)
   //              COMPILEOPT('INCDIR(''<clone>/qrpglesrc'') TGTCCSID(*JOB)')
   // Try: curl http://your-ibm-i:3012/api/v1/memberships/1
   //   -> {"id":1,"first_name":"Anna","last_name":"Berg"}

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI')
              dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds request likeds(RPGAPI_Request);
dcl-ds response likeds(RPGAPI_Response);
dcl-ds app likeds(RPGAPI_App);

clear app;
app.port = 3012;

       // adding a middleware to all routes
RPGAPI_setMiddleware(app: RPGAPI_GLOBAL_MIDDLEWARE: %paddr(CHECK_AUTH));

       // adding a middle ware to a specific route
RPGAPI_setMiddleware(app : '/api/v1/memberships' : %paddr(CHECK_AUTH));
RPGAPI_get(app : '/api/v1/memberships/{id}' : %paddr(MBR_show));

RPGAPI_start(app);

*inlr = *on;
return;


dcl-proc CHECK_AUTH;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;

   return *on;
end-proc;

dcl-proc MBR_show;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s id_number zoned(11:0) inz;
   dcl-s json varchar(1000);

   id_number = %dec(RPGAPI_getParam(request: 'id') : 11 : 0);

      // the row as a JSON object, escaped by SQL
   exec sql select json_object('id' value id,
                               'first_name' value trim(fname),
                               'last_name' value trim(lname))
                  into :json
                  from testdta
                  where id = :id_number;

   clear response;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   if sqlcode = 100;
      response.status = HTTP_NOT_FOUND;
      response.body = '{"error":"no such membership"}';
   else;
      response.status = HTTP_OK;
      response.body = json;
   endif;

   return response;
end-proc;