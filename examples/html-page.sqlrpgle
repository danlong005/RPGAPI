**free
   // An HTML page from a view: the tables and views of a library, from the SQL
   // catalog. The route fetches the rows into its data structure, as any RPG
   // program would fill one, and renders views/tablelist.erpg with its address: the
   // view, a template of HTML with RPG in it, bases the same data structure
   // (views/tablelist_t.rpgleinc, included by both) on it and loops over the
   // rows; views/layout.erpg, the app's layout, writes the page around it.
   // RPGAPI
   // compiles each view the first time it is asked for, and again whenever
   // it or the copybook changes: edit a template and refresh the page.
   //
   // Build:
   //   CRTSQLRPGI OBJ(MYLIB/HTMLPAGE) SRCSTMF('<clone>/examples/html-page.sqlrpgle')
   //              CVTCCSID(*JOB) COMPILEOPT('INCDIR(''<clone>/qrpglesrc''
   //              ''<clone>/examples/views'') TGTCCSID(*JOB)')
   // with VIEWS below set to <clone>/examples/views. The views are compiled
   // into MYLIB, the program's library, so the job needs the ILE RPG
   // compiler and authority to create programs there.
   // Run:
   //   SBMJOB CMD(CALL PGM(MYLIB/HTMLPAGE)) JOB(HTMLPAGE)
   // Try, in a browser:
   //   http://your-ibm-i:8080/tables/QSYS2

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
   // layout_t, what the layout shows; table_t, and tablelist_t, the view's data
/include 'layout_t.rpgleinc'
/include 'tablelist_t.rpgleinc'

dcl-c VIEWS '/home/myuser/RPGAPI/examples/views';

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setViews(app : VIEWS);
RPGAPI_setLayout(app : 'layout.erpg');
RPGAPI_get(app : '/tables/{library}' : %paddr(tables));
RPGAPI_setCompression(app);
RPGAPI_start(app : 8080);

*inlr = *on;
return;


dcl-proc tables;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds model likeds(tablelist_t) inz;
   dcl-s library varchar(128);
   dcl-s name varchar(128);
   dcl-s kind varchar(20);
   dcl-s text varchar(50);
   dcl-s changed timestamp;

   exec sql set option commit = *none, datfmt = *iso, closqlcsr = *endmod;

   library = %upper(RPGAPI_getParam(request : 'library'));
   model.head.title = 'Tables in ' + library;
   exec sql declare table_list cursor for
            select table_name,
                   case table_type when 'V' then 'View'
                                   when 'L' then 'Logical file'
                                   else 'Table' end,
                   coalesce(table_text, ''),
                   coalesce(last_altered_timestamp, timestamp('0001-01-01'))
              from qsys2.systables
             where table_schema = :library
             order by table_name;
   exec sql open table_list;
   exec sql fetch next from table_list into :name, :kind, :text, :changed;
   dow sqlcode = 0 and model.count < %elem(model.tables);
      model.count += 1;
      model.tables(model.count).name = name;
      model.tables(model.count).kind = kind;
      model.tables(model.count).text = text;
      model.tables(model.count).changed = changed;
      exec sql fetch next from table_list into :name, :kind, :text, :changed;
   enddo;
   exec sql close table_list;

   return RPGAPI_render('tablelist.erpg' : %addr(model));
end-proc;
