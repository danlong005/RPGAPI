**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'
   // the data structures the views base on the pointer the route passes
/include 'views/listpage_t.rpgleinc'
/include 'views/people_t.rpgleinc'

   // views (RPGAPI_render): templates in the work directory's views, which
   // the runner copies from apps/views and the client adds to, compiled
   // into the app's library when they are first asked for
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/page' : %paddr(LISTPAGE));
RPGAPI_get(app : '/people' : %paddr(PEOPLE));
RPGAPI_get(app : '/view/{name}' : %paddr(VIEW));
RPGAPI_get(app : '/nodata/{name}' : %paddr(NODATA));
RPGAPI_get(app : '/custom' : %paddr(CUSTOM));
testSettings(app);
RPGAPI_setViews(app : testWorkDir + '/views');
   // the second run of the suite: every view in views/frame.erpg, unless it
   // picks another layout
if testCorsOrigins = 'layout';
   RPGAPI_setLayout(app : 'frame.erpg');
endif;
RPGAPI_start(app);

*inlr = *on;
return;

   // views/listpage.erpg: ?title=, and ?rows= rows
dcl-proc LISTPAGE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds model likeds(listpage_t) inz;
   dcl-s index int(10:0);

   model.title = RPGAPI_getQueryParam(request : 'title');
   model.count = %int(RPGAPI_getQueryParam(request : 'rows'));
   for index = 1 to model.count;
      model.items(index).id = index;
      model.items(index).label = 'Row ' + %char(index);
   endfor;
   return RPGAPI_render('listpage.erpg' : %addr(model));
end-proc;

   // views/people.erpg: numbers and dates, ?max= of 3
dcl-proc PEOPLE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds model likeds(people_t) inz;

   model.people(1).id = 1;
   model.people(1).name = 'Anna & Co';
   model.people(1).balance = 12.50;
   model.people(1).since = d'2024-01-31';
   model.people(2).id = 2;
   model.people(2).name = '<b>';
   model.people(2).balance = -3;
   model.people(2).since = d'2025-06-01';
   model.people(3).id = 3;
   model.people(3).name = 'Cy';
   model.count = %min(%int(RPGAPI_getQueryParam(request : 'max')) : 3);
   return RPGAPI_render('people.erpg' : %addr(model));
end-proc;

   // views/<name>.erpg, with a title as its data
dcl-proc VIEW;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s title varchar(100) inz('T');

   return RPGAPI_render(RPGAPI_getParam(request : 'name') + '.erpg' :
                        %addr(title));
end-proc;

   // views/<name>.erpg, with no data
dcl-proc NODATA;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;

   return RPGAPI_render(RPGAPI_getParam(request : 'name') + '.erpg');
end-proc;

   // a view with the route's own status and headers
dcl-proc CUSTOM;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s title varchar(100) inz('Custom');

   response.status = 201;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   RPGAPI_setHeader(response : 'X-View' : 'custom');
   return RPGAPI_render('heading.erpg' : %addr(title) : response);
end-proc;

/include 'testcfg.rpgle'
