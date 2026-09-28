**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // views (RPGAPI_render): templates in the work directory's views, which
   // the runner copies from apps/views and the client adds to, compiled
   // into the app's library when they are first asked for
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/page' : %paddr(LISTPAGE));
RPGAPI_get(app : '/people' : %paddr(PEOPLE));
RPGAPI_get(app : '/view/{name}' : %paddr(VIEW));
RPGAPI_get(app : '/custom' : %paddr(CUSTOM));
RPGAPI_get(app : '/badsql' : %paddr(BADSQL));
testSettings(app);
RPGAPI_setViews(app : testWorkDir + '/views');
RPGAPI_start(app);

*inlr = *on;
return;

   // views/listpage.erpg: ?title=, and ?rows= rows built one by one
dcl-proc LISTPAGE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds vars likeds(RPGAPI_Vars) inz;
   dcl-s index int(10:0);

   RPGAPI_setVar(vars : 'title' : RPGAPI_getQueryParam(request : 'title'));
   for index = 1 to %int(RPGAPI_getQueryParam(request : 'rows'));
      RPGAPI_addRow(vars : 'items');
      RPGAPI_setField(vars : 'items' : 'id' : %char(index));
      RPGAPI_setField(vars : 'items' : 'label' : 'Row ' + %char(index));
   endfor;
   return RPGAPI_render('listpage.erpg' : vars);
end-proc;

   // views/people.erpg: a list from SQL with numbers, dates and a null,
   // ?max= rows of 4
dcl-proc PEOPLE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds vars likeds(RPGAPI_Vars) inz;

   RPGAPI_setList(vars : 'people' :
      'select * from (values (1, ''Anna & Co'', 12.50, date(''2024-01-31'')), ' +
      '(2, ''<b>'', -3, date(''2025-06-01'')), (3, ''Cy'', 0, null), ' +
      '(4, ''Dee'', 7, date(''2026-09-28''))) as t(id, name, balance, since) ' +
      'where id <= ? order by id' : RPGAPI_getQueryParam(request : 'max'));
   return RPGAPI_render('people.erpg' : vars);
end-proc;

   // views/<name>.erpg, with a title
dcl-proc VIEW;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds vars likeds(RPGAPI_Vars) inz;

   RPGAPI_setVar(vars : 'title' : 'T');
   return RPGAPI_render(RPGAPI_getParam(request : 'name') + '.erpg' : vars);
end-proc;

   // a view with the route's own status and headers
dcl-proc CUSTOM;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds vars likeds(RPGAPI_Vars) inz;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 201;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   RPGAPI_setHeader(response : 'X-View' : 'custom');
   RPGAPI_setVar(vars : 'title' : 'Custom');
   return RPGAPI_render('heading.erpg' : vars : response);
end-proc;

   // an SQL statement that fails
dcl-proc BADSQL;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds vars likeds(RPGAPI_Vars) inz;

   RPGAPI_setList(vars : 'x' : 'select nothing from no_such_table_here');
   return RPGAPI_render('heading.erpg' : vars);
end-proc;

/include 'testcfg.rpgle'
