**free
ctl-opt nomain option(*nodebugio:*srcstmt);

   // Views: EJS-style templates with RPG inside the tags, compiled and run
   // while the app runs. RPGAPI_render('views/customers.erpg' : vars) turns
   // the template into an RPG program the first time it is asked for (and
   // again whenever it changes), compiles it into the app's views library,
   // and calls it; the program writes the page, which is streamed to the
   // client. The route passes values and lists by name in an RPGAPI_Vars:
   //   RPGAPI_setVar, RPGAPI_setList (from SQL), RPGAPI_addRow, RPGAPI_setField
   // and the template reads them with RPGAPI_getVar and RPGAPI_getList.
   //
   // In a template:
   //   <% code %>     RPG statements, such as for-each, if, exec sql, calls
   //   <%= expr %>    a value, HTML-escaped (RPGAPI_writeHtml)
   //   <%- expr %>    a value as it is (RPGAPI_write)
   //   <%# text %>    a comment, left out
   //   <%! decls %>   declarations (dcl-s, dcl-ds), put first in the program
   //   <%%            a literal <%
   //   -%>            ends a tag and drops the line break after it

/include 'rpgapi_h.rpgle'
/include 'rpgapi_int_h.rpgle'
/include 'socket_h.rpgle'

dcl-ds QtqCode_T qualified template inz;
   ccsid int(10:0);
   conversion_alternative int(10:0);
   substitution_alternative int(10:0);
   shift_state_alternative int(10:0);
   input_length_option int(10:0);
   error_option int(10:0);
   reserved char(8) inz(*allx'00');
end-ds;

dcl-ds iconv_t qualified template;
   return_value int(10:0);
   cd int(10:0) dim(12);
end-ds;

dcl-pr iconv_open likeds(iconv_t) extproc('QtqIconvOpen');
   to_code likeds(QtqCode_T) const;
   from_code likeds(QtqCode_T) const;
end-pr;

dcl-pr iconv int(10:0) extproc('iconv');
   converter likeds(iconv_t) value;
   input pointer value;
   input_left pointer value;
   output pointer value;
   output_left pointer value;
end-pr;

dcl-pr iconv_close int(10:0) extproc('iconv_close');
   converter likeds(iconv_t) value;
end-pr;

dcl-pr qcmdexc extpgm('QCMDEXC');
   command char(3000) const options(*varsize);
   length packed(15:5) const;
end-pr;

   // zlib's, in QSYS/QZIPZLIB: names a compiled view after its template
dcl-pr crc32 uns(10:0) extproc('crc32');
   crc uns(10:0) value;
   buffer pointer value;
   length uns(10:0) value;
end-pr;

   // copies bytes between storage. A based field as long as the largest
   // value reaches past a small allocation, and RPG checks the whole field:
   // near the end of a heap segment that is MCH0601
dcl-pr memcpy pointer extproc('memcpy');
   target pointer value;
   source pointer value;
   length uns(10:0) value;
end-pr;

dcl-pr getcwd pointer extproc('getcwd');
   buffer pointer value;
   size int(10:0) value;
end-pr;

dcl-pr send_program_message extpgm('QMHSNDPM');
   message_id char(7) const;
   message_file char(20) const;
   message_data char(512) const;
   message_data_length int(10:0) const;
   message_type char(10) const;
   call_stack_entry char(10) const;
   call_stack_counter int(10:0) const;
   message_key char(4);
   error_code char(8);
end-pr;

   // the compiled view: extpgm with a name, resolved when it is called
dcl-s view_program char(21);
dcl-pr callView extpgm(view_program);
   vars likeds(RPGAPI_Vars) const;
end-pr;

dcl-c UTF8 1208;
dcl-c JOB_CCSID 0;
   // the largest template read, in bytes
dcl-c MAX_TEMPLATE 4000000;
   // the longest line of generated code, where the code allows
dcl-c MAX_LINE 100;
dcl-c LF x'25';
dcl-c CR x'0D';
   // what compiled views are named with: RV and 8 hex digits
dcl-c HEX '0123456789ABCDEF';
   // work files of a compile
dcl-c WORK_DIRECTORY '/tmp/';

   // ----- values and lists passed to views -----------------------------

   // one value (list ''), one field of a row of a list (row > 0), or a
   // list's row count (row 0, name '', count in length). Names in upper case
dcl-ds var_t qualified template;
   handle int(10:0);
   list varchar(64);
   row int(10:0);
   name varchar(64);
   value pointer;
   length int(10:0);
end-ds;
dcl-s vars_ptr pointer inz(*null);
dcl-ds entries likeds(var_t) dim(80000) based(vars_ptr);
dcl-s entry_count int(10:0) inz(0);
dcl-s entry_room int(10:0) inz(0);
dcl-s last_handle int(10:0) inz(0);

   // ----- compiled views, as this job last found them -------------------

dcl-ds cached_t qualified template;
   path varchar(1024);
   modified int(10:0);
   size int(10:0);
   program char(21);
end-ds;
dcl-ds cache likeds(cached_t) dim(200);
dcl-s cache_count int(10:0) inz(0);
dcl-s service_library char(10) inz(*blanks);

   // ----- the template being turned into RPG ----------------------------

dcl-ds buffer_t qualified template;
   data pointer inz(*null);
   length int(10:0) inz(0);
   size int(10:0) inz(0);
end-ds;
dcl-ds declarations likeds(buffer_t) inz(*likeds);
dcl-ds statements likeds(buffer_t) inz(*likeds);
   // the XML of the list a view last asked for (RPGAPI_listXml)
dcl-ds list_xml likeds(buffer_t) inz(*likeds);
dcl-s template_name varchar(256);
dcl-s source char(16000000) based(source_ptr);
dcl-s source_length int(10:0);
   // text waiting to be written, at most 1000 characters (200 literals
   // even if all are x'..'), and the template line it started on
dcl-s pending varchar(1000);
dcl-s pending_line int(10:0);
   // why the template cannot be used, for the error page
dcl-s view_error varchar(4000);
   // for QMHSNDPM: bytes provided 0, a failure to send is an exception
dcl-s message_key char(4);
dcl-s message_error char(8) inz(*allx'00');

   // the escape message last monitored, for the reason a command failed
dcl-ds program_status psds qualified;
   message_id char(7) pos(40);
   message_data char(80) pos(91);
end-ds;

   // the app's settings, from RPGAPI_setViews
dcl-s RPGAPI_views_directory varchar(1024) import;
dcl-s RPGAPI_views_library char(10) import;


   // ======================================================================
   // values and lists
   // ======================================================================

dcl-proc RPGAPI_setVar export;
   dcl-pi *n;
      vars likeds(RPGAPI_Vars);
      name varchar(64) const;
      value varchar(32000) const;
   end-pi;

   setEntry(handleOf(vars) : '' : 0 : name : value);
end-proc;


dcl-proc RPGAPI_addRow export;
   dcl-pi *n int(10:0);
      vars likeds(RPGAPI_Vars);
      list varchar(64) const;
   end-pi;
   dcl-s index int(10:0);

   index = countEntry(handleOf(vars) : list : *on);
   entries(index).length += 1;
   return entries(index).length;
end-proc;


dcl-proc RPGAPI_setField export;
   dcl-pi *n;
      vars likeds(RPGAPI_Vars);
      list varchar(64) const;
      name varchar(64) const;
      value varchar(32000) const;
   end-pi;
   dcl-s row int(10:0);

   row = RPGAPI_listCount(vars : list);
   if row = 0;
      row = RPGAPI_addRow(vars : list);
   endif;
   setEntry(handleOf(vars) : list : row : name : value);
