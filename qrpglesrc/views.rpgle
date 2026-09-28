**free
ctl-opt nomain option(*nodebugio:*srcstmt);

   // Views: EJS-style templates with RPG inside the tags, compiled and run
   // while the app runs. RPGAPI_render('customers.erpg' : %addr(page)) turns
   // the template into an RPG program the first time it is asked for (and
   // again whenever it, or a file it includes, changes), compiles it into
   // the app's views library, and calls it with the pointer; the program
   // writes the page, which is streamed to the client. The template bases the
   // same data structure as the route on that pointer, RPGAPI_data: the
   // route's data, read in place, with its types.
   //
   // In a template:
   //   <% code %>     RPG statements, such as for, if, exec sql, calls
   //   <%= expr %>    a value, HTML-escaped (RPGAPI_writeHtml)
   //   <%- expr %>    a value as it is (RPGAPI_write)
   //   <%# text %>    a comment, left out
   //   <%! decls %>   declarations (dcl-s, dcl-ds, /include of a copybook),
   //                  put first in the program
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

   // a user space, the objects of a library listed into it, and where it is
dcl-pr create_user_space extpgm('QUSCRTUS');
   name char(20) const;
   attribute char(10) const;
   size int(10:0) const;
   initial char(1) const;
   authority char(10) const;
   text char(50) const;
   replace char(10) const;
   error_code char(8);
end-pr;
dcl-pr list_objects extpgm('QUSLOBJ');
   space char(20) const;
   format char(8) const;
   objects char(20) const;
   type char(10) const;
   error_code char(8);
end-pr;
dcl-pr user_space_pointer extpgm('QUSPTRUS');
   space char(20) const;
   pointer pointer;
   error_code char(8);
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
   data pointer const;
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

   // ----- compiled views, as this job last found them -------------------

   // a template and the files it includes (copybooks), with when each last
   // changed: the view is compiled again when any of them has
dcl-ds cached_t qualified template;
   path varchar(1024);
   modified int(10:0);
   size int(10:0);
   program char(21);
   include_count int(10:0);
   includes varchar(1024) dim(10);
   include_modified int(10:0) dim(10);
   include_size int(10:0) dim(10);
end-ds;
dcl-ds cache likeds(cached_t) dim(100);
dcl-s cache_count int(10:0) inz(0);
dcl-s service_library char(10) inz(*blanks);
   // the files the template being compiled includes
dcl-s include_count int(10:0);
dcl-s includes varchar(1024) dim(10);

   // ----- the template being turned into RPG ----------------------------

dcl-ds buffer_t qualified template;
   data pointer inz(*null);
   length int(10:0) inz(0);
   size int(10:0) inz(0);
end-ds;
dcl-ds declarations likeds(buffer_t) inz(*likeds);
dcl-ds statements likeds(buffer_t) inz(*likeds);
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
   // rendering
   // ======================================================================

dcl-proc RPGAPI_render export;
   dcl-pi *n likeds(RPGAPI_Response);
      template varchar(1024) const;
      data pointer value options(*nopass);
      response likeds(RPGAPI_Response) const options(*nopass);
   end-pi;
   dcl-ds answer likeds(RPGAPI_Response) inz;
   dcl-s passed pointer inz(*null);
   dcl-s program char(21);

   if %parms() >= 3;
      answer = response;
   endif;
   if %parms() >= 2;
      passed = data;
   endif;

   program = viewProgram(template);
   if program = '';
      return errorPage(template);
   endif;

      // inside a page that is being written: the view goes into it
   if RPGAPI_streaming();
      callProgram(program : passed);
      return answer;
   endif;

   if answer.status = 0;
      answer.status = HTTP_OK;
   endif;
   if not RPGAPI_hasHeader(answer : 'Content-Type');
      RPGAPI_setHeader(answer : 'Content-Type' : 'text/html; charset=utf-8');
   endif;
   RPGAPI_beginResponse(answer);
   callProgram(program : passed);
   RPGAPI_endResponse();
   return answer;
end-proc;


   // for compiled views: another view, written into the page where it is
dcl-proc RPGAPI_includeView export;
   dcl-pi *n;
      template varchar(1024) const;
      data pointer value;
   end-pi;
   dcl-s program char(21);

   program = viewProgram(template);
   if program = '';
      RPGAPI_writeHtml('[' + template + ' could not be compiled: ' +
                       view_error + ']');
      return;
   endif;
   callProgram(program : data);
