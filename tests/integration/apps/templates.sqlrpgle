**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // ERPG templates: views/*.erpg, turned into procedures by the runner
   // before this is compiled. A page with a view in it, and a view over an
   // SQL cursor
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/page' : %paddr(PAGEROUTE));
RPGAPI_get(app : '/tables/{schema}' : %paddr(TABLESROUTE));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

   // views/listpage.erpg with ?title= and ?rows=
dcl-proc PAGEROUTE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   RPGAPI_setHeader(response : 'Content-Type' : 'text/html; charset=utf-8');
   RPGAPI_beginResponse(response);
   listpage(RPGAPI_getQueryParam(request : 'title') :
            %int(RPGAPI_getQueryParam(request : 'rows')));
   RPGAPI_endResponse();
   return response;
end-proc;

   // views/tables.erpg: the first 5 tables of a schema
dcl-proc TABLESROUTE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   RPGAPI_setHeader(response : 'Content-Type' : 'text/html; charset=utf-8');
   RPGAPI_beginResponse(response);
   tables(RPGAPI_getParam(request : 'schema'));
   RPGAPI_endResponse();
   return response;
end-proc;

/include 'testcfg.rpgle'
   // the views; compiled with RPGPPOPT(*LVL2), so that the SQL precompiler
   // sees the SQL in them
/include 'views/listpage.erpg.rpgle'
/include 'views/heading.erpg.rpgle'
/include 'views/tables.erpg.rpgle'