end-proc;


   // the rows of an SQL query as a list: each column a field by its name,
   // every value as text; up to 5 values for ? markers. A statement that
   // fails ends the calling procedure with CPF9898 and the SQL state
dcl-proc RPGAPI_setList export;
   dcl-pi *n;
      vars likeds(RPGAPI_Vars);
      list varchar(64) const;
      statement varchar(32000) const;
      value1 varchar(1000) const options(*nopass);
      value2 varchar(1000) const options(*nopass);
      value3 varchar(1000) const options(*nopass);
      value4 varchar(1000) const options(*nopass);
      value5 varchar(1000) const options(*nopass);
   end-pi;
   dcl-s sql_text varchar(32000);
   dcl-s p1 varchar(1000);
   dcl-s p2 varchar(1000);
   dcl-s p3 varchar(1000);
   dcl-s p4 varchar(1000);
   dcl-s p5 varchar(1000);
   dcl-s column_count int(10:0);
   dcl-s column_name varchar(128);
   dcl-s names varchar(64) dim(200);
   dcl-s value varchar(32000);
   dcl-s indicator int(5:0);
   dcl-s index int(10:0);
   dcl-s handle int(10:0);
   dcl-s row int(10:0);
   dcl-s rows int(10:0) inz(0);
   dcl-s markers int(10:0);

   exec sql set option commit = *none, closqlcsr = *endmod, datfmt = *iso,
                       timfmt = *iso, decmpt = *period;

   handle = handleOf(vars);
      // the list exists, empty, even when the query finds nothing
   countEntry(handle : list : *on);
   markers = %parms() - 3;
   if markers >= 1;
      p1 = value1;
   endif;
   if markers >= 2;
      p2 = value2;
   endif;
   if markers >= 3;
      p3 = value3;
   endif;
   if markers >= 4;
      p4 = value4;
   endif;
   if markers >= 5;
      p5 = value5;
   endif;

   sql_text = statement;
   exec sql deallocate descriptor local 'RPGAPI_LIST';
   exec sql prepare RPGAPI_list_statement from :sql_text;
   if sqlcode < 0;
      listFailed(list : 'prepare');
   endif;
   exec sql allocate descriptor local 'RPGAPI_LIST' with max 200;
   exec sql describe RPGAPI_list_statement
            using sql descriptor local 'RPGAPI_LIST';
   exec sql get descriptor 'RPGAPI_LIST' :column_count = count;
   if sqlcode < 0 or column_count > %elem(names);
      listFailed(list : 'describe');
   endif;
   for index = 1 to column_count;
      exec sql get descriptor 'RPGAPI_LIST' value :index :column_name = name;
      names(index) = %trim(column_name);
         // every column fetched as text, in the job's CCSID
      exec sql set descriptor 'RPGAPI_LIST' value :index type = 12,
                              length = 32000;
   endfor;

   exec sql declare RPGAPI_list_cursor cursor for RPGAPI_list_statement;
   select;
   when markers <= 0;
      exec sql open RPGAPI_list_cursor;
   when markers = 1;
      exec sql open RPGAPI_list_cursor using :p1;
   when markers = 2;
      exec sql open RPGAPI_list_cursor using :p1, :p2;
   when markers = 3;
      exec sql open RPGAPI_list_cursor using :p1, :p2, :p3;
   when markers = 4;
      exec sql open RPGAPI_list_cursor using :p1, :p2, :p3, :p4;
   other;
      exec sql open RPGAPI_list_cursor using :p1, :p2, :p3, :p4, :p5;
   endsl;
   if sqlcode < 0;
      listFailed(list : 'open');
   endif;

   dow *on;
      exec sql fetch next from RPGAPI_list_cursor
               into sql descriptor 'RPGAPI_LIST';
      if sqlcode = 100;
         leave;
      endif;
      if sqlcode < 0;
         exec sql close RPGAPI_list_cursor;
         listFailed(list : 'fetch');
      endif;
      row = RPGAPI_addRow(vars : list);
      rows += 1;
      for index = 1 to column_count;
         exec sql get descriptor 'RPGAPI_LIST' value :index
                  :value = data, :indicator = indicator;
            // a null is a field left out: the view's subfield stays empty
         if indicator >= 0;
            setEntry(handle : list : row : names(index) : value);
         endif;
      endfor;
   enddo;
   exec sql close RPGAPI_list_cursor;
   exec sql deallocate descriptor local 'RPGAPI_LIST';
   RPGAPI_log(RPGAPI_LOG_DEBUG : 'list ' + list + ': ' + %char(rows) +
              ' rows of ' + %char(column_count) + ' columns');
end-proc;


   // ends RPGAPI_setList's caller with CPF9898 and the SQL state
dcl-proc listFailed;
   dcl-pi *n;
      list varchar(64) const;
      step varchar(20) const;
   end-pi;
   dcl-s text varchar(512);
   dcl-s key char(4);
   dcl-s error_code char(8) inz(*allx'00');

   text = 'RPGAPI_setList ' + list + ': the SQL statement failed in ' + step +
          ', SQLSTATE ' + sqlstate + ', SQLCODE ' + %char(sqlcode);
   RPGAPI_log(RPGAPI_LOG_ERROR : text);
   exec sql deallocate descriptor local 'RPGAPI_LIST';
      // counter 3: past this and RPGAPI_setList, to the route
   send_program_message('CPF9898' : 'QCPFMSG   *LIBL' : text : %len(text) :
                        '*ESCAPE' : '*' : 3 : key : error_code);
end-proc;


   // for compiled views: a value by name, '' when there is none
dcl-proc RPGAPI_varValue export;
   dcl-pi *n varchar(32000);
      vars likeds(RPGAPI_Vars) const;
      name varchar(64) const;
   end-pi;
   dcl-s index int(10:0);
   dcl-s key varchar(64);

   key = %upper(%trim(name));
   for index = entry_count downto 1;
      if entries(index).handle = vars.handle and entries(index).list = '' and
         entries(index).name = key;
         return storedValue(index);
      endif;
   endfor;
   return '';
end-proc;


   // for compiled views and routes: the number of rows of a list
dcl-proc RPGAPI_listCount export;
   dcl-pi *n int(10:0);
      vars likeds(RPGAPI_Vars) const;
      list varchar(64) const;
   end-pi;
   dcl-s index int(10:0);

   index = countEntry(vars.handle : list : *off);
   if index = 0;
      return 0;
   endif;
   return entries(index).length;
end-proc;


   // for compiled views: up to max rows of a list as XML, for XML-INTO:
   // <rows><row><NAME>value</NAME>...</row>...</rows>. Returns a pointer to
   // it as a varchar(:4), a length and the text, which the view reads
   // through a based variable: returned as a value, a list of any size
   // would take that much of the view's stack. It stays until the next call
dcl-proc RPGAPI_listXml export;
   dcl-pi *n pointer;
      vars likeds(RPGAPI_Vars) const;
      list varchar(64) const;
      max int(10:0) const;
   end-pi;
   dcl-s key varchar(64);
   dcl-s index int(10:0);
   dcl-s row int(10:0) inz(0);
   dcl-s value varchar(32000);
   dcl-s length int(10:0) based(length_ptr);

   key = %upper(%trim(list));
   list_xml.length = 0;
      // the length, filled in at the end
   append(list_xml : x'00000000');
   append(list_xml : '<rows>');
   for index = 1 to entry_count;
      if entries(index).handle <> vars.handle or entries(index).list <> key or
         entries(index).row = 0 or entries(index).row > max;
         iter;
      endif;
      if entries(index).row <> row;
         if row > 0;
            append(list_xml : '</row>');
         endif;
         append(list_xml : '<row>');
         row = entries(index).row;
      endif;
      value = storedValue(index);
      append(list_xml : '<' + entries(index).name + '>');
      appendLong(list_xml : escapeXml(value));
      append(list_xml : '</' + entries(index).name + '>');
   endfor;
   if row > 0;
      append(list_xml : '</row>');
   endif;
   append(list_xml : '</rows>');
   length_ptr = list_xml.data;
   length = list_xml.length - 4;
   return list_xml.data;
