**free
   // An HTML page from views: the tables and views of a library, from the SQL
   // catalog. The route puts the query's rows in a list and renders
   // views/tablelist.erpg, a template of HTML with RPG in it that loops over
   // them and includes views/pagetop.erpg for the top of the page. RPGAPI
   // compiles each view the first time it is asked for, and again whenever
   // the template changes: edit a template and refresh the page.
   //
   // Build:
   //   CRTBNDRPG PGM(MYLIB/HTMLPAGE) SRCSTMF('<clone>/examples/html-page.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // with VIEWS below set to <clone>/examples/views. The views are compiled
   // into MYLIB, the program's library, so the job needs the ILE RPG
   // compiler and authority to create programs there.
   // Run:
   //   SBMJOB CMD(CALL PGM(MYLIB/HTMLPAGE)) JOB(HTMLPAGE)
   // Try, in a browser:
   //   http://your-ibm-i:8080/tables/QSYS2

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-c VIEWS '/home/myuser/RPGAPI/examples/views';

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setViews(app : VIEWS);
RPGAPI_get(app : '/tables/{library}' : %paddr(tables));
RPGAPI_setCompression(app);
RPGAPI_start(app : 8080);

*inlr = *on;
return;


dcl-proc tables;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds vars likeds(RPGAPI_Vars) inz;
   dcl-s library varchar(128);

   library = %upper(RPGAPI_getParam(request : 'library'));
   RPGAPI_setVar(vars : 'title' : 'Tables in ' + library);
      // each column is a field of the list, by its name
   RPGAPI_setList(vars : 'tables' :
      'select table_name as name, ' +
      '       case table_type when ''V'' then ''View'' ' +
      '                       when ''L'' then ''Logical file'' ' +
      '                       else ''Table'' end as kind, ' +
      '       coalesce(table_text, '''') as text, ' +
      '       last_altered_timestamp as changed ' +
      '  from qsys2.systables where table_schema = ? order by table_name' :
      library);
   return RPGAPI_render('tablelist.erpg' : vars);
end-proc;
