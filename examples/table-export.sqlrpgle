**free
   // Streaming a large result: every table and view in a library, from the
   // SQL catalog, as a JSON array or as CSV, row by row. Nothing is collected in
   // memory first, so it works the same for 10 rows or a million. With
   // compression on, clients that accept gzip get it gzipped as it is written:
   // a fraction of the bytes over the network.
   //
   // Build:
   //   CRTSQLRPGI OBJ(MYLIB/EXPORT) SRCSTMF('<clone>/examples/table-export.sqlrpgle')
   //              CVTCCSID(*JOB) COMPILEOPT('INCDIR(''<clone>/qrpglesrc'') TGTCCSID(*JOB)')
   // Run:
   //   SBMJOB CMD(CALL PGM(MYLIB/EXPORT)) JOB(EXPORT)
   // Try:
   //   curl http://your-ibm-i:8080/tables/QSYS2
   //   curl -O -J http://your-ibm-i:8080/tables/QSYS2?format=csv    (saves QSYS2.csv)
   //   curl --compressed http://your-ibm-i:8080/tables/QSYS2         (gzipped on the way)
   //   curl -s -o /dev/null -w '%{size_download}\n' http://your-ibm-i:8080/tables/QSYS2
   //   curl -s -o /dev/null -w '%{size_download}\n' --compressed http://your-ibm-i:8080/tables/QSYS2
   //                                            (the bytes sent, without and with gzip)

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/tables/{schema}' : %paddr(tables));
   // gzip for clients that accept it: the stream is compressed as it is
   // written, and sent in chunks
RPGAPI_setCompression(app);
RPGAPI_start(app : 8080);

*inlr = *on;
return;


dcl-proc tables;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds row qualified;
      name varchar(128);
      type char(1);
      text varchar(50);
      columns int(10:0);
   end-ds;
   dcl-s row_text_ind int(5:0);
   dcl-s schema varchar(128);
   dcl-s csv ind;
   dcl-s first ind inz(*on);
   dcl-s line varchar(1000);

   schema = %upper(RPGAPI_getParam(request : 'schema'));
   csv = RPGAPI_getQueryParam(request : 'format') = 'csv';

   exec sql declare tables cursor for
      select table_name, table_type, table_text, column_count
        from qsys2.systables
       where table_schema = :schema
       order by table_name;
   exec sql open tables;

      // the status and headers go out now; the rows follow as they are read
   if csv;
      RPGAPI_setHeader(response : 'Content-Type' : 'text/csv; charset=utf-8');
      RPGAPI_setHeader(response : 'Content-Disposition' :
                       'attachment; filename="' + schema + '.csv"');
      RPGAPI_beginResponse(response);
      RPGAPI_write('name,type,text,columns' + x'0d25');
   else;
      RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
      RPGAPI_beginResponse(response);
      RPGAPI_write('[');
   endif;

   dow *on;
      exec sql fetch tables into :row.name, :row.type,
                                 :row.text :row_text_ind, :row.columns;
         // warnings (SQLCODE above 0, but not 100) still give a row
      if sqlcode < 0 or sqlcode = 100;
         leave;
      endif;
      if row_text_ind < 0;
         row.text = '';
      endif;

      if csv;
         line = row.name + ',' + row.type + ',"' +
                %scanrpl('"' : '""' : %trim(row.text)) + '",' + %char(row.columns) +
                x'0d25';
      else;
            // JSON_OBJECT escapes the text properly
         exec sql values json_object('name' value :row.name,
                                     'type' value :row.type,
                                     'text' value trim(:row.text),
                                     'columns' value :row.columns)
                  into :line;
         if not first;
            line = ',' + line;
         endif;
      endif;
      RPGAPI_write(line);
      first = *off;
   enddo;
   exec sql close tables;

   if not csv;
      RPGAPI_write(']');
   endif;
   RPGAPI_endResponse();
   return response;
end-proc;
