**free

   // Middleware on all routes and on one path, a route param, and SQL.
   // MBR_show reads a table TESTDTA (ID, FNAME, LNAME) that you provide.
   // Build it with the RPGAPI binding directory's library in the library list:
   //   CRTSQLRPGI OBJ(MYLIB/APP) SRCSTMF('<clone>/examples/memberships.sqlrpgle')
   //              CVTCCSID(*JOB)
   //              COMPILEOPT('INCDIR(''<clone>/qrpglesrc'') TGTCCSID(*JOB)')
   // Try: curl http://your-ibm-i:3012/api/v1/memberships/1

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI')
              dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds request likeds(RPGAPI_Request);
dcl-ds response likeds(RPGAPI_Response);
dcl-ds app likeds(RPGAPI_App);

dcl-pr JSON_escape varchar(1000);
   value varchar(1000) const;
end-pr;

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
   dcl-ds row qualified;
      id zoned(11:0);
      first_name char(25);
      last_name char(25);
   end-ds;

   clear row;
   id_number = %dec(RPGAPI_getParam(request: 'id') : 11 : 0);

   exec sql select id, fname, lname
                  into :row
                  from testdta
                  where id = :id_number;

   clear response;
   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
         
   if row.id <> *zeros;
      response.body = '{"id":' + %trim(%char(row.id)) +
                      ',"first_name":"' +
                            JSON_escape(%trim(row.first_name)) + '"' +
                      ',"last_name":"' +
                            JSON_escape(%trim(row.last_name)) + '"' +
                      '}';
   else;
      response.status = HTTP_NOT_FOUND;
   endif;

   return response;
end-proc;


       // Escapes the characters JSON requires to be escaped, so that a value
       // containing a quote or a backslash cannot break the string it is
       // concatenated into.
dcl-proc JSON_escape;
   dcl-pi *n varchar(1000);
      value varchar(1000) const;
   end-pi;

         // backslashes first: escaping them afterwards would double the
         // backslashes introduced when escaping the quotes
   return %scanrpl('"' : '\"' :
                %scanrpl('\' : '\\' : value));
end-proc;