end-proc;


   // appends text of up to 96000 characters, in pieces append takes
dcl-proc appendLong;
   dcl-pi *n;
      buffer likeds(buffer_t);
      text varchar(96000) const;
   end-pi;
   dcl-s start int(10:0) inz(1);

   dow start <= %len(text);
      append(buffer : %subst(text : start : %min(32766 : %len(text) - start + 1)));
      start += 32766;
   enddo;
end-proc;


dcl-proc escapeXml;
   dcl-pi *n varchar(96000);
      text varchar(32000) const;
   end-pi;
   dcl-s escaped varchar(96000);

   if %scan('&' : text) + %scan('<' : text) + %scan('>' : text) = 0;
      return text;
   endif;
   escaped = %scanrpl('&' : '&amp;' : text);
   escaped = %scanrpl('<' : '&lt;' : escaped);
   escaped = %scanrpl('>' : '&gt;' : escaped);
   return escaped;
end-proc;


   // at the start of each request: the values of the one before are gone
dcl-proc RPGAPI_clearVars export;
   dcl-s index int(10:0);
   dcl-s value pointer;

   for index = 1 to entry_count;
      if entries(index).value <> *null;
         value = entries(index).value;
         dealloc value;
      endif;
   endfor;
   entry_count = 0;
end-proc;


   // the handle of a set of values, given one when it is first used
dcl-proc handleOf;
   dcl-pi *n int(10:0);
      vars likeds(RPGAPI_Vars);
   end-pi;

   if vars.handle = 0;
      last_handle += 1;
      vars.handle = last_handle;
   endif;
   return vars.handle;
end-proc;


   // the entry holding a list's row count, added when create is on. 0 when
   // there is none
dcl-proc countEntry;
   dcl-pi *n int(10:0);
      handle int(10:0) const;
      list varchar(64) const;
      create ind const;
   end-pi;
   dcl-s index int(10:0);
   dcl-s key varchar(64);

   key = %upper(%trim(list));
   for index = entry_count downto 1;
      if entries(index).handle = handle and entries(index).list = key and
         entries(index).row = 0;
         return index;
      endif;
   endfor;
   if not create;
      return 0;
   endif;
   index = newEntry();
   entries(index).handle = handle;
   entries(index).list = key;
   entries(index).row = 0;
   entries(index).name = '';
   entries(index).value = *null;
   entries(index).length = 0;
   return index;
end-proc;


   // sets a value, or a field of a row: replaced when the same one was set
   // before in that row, added otherwise
dcl-proc setEntry;
   dcl-pi *n;
      handle int(10:0) const;
      list varchar(64) const;
      row int(10:0) const;
      name varchar(64) const;
      value varchar(32000) value;
   end-pi;
   dcl-s index int(10:0);
   dcl-s key varchar(64);
   dcl-s list_key varchar(64);
   dcl-s old_value pointer;

   key = xmlName(name);
   list_key = %upper(%trim(list));
   for index = entry_count downto 1;
      if entries(index).handle = handle and entries(index).list = list_key and
         entries(index).row = row and entries(index).name = key;
         leave;
      endif;
         // the fields of a row are together: stop at the row before it
      if list_key <> '' and entries(index).handle = handle and
         entries(index).list = list_key and entries(index).row < row;
         index = 0;
         leave;
      endif;
   endfor;
   if index < 1;
      index = newEntry();
      entries(index).handle = handle;
      entries(index).list = list_key;
      entries(index).row = row;
      entries(index).name = key;
      entries(index).value = *null;
   endif;
   if entries(index).value <> *null;
      old_value = entries(index).value;
      dealloc old_value;
      entries(index).value = *null;
   endif;
   entries(index).length = %len(value);
   if %len(value) > 0;
      entries(index).value = %alloc(%len(value));
      memcpy(entries(index).value : %addr(value : *data) : %len(value));
   endif;
end-proc;


   // the value of an entry
dcl-proc storedValue;
   dcl-pi *n varchar(32000);
      index int(10:0) const;
   end-pi;
   dcl-s value varchar(32000);

   if entries(index).length = 0 or entries(index).value = *null;
      return '';
   endif;
   %len(value) = entries(index).length;
   memcpy(%addr(value : *data) : entries(index).value : entries(index).length);
   return value;
end-proc;


   // a name as an XML element: upper case, and characters XML does not
   // allow in names (# @ $ and blanks, such as in some column names) as _
dcl-proc xmlName;
   dcl-pi *n varchar(64);
      name varchar(64) const;
   end-pi;
   dcl-s key varchar(64);

   key = %upper(%trim(name));
   key = %xlate('#@$ -' : '_____' : key);
   if key = '' or %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ_' : %subst(key : 1 : 1)) > 0;
      key = '_' + key;
   endif;
   return key;
end-proc;


dcl-proc newEntry;
   dcl-pi *n int(10:0);
   end-pi;
      // an element of the array is longer than %size says: each is padded
      // so that its pointer is aligned. Measured between two elements
   dcl-ds pair likeds(var_t) dim(2);
   dcl-s stride int(10:0);

   if entry_count = entry_room;
      if entry_room >= %elem(entries);
         RPGAPI_log(RPGAPI_LOG_ERROR : 'more than ' + %char(%elem(entries)) +
                    ' values and fields in one request');
         send_program_message('CPF9898' : 'QCPFMSG   *LIBL' :
                              'RPGAPI: too many view values in one request' :
                              43 : '*ESCAPE' : '*' : 3 : message_key :
                              message_error);
      endif;
      entry_room = %min(%elem(entries) : %max(entry_room * 2 : 1000));
      stride = %addr(pair(2)) - %addr(pair(1));
      if vars_ptr = *null;
         vars_ptr = %alloc(entry_room * stride);
      else;
         vars_ptr = %realloc(vars_ptr : entry_room * stride);
      endif;
   endif;
   entry_count += 1;
   return entry_count;
end-proc;


   // ======================================================================
   // rendering
   // ======================================================================

dcl-proc RPGAPI_render export;
   dcl-pi *n likeds(RPGAPI_Response);
      template varchar(1024) const;
      vars likeds(RPGAPI_Vars) const options(*nopass : *omit);
      response likeds(RPGAPI_Response) const options(*nopass);
   end-pi;
   dcl-ds answer likeds(RPGAPI_Response) inz;
   dcl-ds values likeds(RPGAPI_Vars) inz;
   dcl-s program char(21);

   if %parms() >= 3;
      answer = response;
   endif;
   if %parms() >= 2 and %addr(vars) <> *null;
      values = vars;
   endif;

   program = viewProgram(template);
   if program = '';
      return errorPage(template);
   endif;

      // inside a page that is being written: the view goes into it
   if RPGAPI_streaming();
      callProgram(program : values);
      return answer;
   endif;

   if answer.status = 0;
      answer.status = HTTP_OK;
   endif;
   if not RPGAPI_hasHeader(answer : 'Content-Type');
      RPGAPI_setHeader(answer : 'Content-Type' : 'text/html; charset=utf-8');
   endif;
   RPGAPI_beginResponse(answer);
   callProgram(program : values);
   RPGAPI_endResponse();
   return answer;
end-proc;


   // for compiled views: another view, written into the page where it is