end-proc;


dcl-proc callProgram;
   dcl-pi *n;
      program char(21) const;
      data pointer value;
   end-pi;

   view_program = program;
   callView(data);
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
   dcl-s included int(10:0);
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
            cache(index).size = info.size and unchangedIncludes(index);
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
   cache(index).include_count = include_count;
   for included = 1 to include_count;
      cache(index).includes(included) = includes(included);
      cache(index).include_modified(included) = -1;
      cache(index).include_size(included) = -1;
      if stat(includes(included) : info) = 0;
         cache(index).include_modified(included) = info.modified;
         cache(index).include_size(included) = info.size;
      endif;
   endfor;
   return program;
end-proc;


   // whether none of the files a cached view includes has changed since
dcl-proc unchangedIncludes;
   dcl-pi *n ind;
      index int(10:0) const;
   end-pi;
   dcl-ds info likeds(FileStat);
   dcl-s included int(10:0);

   for included = 1 to cache(index).include_count;
      if stat(cache(index).includes(included) : info) < 0;
         if cache(index).include_modified(included) <> -1;
            return *off;
         endif;
      elseif info.modified <> cache(index).include_modified(included) or
             info.size <> cache(index).include_size(included);
         return *off;
      endif;
   endfor;
   return *on;
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
   dcl-s included int(10:0);
   dcl-s text char(50);
   dcl-s path_copy varchar(1024);

   template_name = %subst(path : %scanr('/' : '/' + path));
   monitor;
      readTemplate(path);
   on-error;
      return '';
   endmon;

      // named after the template's file name and content, and the content of
      // the files it includes: a changed copybook is a different view
   crc = crc32(0 : %addr(template_name : *data) : %len(template_name));
   crc = crc32(crc : source_ptr : source_length);
   findIncludes(%subst(path : 1 : %scanr('/' : path)));
   for included = 1 to include_count;
      crc = crcOfFile(crc : includes(included));
   endfor;
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

      // the program's text names the template: a hash of its path, which
      // tells two templates of the same name apart, and its name
   path_copy = path;
   text = 'RPGAPI view ' + hex8(crc32(0 : %addr(path_copy : *data) :
                                      %len(path_copy))) + ' ' + template_name;
   RPGAPI_log(RPGAPI_LOG_INFO : 'compiling view ' + path + ' into ' + program);
   if not compile(name : library : source_path : has_sql : output :
                  %subst(path : 1 : %scanr('/' : path) - 1) : text);
      freeGenerated(output);
      RPGAPI_log(RPGAPI_LOG_ERROR : 'view ' + path + ' does not compile: ' +
                 view_error);
      return '';
   endif;
   freeGenerated(output);
   deleteOlderVersions(library : name : %subst(text : 1 : 20));
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
      directory varchar(1024) const;
      text char(50) const;
   end-pi;
   dcl-s command varchar(3000);
   dcl-s compiled ind inz(*on);

   runCommand('DLTMOD MODULE(QTEMP/' + %trim(name) + ')' : *off);
      // copybooks the view includes are found in the template's directory
   if has_sql;
         // *LVL2: the SQL precompiler reads the copybooks too, for host
         // variables declared in them
      command = 'CRTSQLRPGI OBJ(QTEMP/' + %trim(name) + ') SRCSTMF(''' +
                source_path + ''') OBJTYPE(*MODULE) CVTCCSID(*JOB) ' +
                'OPTION(*EVENTF) COMMIT(*NONE) CLOSQLCSR(*ENDMOD) ' +
                'DATFMT(*ISO) TIMFMT(*ISO) DBGVIEW(*SOURCE) OUTPUT(*NONE) ' +
                'RPGPPOPT(*LVL2) INCDIR(''' + directory + ''') ' +
                'COMPILEOPT(''TGTCCSID(*JOB) INCDIR(''''' + directory +
                ''''')'')';
   else;
      command = 'CRTRPGMOD MODULE(QTEMP/' + %trim(name) + ') SRCSTMF(''' +
                source_path + ''') TGTCCSID(*JOB) OPTION(*EVENTF) ' +
                'DBGVIEW(*SOURCE) OUTPUT(*NONE) INCDIR(''' + directory + ''')';
   endif;
   if not runCommand(command : *on);
      view_error = compileErrors(name : output);
      compiled = *off;
   endif;

   if compiled and not runCommand('CRTPGM PGM(' + %trim(library) + '/' +
                   %trim(name) + ') MODULE(QTEMP/' + %trim(name) + ') ' +
                   'BNDSRVPGM((' + %trim(serviceLibrary()) + '/RPGAPI)) ' +
                   'ACTGRP(*CALLER) REPLACE(*YES) TEXT(''' + %trimr(%scanrpl('''' : '''''' : text)) + ''')' : *on);
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


   // deletes the other programs in library whose text starts with prefix
   // ('RPGAPI view' and the hash of the template's path): older versions of
   // the view just compiled into keep. A program another job is running
   // cannot be deleted; it goes the next time the view is compiled
dcl-proc deleteOlderVersions;
   dcl-pi *n;
      library char(10) const;
      keep char(10) const;
      prefix char(20) const;
   end-pi;
   dcl-c SPACE 'RPGAPIVWS QTEMP     ';
   dcl-s space_ptr pointer;
   dcl-ds header qualified based(space_ptr);
      list_offset int(10:0) pos(125);
      entries int(10:0) pos(133);
      entry_size int(10:0) pos(137);
   end-ds;
      // OBJL0200: name, library, type, status, attribute, text
   dcl-ds entry qualified based(entry_ptr);
      name char(10) pos(1);
      library char(10) pos(11);
      text char(50) pos(42);
   end-ds;
   dcl-s index int(10:0);
   dcl-s error_code char(8) inz(*allx'00');

   monitor;
      create_user_space(SPACE : 'RPGAPI' : 65536 : x'00' : '*EXCLUDE' :
                        'RPGAPI views' : '*YES' : error_code);
      list_objects(SPACE : 'OBJL0200' : 'RV*       ' + library : '*PGM' :
                   error_code);
      user_space_pointer(SPACE : space_ptr : error_code);
   on-error;
      RPGAPI_log(RPGAPI_LOG_WARN : 'older versions of a view in ' +
                 %trim(library) + ' could not be listed: ' + lastMessage());
      return;
   endmon;

   for index = 1 to header.entries;
      entry_ptr = space_ptr + header.list_offset + (index - 1) * header.entry_size;
      if entry.name <> keep and %subst(entry.text : 1 : 20) = prefix;
         if runCommand('DLTPGM PGM(' + %trim(library) + '/' + %trim(entry.name) +
                       ')' : *off);
            RPGAPI_log(RPGAPI_LOG_DEBUG : 'deleted ' + %trim(entry.name) +
                       ', an older version of ' + %trim(%subst(entry.text : 22)));
         endif;
      endif;
   endfor;
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


   // the files the template in source includes with /include or /copy, in
   // includes: a path in quotes or up to a blank, relative to directory
   // unless it starts with /. Members (QRPGLESRC,NAME) are left out
dcl-proc findIncludes;
   dcl-pi *n;
      directory varchar(1024) const;
   end-pi;
   dcl-s upper varchar(32000);
   dcl-s at int(10:0) inz(0);
   dcl-s start int(10:0);
   dcl-s stop int(10:0);
   dcl-s name varchar(1024);
   dcl-s word varchar(10);
   dcl-s position int(10:0) inz(1);
   dcl-s piece int(10:0);

   include_count = 0;
      // in pieces of 32000: %upper works on a varchar
   dow position <= source_length and include_count < %elem(includes);
      piece = %min(32000 : source_length - position + 1);
      upper = %upper(%subst(source : position : piece));
      at = 0;
      dow include_count < %elem(includes);
         at = %scan('/' : upper : at + 1);
         if at = 0;
            leave;
         endif;
            // a / near the end, as in </html>, is not one
         word = '';
         if %subst(upper + '        ' : at : 8) = '/INCLUDE';
            word = '/INCLUDE';
         elseif %subst(upper + '     ' : at : 5) = '/COPY';
            word = '/COPY';
         endif;
         if word = '';
            iter;
         endif;
         start = at + %len(word);
            // /COPYRIGHT is not a /COPY
         if %subst(upper + ' ' : start : 1) <> ' ' and
            %subst(upper + ' ' : start : 1) <> '''';
            iter;
         endif;
         dow start <= %len(upper) and %subst(upper : start : 1) = ' ';
            start += 1;
         enddo;
         if start > %len(upper);
            leave;
         endif;
         if %subst(upper : start : 1) = '''';
            stop = %scan('''' : upper : start + 1);
            start += 1;
         else;
            stop = %scan(' ' : upper + ' ' : start);
            if %scan(LF : upper : start) > 0 and %scan(LF : upper : start) < stop;
               stop = %scan(LF : upper : start);
            endif;
         endif;
         if stop <= start;
            iter;
         endif;
            // the name as written, not upper-cased
         name = %trim(%xlate(CR : ' ' : %subst(source : position + start - 1 :
                                               stop - start)));
         if name = '' or %scan(',' : name) > 0;
            iter;
         endif;
         if %subst(name : 1 : 1) <> '/';
            name = directory + name;
         endif;
         include_count += 1;
         includes(include_count) = name;
      enddo;
      position += piece;
   enddo;
end-proc;


   // the CRC32 of a file's bytes, on top of crc. Unchanged when it cannot be
   // read: the compile names it
dcl-proc crcOfFile;
   dcl-pi *n uns(10:0);
      crc uns(10:0) value;
      path varchar(1024) const;
   end-pi;
   dcl-s descriptor int(10:0);
   dcl-s buffer char(32768);
   dcl-s count int(10:0);

   descriptor = open(path : O_RDONLY);
   if descriptor < 0;
      return crc;
   endif;
   dow *on;
      count = read(descriptor : %addr(buffer) : %size(buffer));
      if count <= 0;
         leave;
      endif;
      crc = crc32(crc : %addr(buffer) : count);
   enddo;
   close_port(descriptor);
   return crc;
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
   // main procedure that takes the pointer to the route's data
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
                   'again when it or a file' + LF);
   append(output : '   // it includes changes' + LF);
   append(output : 'dcl-pr RPGAPI_write;' + LF);
   append(output : '   text varchar(32000) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_writeHtml;' + LF);
   append(output : '   text varchar(32000) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_escapeHtml varchar(192000);' + LF);
   append(output : '   text varchar(32000) const;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : 'dcl-pr RPGAPI_includeView;' + LF);
   append(output : '   template varchar(1024) const;' + LF);
   append(output : '   data pointer value;' + LF);
   append(output : 'end-pr;' + LF);
   append(output : '   // the data the route passed to RPGAPI_render: the view ' +
                   'bases its data' + LF);
   append(output : '   // structure on it' + LF);
   append(output : 'dcl-s RPGAPI_data pointer;' + LF);
   append(output : LF);
   append(output : 'dcl-proc RPGAPI_view;' + LF);
   append(output : '   dcl-pi *n;' + LF);
   append(output : '      RPGAPI_passed pointer const;' + LF);
   append(output : '   end-pi;' + LF);
   appendBuffer(output : declarations);
   append(output : '   RPGAPI_data = RPGAPI_passed;' + LF);
   appendBuffer(output : statements);
   append(output : 'end-proc;' + LF);
   append(output : LF);
   append(output : '   // another view, written here, with this one''s data or ' +
                   'other data' + LF);
   append(output : 'dcl-proc RPGAPI_include;' + LF);
   append(output : '   dcl-pi *n;' + LF);
   append(output : '      template varchar(1024) const;' + LF);
   append(output : '      data pointer value options(*nopass);' + LF);
   append(output : '   end-pi;' + LF);
   append(output : '   if %parms() >= 2;' + LF);
   append(output : '      RPGAPI_includeView(template : data);' + LF);
   append(output : '   else;' + LF);
   append(output : '      RPGAPI_includeView(template : RPGAPI_data);' + LF);
   append(output : '   endif;' + LF);
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

   if %len(pending) = 0;
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

   if %len(pending) = 0 and not line_break;
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
      if text <> '' and %subst(text : 1 : 1) = '/';
            // a directive (/include, /copy, /if...): at the start of its
            // line, with the template line on the line before
         append(buffer : '   // ' + template_name + ':' + %char(line) + LF);
         append(buffer : text + LF);
      elseif text <> '';
         emit(buffer : '   ' + text : line);
      endif;
      line += 1;
   enddo;
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