dcl-proc RPGAPI_includeView export;
   dcl-pi *n;
      template varchar(1024) const;
      vars likeds(RPGAPI_Vars) const;
   end-pi;
   dcl-s program char(21);

   program = viewProgram(template);
   if program = '';
      RPGAPI_writeHtml('[' + template + ' could not be compiled: ' +
                       view_error + ']');
      return;
   endif;
   callProgram(program : vars);
end-proc;


dcl-proc callProgram;
   dcl-pi *n;
      program char(21) const;
      vars likeds(RPGAPI_Vars) const;
   end-pi;

   view_program = program;
   callView(vars);
end-proc;


   // a 500 page naming the template and why it could not be used
dcl-proc errorPage;
   dcl-pi *n likeds(RPGAPI_Response);
      template varchar(1024) const;
   end-pi;
   dcl-ds answer likeds(RPGAPI_Response) inz;

   answer.status = HTTP_INTERNAL_SERVER;
   RPGAPI_setHeader(answer : 'Content-Type' : 'text/html; charset=utf-8');
   answer.body = '<!DOCTYPE html>' + LF + '<html><head><title>View error' +
               '</title></head><body>' + LF + '<h1>' +
               RPGAPI_escapeHtml(template) + ' cannot be shown</h1>' + LF +
               '<pre>' + RPGAPI_escapeHtml(view_error) + '</pre>' + LF +
               '</body></html>' + LF;
   return answer;
end-proc;


   // the compiled program of a template, compiling it when it is new or has
   // changed: LIBRARY/RVxxxxxxxx, named after the template's name and
   // content, so the same template always has the same program (one
   // compiled elsewhere, too). '' when it cannot be, with why in view_error
dcl-proc viewProgram;
   dcl-pi *n char(21);
      template varchar(1024) const;
   end-pi;
   dcl-s path varchar(1024);
   dcl-ds info likeds(FileStat);
   dcl-s index int(10:0);
   dcl-s program char(21);
   dcl-s library char(10);

   view_error = '';
   path = viewPath(template);
   if stat(path : info) < 0;
      view_error = path + ' cannot be read: ' + errorText();
      RPGAPI_log(RPGAPI_LOG_ERROR : 'view ' + view_error);
      return '';
   endif;

   for index = 1 to cache_count;
      if cache(index).path = path;
         if cache(index).modified = info.modified and
            cache(index).size = info.size;
            return cache(index).program;
         endif;
         leave;
      endif;
   endfor;

   library = RPGAPI_views_library;
   if library = '';
      library = appLibrary();
   endif;
   program = compileView(path : library : *off);
   if program = '';
      return '';
   endif;

   if index > cache_count;
      if cache_count < %elem(cache);
         cache_count += 1;
      endif;
      index = cache_count;
   endif;
   cache(index).path = path;
   cache(index).modified = info.modified;
   cache(index).size = info.size;
   cache(index).program = program;
   return program;
end-proc;


   // a template's path: as it is when it starts with /, otherwise below the
   // views directory (RPGAPI_setViews), or the job's current directory
dcl-proc viewPath;
   dcl-pi *n varchar(1024);
      template varchar(1024) const;
   end-pi;
   dcl-s directory varchar(1024);
   dcl-s buffer char(1024);

   if %subst(%trim(template) + ' ' : 1 : 1) = '/';
      return %trim(template);
   endif;
   directory = RPGAPI_views_directory;
   if directory = '';
      if getcwd(%addr(buffer) : %size(buffer)) <> *null;
         directory = %str(%addr(buffer));
      endif;
   endif;
   if directory <> '' and %subst(directory : %len(directory) : 1) <> '/';
      directory += '/';
   endif;
   return directory + %trim(template);
end-proc;


   // the library of the app's program, where views go unless RPGAPI_setViews
   // names another
dcl-proc appLibrary;
   dcl-pi *n char(10);
   end-pi;
   dcl-s program varchar(64);
   dcl-s start int(10:0);

      // /QSYS.LIB/MYLIB.LIB/MYAPP.PGM
   program = RPGAPI_jobProgram();
   start = %len('/QSYS.LIB/') + 1;
   return %subst(program : start : %scan('.LIB/' : program : start) - start);
end-proc;


   // turns the template at path into a program in library, compiling it
   // unless a program of that name is there already (and recompile is off).
   // Returns LIBRARY/NAME, or '' with why in view_error
dcl-proc compileView;
   dcl-pi *n char(21);
      path varchar(1024) const;
      library char(10) const;
      recompile ind const;
   end-pi;
   dcl-s name char(10);
   dcl-s program char(21);
   dcl-s source_path varchar(100);
   dcl-s has_sql ind;
   dcl-ds output likeds(buffer_t) inz(*likeds);
   dcl-s crc uns(10:0);

   template_name = %subst(path : %scanr('/' : '/' + path));
   monitor;
      readTemplate(path);
   on-error;
      return '';
   endmon;

      // named after the template's file name and content
   crc = crc32(0 : %addr(template_name : *data) : %len(template_name));
   crc = crc32(crc : source_ptr : source_length);
   name = 'RV' + hex8(crc);
   program = %trim(library) + '/' + name;
   if not recompile and exists(program);
      dealloc(n) source_ptr;
      return program;
   endif;

   monitor;
      generate(output);
   on-error;
      dealloc(n) source_ptr;
      freeGenerated(output);
      RPGAPI_log(RPGAPI_LOG_ERROR : 'view ' + view_error);
      return '';
   endmon;
   has_sql = %scan('EXEC SQL' : %upper(%subst(source : 1 : %min(source_length :
                   16000000)))) > 0;
   dealloc(n) source_ptr;

   source_path = WORK_DIRECTORY + 'RPGAPI_' + %trim(name) + '.rpgle';
   monitor;
      writeUtf8(source_path : output);
   on-error;
      freeGenerated(output);
      RPGAPI_log(RPGAPI_LOG_ERROR : 'view ' + view_error);
      return '';
   endmon;

   RPGAPI_log(RPGAPI_LOG_INFO : 'compiling view ' + path + ' into ' + program);
   if not compile(name : library : source_path : has_sql : output);
      freeGenerated(output);
      RPGAPI_log(RPGAPI_LOG_ERROR : 'view ' + path + ' does not compile: ' +
                 view_error);
      return '';
   endif;
   freeGenerated(output);
   return program;
end-proc;


   // compiles the generated source into LIBRARY/NAME: a module in QTEMP,
   // bound to the RPGAPI service program. *off with the compiler's errors,
   // at their template lines, in view_error
dcl-proc compile;
   dcl-pi *n ind;
      name char(10) const;
      library char(10) const;
      source_path varchar(100) const;
      has_sql ind const;
      output likeds(buffer_t) const;
   end-pi;
   dcl-s command varchar(3000);
   dcl-s compiled ind inz(*on);

   runCommand('DLTMOD MODULE(QTEMP/' + %trim(name) + ')' : *off);
   if has_sql;
      command = 'CRTSQLRPGI OBJ(QTEMP/' + %trim(name) + ') SRCSTMF(''' +
                source_path + ''') OBJTYPE(*MODULE) CVTCCSID(*JOB) ' +
                'OPTION(*EVENTF) COMMIT(*NONE) CLOSQLCSR(*ENDMOD) ' +
                'DATFMT(*ISO) TIMFMT(*ISO) DBGVIEW(*SOURCE) OUTPUT(*NONE) ' +
                'COMPILEOPT(''TGTCCSID(*JOB)'')';
   else;
      command = 'CRTRPGMOD MODULE(QTEMP/' + %trim(name) + ') SRCSTMF(''' +
                source_path + ''') TGTCCSID(*JOB) OPTION(*EVENTF) ' +
                'DBGVIEW(*SOURCE) OUTPUT(*NONE)';
   endif;
   if not runCommand(command : *on);
      view_error = compileErrors(name : output);
      compiled = *off;
   endif;

   if compiled and not runCommand('CRTPGM PGM(' + %trim(library) + '/' +
                   %trim(name) + ') MODULE(QTEMP/' + %trim(name) + ') ' +
                   'BNDSRVPGM((' + %trim(serviceLibrary()) + '/RPGAPI)) ' +
                   'ACTGRP(*CALLER) REPLACE(*YES) TEXT(''RPGAPI view ' +
                   %subst(template_name : 1 : %min(%len(template_name) : 35)) +
                   ''')' : *on);
      view_error = 'CRTPGM of ' + %trim(library) + '/' + %trim(name) +
                   ' failed: ' + view_error;
      compiled = *off;
   endif;
   runCommand('DLTMOD MODULE(QTEMP/' + %trim(name) + ')' : *off);
   return compiled;
end-proc;


   // the compiler's errors (severity 20 and up) from its event file, at the
   // template lines the generated lines came from
dcl-proc compileErrors;
   dcl-pi *n varchar(4000);
      name char(10) const;
      output likeds(buffer_t) const;
   end-pi;
   dcl-s events_path varchar(100);
   dcl-s errors varchar(4000);
   dcl-s descriptor int(10:0);
   dcl-s buffer char(65535);
   dcl-s count int(10:0);
   dcl-s text varchar(65535);
   dcl-s line varchar(1000);
   dcl-s start int(10:0) inz(1);
   dcl-s stop int(10:0);
   dcl-s words varchar(200) dim(14);
   dcl-s message varchar(1000);
   dcl-s at int(10:0);
   dcl-s word int(10:0);
   dcl-s position int(10:0);

   events_path = WORK_DIRECTORY + 'RPGAPI_' + %trim(name) + '.evf';
   if not runCommand('CPYTOSTMF FROMMBR(''/QSYS.LIB/QTEMP.LIB/EVFEVENT.FILE/' +
                     %trim(name) + '.MBR'') TOSTMF(''' + events_path +
                     ''') STMFOPT(*REPLACE) STMFCCSID(*STDASCII)' : *off);
      return 'the compile failed; its messages could not be read (' +
             view_error + ')';
   endif;
   descriptor = open(events_path : O_RDONLY + O_TEXTDATA);
   if descriptor >= 0;
      count = read(descriptor : %addr(buffer) : %size(buffer));
      close_port(descriptor);
      if count > 0;
         text = %subst(buffer : 1 : count);
      endif;
   endif;
   unlink(events_path);

      // ERROR 0 001 1 000047 000047 000 000047 000 RNF7030 S 30 050 The ...
   dow start <= %len(text) and %len(errors) < 3500;
      stop = %scan(LF : text : start);
      if stop = 0;
         stop = %len(text) + 1;
      endif;
      line = %trim(%xlate(CR : ' ' : %subst(text : start :
                   %min(stop - start : 1000))));
      start = stop + 1;
      if %len(line) < 6 or %subst(line : 1 : 6) <> 'ERROR ';
         iter;
      endif;
      clear words;
      word = 0;
      position = 1;
      dow word < 13 and position <= %len(line);
         at = %scan(' ' : line + ' ' : position);
         if at > position;
            word += 1;
            words(word) = %subst(line : position : at - position);
         endif;
         position = at + 1;
      enddo;
         // RNS9308 and the like only say that the compile stopped
      if word < 13 or %check('0123456789' : words(12)) > 0 or
         %int(words(12)) < 20 or %subst(words(10) : 1 : 3) = 'RNS';
         iter;
      endif;
      message = '';
      if position <= %len(line);
         message = %trim(%subst(line : position));
      endif;
      errors += templateLine(output : %int(words(5))) + ': ' + words(10) +
                ' ' + message + LF;
   enddo;
   if errors = '';
      errors = 'the compile failed without messages; see the job log';
   endif;
   return errors;
end-proc;


   // the template:line a line of the generated code came from, by its
   // comment, or the one on the line before (for a line too long for one)
dcl-proc templateLine;
   dcl-pi *n varchar(300);
      output likeds(buffer_t) const;
      number int(10:0) const;
   end-pi;
   dcl-s code char(16000000) based(code_ptr);
   dcl-s line varchar(32000);
   dcl-s before varchar(32000);
   dcl-s start int(10:0) inz(1);
   dcl-s stop int(10:0);
   dcl-s index int(10:0) inz(0);
   dcl-s at int(10:0);

   code_ptr = output.data;
   dow start <= output.length;
      stop = %scan(LF : code : start : output.length - start + 1);
      if stop = 0;
         stop = output.length + 1;
      endif;
      index += 1;
      before = line;
      line = %subst(code : start : %min(stop - start : 32000));
      if index = number;
         at = %scanr('// ' + template_name + ':' : line);
         if at = 0;
            at = %scanr('// ' + template_name + ':' : before);
            if at > 0;
               return %subst(before : at + 3);
            endif;
            return template_name + ' (generated line ' + %char(number) + ')';
         endif;
         return %subst(line : at + 3);
      endif;
      start = stop + 1;
   enddo;
   return template_name;
end-proc;


   // runs a CL command. *off when it fails, with the reason in view_error
   // when report is on
dcl-proc runCommand;
   dcl-pi *n ind;
      command varchar(3000) const;
      report ind const;
   end-pi;

   monitor;
      qcmdexc(command : %len(command));
   on-error;
      if report;
         view_error = %trim(lastMessage());
      endif;
      return *off;
   endmon;
   return *on;
end-proc;


   // the text of the escape message just monitored: RPG's program status
dcl-proc lastMessage;
   dcl-pi *n varchar(200);
   end-pi;

   return program_status.message_id + ' ' +
          %trim(program_status.message_data);
end-proc;


dcl-proc exists;
   dcl-pi *n ind;
      program char(21) const;
   end-pi;

   return runCommand('CHKOBJ OBJ(' + %trim(program) + ') OBJTYPE(*PGM)' : *off);
end-proc;


   // the library of the RPGAPI service program, which views are bound to:
   // its entry on the call stack
dcl-proc serviceLibrary;
   dcl-pi *n char(10);
   end-pi;

   if service_library = '';
      service_library = RPGAPI_ownLibrary();
   endif;
   return service_library;
end-proc;


dcl-proc hex8;
   dcl-pi *n char(8);
      value uns(10:0) value;
   end-pi;
   dcl-s text char(8);
   dcl-s index int(10:0);

   for index = 8 downto 1;
      %subst(text : index : 1) = %subst(HEX : %rem(value : 16) + 1 : 1);
      value = %div(value : 16);
   endfor;
   return text;
end-proc;


   // for ERPG: compiles a template into library ahead of time. Returns the
   // program, or '' with why in errors
dcl-proc RPGAPI_compileView export;
   dcl-pi *n char(21);
      path varchar(1024) const;
      library char(10) const;
      errors varchar(4000);
   end-pi;
   dcl-s program char(21);

   program = compileView(path : library : *on);
   errors = view_error;
   return program;
end-proc;


   // ======================================================================
   // turning a template into RPG
   // ======================================================================

   // stops generating, with why in view_error: an escape message to the
   // monitor in compileView
dcl-proc generateFailed;
   dcl-pi *n;
      text varchar(1000) const;
   end-pi;
   dcl-s key char(4);
   dcl-s error_code char(8) inz(*allx'00');

   view_error = text;
   send_program_message('CPF9898' : 'QCPFMSG   *LIBL' : text :
                        %min(%len(text) : 512) : '*ESCAPE' : '*' : 1 : key :
                        error_code);
end-proc;


   // reads the template at path and converts it from UTF-8 to the job's
   // CCSID, into source
dcl-proc readTemplate;
   dcl-pi *n;
      path varchar(1024) const;
   end-pi;
   dcl-ds info likeds(FileStat);
   dcl-s descriptor int(10:0);
   dcl-s raw_ptr pointer;
   dcl-s raw char(16000000) based(raw_ptr);
   dcl-s raw_length int(10:0) inz(0);
   dcl-s count int(10:0);
   dcl-s start int(10:0) inz(1);

   source_ptr = *null;
   descriptor = open(path : O_RDONLY);
   if descriptor < 0;
      generateFailed(path + ' cannot be opened: ' + errorText());
   endif;
   if fstat(descriptor : info) < 0 or info.size > MAX_TEMPLATE;
      close_port(descriptor);
      generateFailed(template_name + ' is larger than ' +
                     %char(MAX_TEMPLATE) + ' bytes, or cannot be read');
   endif;

   raw_ptr = %alloc(info.size + 1);
   dow raw_length < info.size;
      count = read(descriptor : raw_ptr + raw_length : info.size - raw_length);
      if count <= 0;
         leave;
      endif;
      raw_length += count;
   enddo;
   close_port(descriptor);

      // a byte order mark, as some editors write at the start of UTF-8
   if raw_length >= 3 and %subst(raw : 1 : 3) = x'EFBBBF';
      start = 4;
   endif;
      // single-byte EBCDIC is never longer than UTF-8; room for DBCS shifts
   source_ptr = %alloc(raw_length * 2 + 16);
   source_length = convert(raw_ptr + start - 1 : raw_length - start + 1 :
                           UTF8 : JOB_CCSID : source_ptr :
                           raw_length * 2 + 16);
   dealloc raw_ptr;
   if source_length < 0;
      dealloc(n) source_ptr;
      generateFailed(template_name + ' is not UTF-8 text, or has characters ' +
                     'the job''s CCSID does not have');
   endif;
end-proc;


   // the program's source: the template's declarations and statements in a
   // main procedure that takes the values, and the procedures templates use
dcl-proc generate;
   dcl-pi *n;
      output likeds(buffer_t);
   end-pi;

   freeGenerated(declarations);
   freeGenerated(statements);
   parse();

   append(output : '**free' + LF);
   append(output : 'ctl-opt main(RPGAPI_view) datfmt(*iso) timfmt(*iso)' + LF);
   append(output : '        option(*srcstmt : *nodebugio);' + LF);
   append(output : '   // compiled by RPGAPI from ' + template_name + ', and ' +
                   'again when it changes' + LF);
   append(output : 'dcl-ds RPGAPI_Vars qualified template;' + LF);
   append(output : '   handle int(10:0);' + LF);
   append(output : 'end-ds;' + LF);
   append(output : 'dcl-pr RPGAPI_write;' + LF);
   append(output : '   text varchar(32000) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_writeHtml;' + LF);
   append(output : '   text varchar(32000) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_escapeHtml varchar(192000);' + LF);
   append(output : '   text varchar(32000) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_varValue varchar(32000);' + LF);
   append(output : '   vars likeds(RPGAPI_Vars) const;' + LF);
   append(output : '   name varchar(64) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_listCount int(10:0);' + LF);
   append(output : '   vars likeds(RPGAPI_Vars) const;' + LF);
   append(output : '   list varchar(64) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_listXml pointer;' + LF);
   append(output : '   vars likeds(RPGAPI_Vars) const;' + LF);
   append(output : '   list varchar(64) const;' + LF);
   append(output : '   max int(10:0) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_includeView;' + LF);
   append(output : '   template varchar(1024) const;' + LF);
   append(output : '   vars likeds(RPGAPI_Vars) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-ds RPGAPI_view_vars likeds(RPGAPI_Vars);' + LF);
   append(output : 'dcl-s RPGAPI_list_xml varchar(16000000:4) ' +
                   'based(RPGAPI_list_xml_ptr);' + LF);
   append(output : 'dcl-ds RPGAPI_view_status psds qualified;' + LF);
   append(output : '   xml_elements int(20:0) pos(372);' + LF);
   append(output : 'end-ds;' + LF);
   append(output : LF);
   append(output : 'dcl-proc RPGAPI_view;' + LF);
   append(output : '   dcl-pi *n;' + LF);
   append(output : '      RPGAPI_values likeds(RPGAPI_Vars) const;' + LF);
   append(output : '   end-pi;' + LF);
   appendBuffer(output : declarations);
   append(output : '   RPGAPI_view_vars = RPGAPI_values;' + LF);
   appendBuffer(output : statements);
   append(output : 'end-proc;' + LF);
   append(output : LF);
   append(output : '   // a value the route set' + LF);
   append(output : 'dcl-proc RPGAPI_getVar;' + LF);
   append(output : '   dcl-pi *n varchar(32000);' + LF);
   append(output : '      name varchar(64) const;' + LF);
   append(output : '   end-pi;' + LF);
   append(output : '   return RPGAPI_varValue(RPGAPI_view_vars : name);' + LF);
   append(output : 'end-proc;' + LF);
   append(output : LF);
   append(output : '   // the number of rows of a list the route set' + LF);
   append(output : 'dcl-proc RPGAPI_rows;' + LF);
   append(output : '   dcl-pi *n int(10:0);' + LF);
   append(output : '      list varchar(64) const;' + LF);
   append(output : '   end-pi;' + LF);
   append(output : '   return RPGAPI_listCount(RPGAPI_view_vars : list);' + LF);
   append(output : 'end-proc;' + LF);
   append(output : LF);
   append(output : '   // another view, written here' + LF);
   append(output : 'dcl-proc RPGAPI_include;' + LF);
   append(output : '   dcl-pi *n;' + LF);
   append(output : '      template varchar(1024) const;' + LF);
   append(output : '   end-pi;' + LF);
   append(output : '   RPGAPI_includeView(template : RPGAPI_view_vars);' + LF);
   append(output : 'end-proc;' + LF);
   freeGenerated(declarations);
   freeGenerated(statements);
end-proc;


   // goes through the template, text and tags, into declarations and
   // statements
dcl-proc parse;
   dcl-s position int(10:0) inz(1);
   dcl-s line int(10:0) inz(1);
   dcl-s open_at int(10:0);
   dcl-s close_at int(10:0);
   dcl-s tag_line int(10:0);
   dcl-s kind char(1);
   dcl-s content_start int(10:0);
   dcl-s content varchar(32000);
   dcl-s drop_break ind;

   pending = '';
   pending_line = 1;
   dow position <= source_length;
      open_at = 0;
      if position + 1 <= source_length;
         open_at = %scan('<%' : source : position :
                         source_length - position + 1);
      endif;
      if open_at = 0;
         addText(position : source_length - position + 1 : line);
         leave;
      endif;
      addText(position : open_at - position : line);
      tag_line = line;

      kind = ' ';
      if open_at + 2 <= source_length;
         kind = %subst(source : open_at + 2 : 1);
      endif;
         // <%% is <% as text
      if kind = '%';
         addTextLiteral('<%' : line);
         position = open_at + 3;
         iter;
      endif;

      content_start = open_at + 2;
      if kind = '=' or kind = '-' or kind = '#' or kind = '!';
         content_start += 1;
      else;
         kind = ' ';
      endif;
      close_at = 0;
      if content_start + 1 <= source_length;
         close_at = %scan('%>' : source : content_start :
                          source_length - content_start + 1);
      endif;
      if close_at = 0;
         generateFailed(template_name + ':' + %char(tag_line) + ': the <' +
                        '% here is never closed with %' + '>');
      endif;
      if close_at - content_start > %size(content) - 2;
         generateFailed(template_name + ':' + %char(tag_line) + ': a tag of ' +
                        'more than 32000 characters');
      endif;
      content = %subst(source : content_start : close_at - content_start);
      line += lineBreaks(content);
      position = close_at + 2;

         // -%> drops the line break that follows the tag
      drop_break = %len(content) > 0 and
                   %subst(content : %len(content) : 1) = '-';
      if drop_break;
         %len(content) = %len(content) - 1;
         if position + 1 <= source_length and
            %subst(source : position : 2) = CR + LF;
            position += 2;
            line += 1;
         elseif position <= source_length and
                %subst(source : position : 1) = LF;
            position += 1;
            line += 1;
         endif;
      endif;

      select;
      when kind = '#';
      when kind = '!';
         addCode(declarations : content : tag_line);
      when kind = '=' or kind = '-';
         flushText(*off);
         content = %trim(%xlate(CR + LF : '  ' : content));
         if content = '';
            generateFailed(template_name + ':' + %char(tag_line) + ': <' +
                           '%' + kind + ' %' + '> has no value in it');
         endif;
         if kind = '=';
            emit(statements : '   RPGAPI_writeHtml(%trimr(%char(' + content +
                              ')));' : tag_line);
         else;
            emit(statements : '   RPGAPI_write(%trimr(%char(' + content +
                              ')));' : tag_line);
         endif;
      other;
         flushText(*off);
         addCode(statements : content : tag_line);
      endsl;
   enddo;
   flushText(*off);
end-proc;


   // text of the template, from position for length bytes: into pending, and
   // a statement for each line of it
dcl-proc addText;
   dcl-pi *n;
      position int(10:0) value;
      length int(10:0) value;
      line int(10:0);
   end-pi;
   dcl-s break_at int(10:0);
   dcl-s piece_length int(10:0);

   dow length > 0;
      break_at = %scan(LF : source : position : length);
      if break_at = 0;
         piece_length = length;
      else;
         piece_length = break_at - position;
      endif;
         // a CR before the LF of a Windows line break is left out
      if break_at > 0 and piece_length > 0 and
         %subst(source : break_at - 1 : 1) = CR;
         addTextLiteral(%subst(source : position : piece_length - 1) : line);
      elseif piece_length > 0;
         addTextLiteral(%subst(source : position : piece_length) : line);
      endif;
      if break_at = 0;
         leave;
      endif;
      flushText(*on);
      line += 1;
      length -= break_at - position + 1;
      position = break_at + 1;
   enddo;
end-proc;


   // adds text without line breaks to pending, written in pieces when there
   // is a lot of it
dcl-proc addTextLiteral;
   dcl-pi *n;
      text varchar(32000) const;
      line int(10:0) const;
   end-pi;
   dcl-s start int(10:0) inz(1);
   dcl-s count int(10:0);

   if pending = '';
      pending_line = line;
   endif;
   dow start <= %len(text);
      if %len(pending) = %size(pending) - 2;
         flushText(*off);
         pending_line = line;
      endif;
      count = %min(%len(text) - start + 1 : %size(pending) - 2 - %len(pending));
      pending += %subst(text : start : count);
      start += count;
   enddo;
end-proc;


   // a statement writing the pending text, and a line break after it when
   // line_break is on. The text goes into RPG literals of about 60
   // characters, quotes doubled, and characters below x'40' (a tab, other
   // controls) as x'..', which a literal cannot hold safely
dcl-proc flushText;
   dcl-pi *n;
      line_break ind const;
   end-pi;
   dcl-s parts varchar(100) dim(200);
   dcl-s count int(10:0) inz(1);
   dcl-s index int(10:0);
   dcl-s character char(1);
   dcl-s in_quotes ind inz(*off);
   dcl-ds byte qualified;
      value uns(3:0);
      text char(1) overlay(value);
   end-ds;

   if pending = '' and not line_break;
      return;
   endif;
   for index = 1 to %len(pending);
      character = %subst(pending : index : 1);
      byte.text = character;
      if byte.value < 64;
         if in_quotes;
            parts(count) += '''';
            in_quotes = *off;
         endif;
         if parts(count) <> '';
            parts(count) += ' + ';
         endif;
         parts(count) += 'x''' + %subst(HEX : %div(byte.value : 16) + 1 : 1) +
                         %subst(HEX : %rem(byte.value : 16) + 1 : 1) + '''';
      else;
         if not in_quotes;
            if parts(count) <> '';
               parts(count) += ' + ';
            endif;
            parts(count) += '''';
            in_quotes = *on;
         endif;
         parts(count) += character;
         if character = '''';
            parts(count) += '''';
         endif;
      endif;
      if %len(parts(count)) >= 60;
         if in_quotes;
            parts(count) += '''';
            in_quotes = *off;
         endif;
         count += 1;
      endif;
   endfor;
   if in_quotes;
      parts(count) += '''';
   endif;
   if parts(count) = '';
      count -= 1;
   endif;
   if line_break;
      count += 1;
      parts(count) = 'x''25''';
   endif;
   emitParts(parts : count);
   pending = '';
end-proc;


   // RPGAPI_write of parts joined with +, on lines of up to 90 characters
dcl-proc emitParts;
   dcl-pi *n;
      parts varchar(100) dim(200) const;
      count int(10:0) const;
   end-pi;
   dcl-s index int(10:0);
   dcl-s statement varchar(200);

   statement = '   RPGAPI_write(' + parts(1);
   for index = 2 to count;
      if %len(statement) + 3 + %len(parts(index)) > 88;
         emit(statements : statement + ' +' : pending_line);
         statement = '                ' + parts(index);
      else;
         statement += ' + ' + parts(index);
      endif;
   endfor;
   emit(statements : statement + ');' : pending_line);
end-proc;


   // the lines of code in a tag, one line of generated code each
dcl-proc addCode;
   dcl-pi *n;
      buffer likeds(buffer_t);
      code varchar(32000) const;
      line int(10:0) value;
   end-pi;
   dcl-s start int(10:0) inz(1);
   dcl-s break_at int(10:0);
   dcl-s text varchar(32000);

   dow start <= %len(code);
      break_at = %scan(LF : code : start);
      if break_at = 0;
         text = %subst(code : start);
         start = %len(code) + 1;
      else;
         text = %subst(code : start : break_at - start);
         start = break_at + 1;
      endif;
      text = %trim(%xlate(CR : ' ' : text));
      if text <> '';
         addStatement(buffer : text : line);
      endif;
      line += 1;
   enddo;
end-proc;


   // a line of code from a tag. target = RPGAPI_getList(list); becomes the
   // XML-INTO that fills the array target, a dim(*var) array of a data
   // structure, from the list, with as many elements as there are rows
dcl-proc addStatement;
   dcl-pi *n;
      buffer likeds(buffer_t);
      text varchar(32000) const;
      line int(10:0) const;
   end-pi;
   dcl-s upper varchar(32000);
   dcl-s call_at int(10:0);
   dcl-s equals_at int(10:0);
   dcl-s start int(10:0);
   dcl-s close_at int(10:0);
   dcl-s end_at int(10:0);
   dcl-s depth int(10:0) inz(1);
   dcl-s in_quotes ind inz(*off);
   dcl-s position int(10:0);
   dcl-s character char(1);
   dcl-s target varchar(1000);
   dcl-s list varchar(1000);

   upper = %upper(text);
   call_at = %scan('RPGAPI_GETLIST(' : upper);
   if call_at = 0;
      emit(buffer : '   ' + text : line);
      return;
   endif;

      // the statement: after the ; before it, up to the ; after the call
   equals_at = %scanr('=' : text : 1 : call_at);
   start = %scanr(';' : text : 1 : call_at) + 1;
   for position = call_at + 15 to %len(text);
      character = %subst(text : position : 1);
      if character = '''';
         in_quotes = not in_quotes;
      elseif not in_quotes and character = '(';
         depth += 1;
      elseif not in_quotes and character = ')';
         depth -= 1;
         if depth = 0;
            close_at = position;
            leave;
         endif;
      endif;
   endfor;
   if close_at > 0;
      end_at = %scan(';' : text : close_at);
   endif;
   if equals_at < start or close_at = 0 or end_at = 0;
      generateFailed(template_name + ':' + %char(line) + ': use RPGAPI_getList ' +
                     'on a line of its own, as array = RPGAPI_getList(name);');
   endif;
   target = %trim(%subst(text : start : equals_at - start));
   list = %trim(%subst(text : call_at + 15 : close_at - call_at - 15));
   if target = '' or list = '';
      generateFailed(template_name + ':' + %char(line) + ': RPGAPI_getList ' +
                     'needs an array to fill and a list name');
   endif;

   if start > 1;
      emit(buffer : '   ' + %trim(%subst(text : 1 : start - 1)) : line);
   endif;
   emit(buffer : '   %elem(' + target + ') = %elem(' + target + ' : *max);' :
        line);
      // a field a row does not have (a null) keeps the subfield's default,
      // not what grew into the array
   emit(buffer : '   clear ' + target + ';' : line);
   emit(buffer : '   if RPGAPI_listCount(RPGAPI_view_vars : ' + list +
                 ') > 0;' : line);
   emit(buffer : '      RPGAPI_list_xml_ptr = RPGAPI_listXml(RPGAPI_view_vars : ' +
                 list + ' : %elem(' + target + ' : *max));' : line);
   emit(buffer : '      xml-into ' + target + ' %xml(RPGAPI_list_xml :' : line);
   emit(buffer : '         ''path=rows/row case=any allowmissing=yes ' +
                 'allowextra=yes'');' : line);
   emit(buffer : '      %elem(' + target + ') = ' +
                 'RPGAPI_view_status.xml_elements;' : line);
   emit(buffer : '   else;' : line);
   emit(buffer : '      %elem(' + target + ') = 0;' : line);
   emit(buffer : '   endif;' : line);
   if end_at < %len(text);
      addStatement(buffer : %trim(%subst(text : end_at + 1)) : line);
   endif;
end-proc;


   // a line of generated code, with the template line it came from; a
   // comment that does not fit after the code goes on the line before it
dcl-proc emit;
   dcl-pi *n;
      buffer likeds(buffer_t);
      text varchar(32100) const;
      line int(10:0) const;
   end-pi;
   dcl-s comment varchar(300);

   comment = '// ' + template_name + ':' + %char(line);
   if %len(text) + 2 + %len(comment) <= MAX_LINE;
      append(buffer : text + '  ' + comment + LF);
   else;
      append(buffer : '   ' + comment + LF);
      append(buffer : text + LF);
   endif;
end-proc;


dcl-proc lineBreaks;
   dcl-pi *n int(10:0);
      text varchar(32000) const;
   end-pi;
   dcl-s count int(10:0) inz(0);
   dcl-s at int(10:0) inz(0);

   dow *on;
      at = %scan(LF : text : at + 1);
      if at = 0;
         return count;
      endif;
      count += 1;
   enddo;
end-proc;


dcl-proc append;
   dcl-pi *n;
      buffer likeds(buffer_t);
      text varchar(32766) value;
   end-pi;

   if buffer.length + %len(text) > buffer.size;
      buffer.size = %max(buffer.size * 2 : buffer.length + %len(text) + 65536);
      if buffer.data = *null;
         buffer.data = %alloc(buffer.size);
      else;
         buffer.data = %realloc(buffer.data : buffer.size);
      endif;
   endif;
   if %len(text) > 0;
      memcpy(buffer.data + buffer.length : %addr(text : *data) : %len(text));
      buffer.length += %len(text);
   endif;
end-proc;


dcl-proc appendBuffer;
   dcl-pi *n;
      buffer likeds(buffer_t);
      added likeds(buffer_t) const;
   end-pi;
   dcl-s piece varchar(32766);
   dcl-s done int(10:0) inz(0);
   dcl-s count int(10:0);

   dow done < added.length;
      count = %min(32766 : added.length - done);
      %len(piece) = count;
      memcpy(%addr(piece : *data) : added.data + done : count);
      append(buffer : piece);
      done += count;
   enddo;
end-proc;


dcl-proc freeGenerated;
   dcl-pi *n;
      buffer likeds(buffer_t);
   end-pi;

   if buffer.data <> *null;
      dealloc(n) buffer.data;
   endif;
   buffer.length = 0;
   buffer.size = 0;
end-proc;


   // writes the generated code as UTF-8, in a file tagged CCSID 1208
dcl-proc writeUtf8;
   dcl-pi *n;
      path varchar(1024) const;
      buffer likeds(buffer_t) const;
   end-pi;
   dcl-s descriptor int(10:0);
   dcl-s utf8_ptr pointer;
   dcl-s utf8_length int(10:0);
      // rw-r--r--
   dcl-c MODE 420;

   utf8_ptr = %alloc(buffer.length * 3 + 16);
   utf8_length = convert(buffer.data : buffer.length : JOB_CCSID : UTF8 :
                         utf8_ptr : buffer.length * 3 + 16);
   if utf8_length < 0;
      dealloc utf8_ptr;
      generateFailed('Converting the generated code to UTF-8 failed');
   endif;

      // replaced, so that it is created with the CCSID
   unlink(path);
   descriptor = open(path : O_WRONLY + O_CREAT + O_TRUNC + O_CCSID : MODE :
                     UTF8);
   if descriptor < 0;
      dealloc utf8_ptr;
      generateFailed(path + ' cannot be written: ' + errorText());
   endif;
   if write(descriptor : utf8_ptr : utf8_length) <> utf8_length;
      close_port(descriptor);
      dealloc utf8_ptr;
      generateFailed(path + ' cannot be written: ' + errorText());
   endif;
   close_port(descriptor);
   dealloc utf8_ptr;
end-proc;


   // converts length bytes at input between CCSIDs into output, which has
   // room for size bytes. Returns the converted length, -1 when it failed
dcl-proc convert;
   dcl-pi *n int(10:0);
      input pointer value;
      length int(10:0) value;
      from_ccsid int(10:0) const;
      to_ccsid int(10:0) const;
      output pointer value;
      size int(10:0) value;
   end-pi;
   dcl-ds from_code likeds(QtqCode_T) inz(*likeds);
   dcl-ds to_code likeds(QtqCode_T) inz(*likeds);
   dcl-ds converter likeds(iconv_t);
   dcl-s input_left uns(10:0);
   dcl-s output_left uns(10:0);
   dcl-s return_code int(10:0);

   if length <= 0;
      return 0;
   endif;
   from_code.ccsid = from_ccsid;
   to_code.ccsid = to_ccsid;
   converter = iconv_open(to_code : from_code);
   if converter.return_value = -1;
      return -1;
   endif;
   input_left = length;
   output_left = size;
      // bytes that are not valid in from_ccsid, such as a Latin-1 file read
      // as UTF-8, end the conversion with MCH1210 rather than -1
   monitor;
      return_code = iconv(converter : %addr(input) : %addr(input_left) :
                          %addr(output) : %addr(output_left));
   on-error;
      return_code = -1;
   endmon;
   iconv_close(converter);
   if return_code = -1;
      return -1;
   endif;
   return size - output_left;
end-proc;


dcl-proc errorText;
   dcl-pi *n varchar(200);
   end-pi;
   dcl-s error_number int(10:0) based(error_number_ptr);

   error_number_ptr = get_errno();
   return %str(strerror(error_number)) + ' (errno ' + %char(error_number) +
          ')';
end-proc;
