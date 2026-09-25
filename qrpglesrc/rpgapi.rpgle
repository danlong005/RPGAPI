**free

ctl-opt option(*nodebugio:*srcstmt) nomain;
/include 'rpgapi_h.rpgle'
/include 'socket_h.rpgle'

   // HTTP text is UTF-8 on the wire and the job's CCSID in the program
dcl-c RPGAPI_UTF8 1208;
dcl-c RPGAPI_JOB_CCSID 0;

   // seconds a client has to send its whole request. The server handles one
   // connection at a time, so a client that stalls holds up everyone else
dcl-c RPGAPI_READ_TIMEOUT 30;

   // every field has to start as zeros: declare it with inz(*likeds)
dcl-ds RPGAPI_QtqCode_T qualified template inz;
   ccsid int(10:0);
   conversion_alternative int(10:0);
   substitution_alternative int(10:0);
   shift_state_alternative int(10:0);
   input_length_option int(10:0);
   error_option int(10:0);
   reserved char(8) inz(*allx'00');
end-ds;

dcl-ds RPGAPI_iconv_t qualified template;
   return_value int(10:0);
   cd int(10:0) dim(12);
end-ds;

dcl-pr iconv_open likeds(RPGAPI_iconv_t) extproc('QtqIconvOpen');
   to_code likeds(RPGAPI_QtqCode_T) const;
   from_code likeds(RPGAPI_QtqCode_T) const;
end-pr;

dcl-pr iconv int(10:0) extproc('iconv');
   converter likeds(RPGAPI_iconv_t) value;
   input pointer value;
   input_left pointer value;
   output pointer value;
   output_left pointer value;
end-pr;

dcl-pr iconv_close int(10:0) extproc('iconv_close');
   converter likeds(RPGAPI_iconv_t) value;
end-pr;

   // a worker job finds the listening socket it inherited in this variable
dcl-c RPGAPI_WORKER_VAR 'RPGAPI_LISTEN_FD';
   // how often, in milliseconds, a worker checks that the main job still runs
dcl-c RPGAPI_WORKER_CHECK_MS 5000;

dcl-ds RPGAPI_inheritance_t qualified template inz;
   flags uns(10:0);
   process_group int(10:0);
   signal_mask char(8) inz(*allx'00');
   signal_default char(8) inz(*allx'00');
end-ds;
   // workers get the main job's name, so ENDJOB can find them by it
dcl-c SPAWN_SETJOBNAMEPARENT_NP 128;

dcl-pr spawn int(10:0) extproc('spawn');
   path pointer value options(*string);
   fd_count int(10:0) value;
   fd_map int(10:0) dim(1) const;
   inherit likeds(RPGAPI_inheritance_t) const;
   argv pointer dim(2) const;
   envp pointer dim(2) const;
end-pr;

dcl-pr getenv pointer extproc('getenv');
   name pointer value options(*string);
end-pr;

dcl-pr getppid int(10:0) extproc('getppid');
end-pr;

dcl-pr kill int(10:0) extproc('kill');
   process_id int(10:0) value;
   signal int(10:0) value;
end-pr;

dcl-pr retrieve_call_stack extpgm('QWVRCSTK');
   receiver char(65535) options(*varsize);
   receiver_length int(10:0) const;
   format char(8) const;
   job_id char(56) const;
   job_id_format char(8) const;
   error_code char(8);
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

dcl-proc RPGAPI_start export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      port int(10:0) options(*nopass) const;
      workers int(10:0) options(*nopass) const;
   end-pi;
   dcl-s index int(10:0) inz;
   dcl-s index2 int(10:0) inz;
   dcl-s worker_count int(10:0) inz(1);
   dcl-s main_job_pid int(10:0) inz(0);
   dcl-s worker_env pointer;
   dcl-s route_found ind inz;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds request likeds(RPGAPI_Request) inz;
   dcl-s middleware_completed ind;

   if %parms >= 2;
      config.port = port;
   elseif config.port = 0;
      config.port = 3000;
   endif;
   if %parms >= 3 and workers > 1;
      worker_count = workers;
   endif;

      // a worker job was started by RPGAPI_startWorkers from the main job, and
      // serves the socket the main job opened
   worker_env = getenv(RPGAPI_WORKER_VAR);
   if worker_env <> *null;
      config.socket_descriptor = %int(%str(worker_env));
      main_job_pid = getppid();
      RPGAPI_initHttp();
   else;
      RPGAPI_setup(config);
      if worker_count > 1;
         RPGAPI_startWorkers(config : worker_count - 1);
      endif;
   endif;

   dow RPGAPI_acceptConnection(config : main_job_pid);
      monitor;
         clear request;
         request = RPGAPI_acceptRequest(config);

            // no complete request arrived in time: nothing to answer
         if request.method = *blanks;
            close_port( config.return_socket_descriptor );
            iter;
         endif;

         clear response;
         clear route_found;

            // run the matching middleware once, in the order it was added.
            // One that returns *off ends the request with the response it set
         middleware_completed = *on;
         for index2 = 1 to %elem(config.middlewares) by 1;
            if config.middlewares(index2).url = *blanks;
               leave;
            endif;

            if RPGAPI_mwMatches(config.middlewares(index2) : request);
               RPGAPI_mwCallback_ptr = config.middlewares(index2).procedure;
               middleware_completed = RPGAPI_mwCallback(request : response);

               if middleware_completed = *off;
                  leave;
               endif;
            endif;
         endfor;

         if middleware_completed = *on;
            for index = 1 to %elem(config.routes) by 1;
               if config.routes(index).url = *blanks;
                  leave;
               endif;

               if RPGAPI_routeMatches(config.routes(index) : request);
                  RPGAPI_callback_ptr = config.routes(index).procedure;
                  response = RPGAPI_callback(request);
                  route_found = *on;
                  leave;
               endif;
            endfor;

            if not route_found;
               response = RPGAPI_setResponse(request :  HTTP_NOT_FOUND);
            endif;
         endif;

         RPGAPI_sendResponse(config : response);
      on-error;
            // answer with a 500 and close the client socket, so the client
            // is not left waiting and the descriptor is not leaked
         monitor;
            response = RPGAPI_setResponse(request :  HTTP_INTERNAL_SERVER);
            RPGAPI_sendResponse(config : response);
         on-error;
            close_port( config.return_socket_descriptor );
         endmon;
      endmon;
   enddo;

   RPGAPI_stop(config);
end-proc;



dcl-proc RPGAPI_stop export;
   dcl-pi *n;
      config likeds(RPGAPI_App) const;
   end-pi;

   close_port( config.return_socket_descriptor );
   close_port( config.socket_descriptor );
end-proc;



   // waits for the next connection and accepts it into
   // config.return_socket_descriptor. A worker job passes the process ID of
   // the main job, and gets *off once that job has ended
dcl-proc RPGAPI_acceptConnection;
   dcl-pi *n ind;
      config likeds(RPGAPI_App);
      main_job_pid int(10:0) const;
   end-pi;
   dcl-ds poll_fds likeds(PollFd) dim(1);
   dcl-s descriptor int(10:0);
   dcl-s flags int(10:0);

   dow *on;
      if main_job_pid > 0 and kill(main_job_pid : 0) < 0;
         return *off;
      endif;

      poll_fds(1).fd = config.socket_descriptor;
      poll_fds(1).events = POLLIN;
      poll_fds(1).revents = 0;
      if poll(poll_fds : 1 : RPGAPI_WORKER_CHECK_MS) <= 0;
         iter;
      endif;

         // fails with EWOULDBLOCK when another job accepted it first
      descriptor = accept( config.socket_descriptor : *null : *null );
      if descriptor < 0;
         iter;
      endif;

         // the connection inherits non-blocking from the listening socket;
         // a response has to be written whole, so make it blocking again
      flags = fcntl( descriptor : F_GETFL );
      if flags >= 0 and %bitand(flags : O_NONBLOCK) <> 0;
         fcntl( descriptor : F_SETFL : flags - O_NONBLOCK );
      endif;

      config.return_socket_descriptor = descriptor;
      return *on;
   enddo;
end-proc;


   // starts count worker jobs running the program this job was started with.
   // Each inherits the listening socket as descriptor 0 and finds it through
   // RPGAPI_WORKER_VAR, registers its routes, and serves the same port
dcl-proc RPGAPI_startWorkers;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      count int(10:0) const;
   end-pi;
   dcl-s path varchar(64);
   dcl-s path_z char(65);
   dcl-s variable_z char(32);
   dcl-s fd_map int(10:0) dim(1);
   dcl-ds inherit likeds(RPGAPI_inheritance_t) inz(*likeds);
   dcl-s argv pointer dim(2);
   dcl-s envp pointer dim(2);
   dcl-s index int(10:0);
   dcl-s error_number int(10:0) based(error_number_ptr);
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   path = RPGAPI_jobProgram();
   path_z = path + x'00';
   variable_z = RPGAPI_WORKER_VAR + '=0' + x'00';
   fd_map(1) = config.socket_descriptor;
   inherit.flags = SPAWN_SETJOBNAMEPARENT_NP;
   argv(1) = %addr(path_z);
   argv(2) = *null;
   envp(1) = %addr(variable_z);
   envp(2) = *null;

   for index = 1 to count;
      if spawn(%addr(path_z) : 1 : fd_map : inherit : argv : envp) < 0;
         error_number_ptr = get_errno();
         error_text = 'Starting worker job ' + %char(index) + ' of ' +
                      %char(count) + ' (' + path + ') failed: ' +
                      %str(strerror(error_number)) +
                      ' (errno ' + %char(error_number) + ')';
         send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                               %len(error_text) : '*ESCAPE' : '*' : 1 :
                               message_key : error_code );
      endif;
   endfor;
end-proc;


   // the IFS path of the program this job was started with: the oldest entry
   // on the call stack outside QSYS, e.g. MYAPP for SBMJOB CMD(CALL MYAPP)
dcl-proc RPGAPI_jobProgram;
   dcl-pi *n varchar(64);
   end-pi;
   dcl-ds stack len(65535) qualified;
      bytes_returned int(10:0) pos(1);
      entry_count int(10:0) pos(17);
      entry_offset int(10:0) pos(13);
   end-ds;
   dcl-ds entry qualified based(entry_ptr);
      length int(10:0) pos(1);
      program char(10) pos(25);
      library char(10) pos(35);
   end-ds;
   dcl-ds job_id len(56) qualified;
      name char(10) pos(1) inz('*');
      user char(10) pos(11) inz(*blanks);
      number char(6) pos(21) inz(*blanks);
      internal_id char(16) pos(27) inz(*blanks);
      reserved char(2) pos(43) inz(*allx'00');
      thread_indicator int(10:0) pos(45) inz(1);
      thread_id char(8) pos(49) inz(*allx'00');
   end-ds;
   dcl-s error_code char(8) inz(*allx'00');
   dcl-s index int(10:0);
   dcl-s program char(10);
   dcl-s library char(10);

   retrieve_call_stack(stack : %size(stack) : 'CSTK0100' :
                       job_id : 'JIDF0100' : error_code);

      // entries run from the most recent call to the oldest
   entry_ptr = %addr(stack) + stack.entry_offset;
   for index = 1 to stack.entry_count;
      if entry.library <> 'QSYS';
         program = entry.program;
         library = entry.library;
      endif;
      entry_ptr += entry.length;
   endfor;

   return '/QSYS.LIB/' + %trim(library) + '.LIB/' + %trim(program) + '.PGM';
end-proc;


dcl-proc RPGAPI_acceptRequest export;
   dcl-pi *n likeds(RPGAPI_Request);
      config likeds(RPGAPI_App);
   end-pi;
      // RPGAPI_parse takes at most 32000 bytes, so that is all that is read
   dcl-s data char(32000);
   dcl-s return_code int(10:0) inz(0);
   dcl-s received int(10:0) inz(0);
   dcl-s header_end int(10:0) inz(0);
   dcl-s expected int(10:0) inz(0);
   dcl-ds request likeds(RPGAPI_Request);
   dcl-s text varchar(32000);
   dcl-ds poll_fds likeds(PollFd) dim(1);
   dcl-s deadline timestamp;
   dcl-s wait_ms int(20:0);

      // a request can arrive in several pieces: read until the blank line
      // after the headers, then until Content-Length bytes of body are in.
      // Stop early if the client closes the connection or the buffer is full,
      // and give up if the whole request takes longer than the timeout
   deadline = %timestamp() + %seconds(RPGAPI_READ_TIMEOUT);
   dow received < %size(data);
         // *mseconds are microseconds; poll wants milliseconds
      wait_ms = %diff(deadline : %timestamp() : *mseconds) / 1000;
      if wait_ms <= 0;
         clear request;
         return request;
      endif;

      poll_fds(1).fd = config.return_socket_descriptor;
      poll_fds(1).events = POLLIN;
      poll_fds(1).revents = 0;
      return_code = poll(poll_fds : 1 : wait_ms);
      if return_code = 0;
         clear request;
         return request;
      elseif return_code < 0;
         leave;
      endif;

      return_code = read( config.return_socket_descriptor :
                                   %addr(data) + received :
                                   %size(data) - received );
      if return_code <= 0;
         leave;
      endif;
      received += return_code;

      if header_end = 0;
            // the request is still ASCII here: CR LF CR LF. header_end is
            // where it starts, so the headers are the bytes before it
         header_end = %scan(x'0d0a0d0a' : %subst(data : 1 : received));
         if header_end > 0;
            expected = header_end + 3 +
                       RPGAPI_contentLength(%subst(data : 1 : header_end - 1));
         endif;
      endif;

      if header_end > 0 and received >= expected;
         leave;
      endif;
   enddo;

      // the headers never all arrived: the client closed, the read failed
      // or they do not fit in the buffer
   if header_end = 0;
      clear request;
      return request;
   endif;

   text = RPGAPI_convert(%subst(data : 1 : received) :
                         RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
   return RPGAPI_parse(text);
end-proc;


   // the Content-Length of a request from its headers, still in ASCII.
   // 0 when there is none or it is not a valid number
dcl-proc RPGAPI_contentLength;
   dcl-pi *n int(10:0);
      ascii_headers varchar(32000) const;
   end-pi;
   dcl-s headers varchar(32000);
   dcl-s length int(10:0) inz(0);
   dcl-s start int(10:0);
   dcl-s stop int(10:0);
   dcl-c NAME 'CONTENT-LENGTH:';

   headers = %upper(RPGAPI_convert(ascii_headers :
                                   RPGAPI_UTF8 : RPGAPI_JOB_CCSID));

      // headers start after the request line, each after a CRLF
   start = %scan(RPGAPI_CRLF + NAME : headers);
   if start = 0;
      return 0;
   endif;
   start += %len(RPGAPI_CRLF) + %len(NAME);
   stop = %scan(RPGAPI_CRLF : headers : start);
   if stop = 0;
      stop = %len(headers) + 1;
   endif;

   monitor;
      length = %int(%subst(headers : start : stop - start));
   on-error;
      length = 0;
   endmon;

   if length < 0;
      length = 0;
   endif;
   return length;
end-proc;



dcl-proc RPGAPI_parse export;
   dcl-pi *n likeds(RPGAPI_Request);
      raw_request varchar(32000) const;
   end-pi;
   dcl-ds request likeds(RPGAPI_Request);
   dcl-s line char(1024);
   dcl-s start int(10:0);
   dcl-s stop int(10:0);
   dcl-s position int(10:0);
   dcl-s raw_headers char(32000);
   dcl-s parts char(1024) dim(50);
   dcl-s index int(10:0);

   clear request;
   position = %scan(RPGAPI_CRLF : raw_request);
   start = 1;
   stop = position;
   line = %subst(raw_request:start:stop);

   parts = %split(line : ' ');
   request.method = %trim(parts(1));   
   request.route = %trim(parts(2));
   request.protocol = %trim(parts(3));

   start = 0;
   start = %scan('?' : request.route);

   if start > 0;
      request.query_string =
                    RPGAPI_cleanString(%subst(request.route : start + 1));
      request.route = %subst(request.route : 1 : start - 1);
   endif;

   parts = %split(request.query_string : '&');
   for index = 1 to %elem(parts) by 1;
      if parts(index) <> *blanks;
            // split on the first '=' only, a value may contain more of them
         position = %scan('=' : parts(index));
         if position = 0;
            request.query_params(index).name = parts(index);
         else;
            request.query_params(index).name =
                                    %subst(parts(index) : 1 : position - 1);
            if position < %len(parts(index));
               request.query_params(index).value =
                                    %trim(%subst(parts(index) : position + 1));
            endif;
         endif;
      else;
         index = %elem(parts) + 1;
      endif;
   endfor;

   start = stop + 1;
   stop = %scan(RPGAPI_DBL_CRLF : raw_request);
   raw_headers = %subst(raw_request : start : stop - start);
   parts = %split(raw_headers : RPGAPI_CRLF);

   for index = 1 to %elem(parts) by 1;
      if parts(index) <> *blanks;
            // split on the first ':' only, a value such as host:port may
            // contain more of them
         position = %scan(':' : parts(index));
         if position = 0;
            request.headers(index).name = parts(index);
         else;
            request.headers(index).name =
                                    %subst(parts(index) : 1 : position - 1);
            if position < %len(parts(index));
               request.headers(index).value =
                                    %trim(%subst(parts(index) : position + 1));
            endif;
         endif;
      else;
         index = %elem(parts) + 1;
      endif;
   endfor;

      // the body is everything after the blank line, exactly as sent
   start = stop + %len(RPGAPI_DBL_CRLF);
   if start <= %len(raw_request);
      request.body = %subst(raw_request : start);
   endif;

   return request;
end-proc;
        


dcl-proc RPGAPI_getParam export;
   dcl-pi *n varchar(1024);
      request likeds(RPGAPI_Request) const;
      param char(50) const;
   end-pi;
   dcl-s param_value varchar(1024);
   dcl-s index int(10:0);

   clear param_value;
   for index = 1 to %elem(request.params) by 1;
      if %upper(request.params(index).name) =
                %upper(param);
         param_value = request.params(index).value;
         index = %elem(request.params) + 1;
      endif;
   endfor;

   return %trim(param_value);
end-proc;


dcl-proc RPGAPI_getQueryParam export;
   dcl-pi *n varchar(1024);
      request likeds(RPGAPI_Request) const;
      param char(50) const;
   end-pi;
   dcl-s param_value varchar(1024);
   dcl-s index int(10:0);

   clear param_value;
   for index = 1 to %elem(request.query_params) by 1;
      if %upper(request.query_params(index).name) =
                %upper(param);
         param_value = request.query_params(index).value;
         index = %elem(request.query_params) + 1;
      endif;
   endfor;

   return %trim(param_value);
end-proc;


dcl-proc RPGAPI_getHeader export;
   dcl-pi *n varchar(1024);
      request likeds(RPGAPI_Request) const;
      header char(50) const;
   end-pi;
   dcl-s header_value varchar(1024);
   dcl-s index int(10:0);

   clear header_value;
   for index = 1 to %elem(request.headers) by 1;
      if %upper(request.headers(index).name) =
                %upper(header);
         header_value = request.headers(index).value;
         index = %elem(request.headers) + 1;
      endif;
   endfor;

   return %trim(header_value);
end-proc;



dcl-proc RPGAPI_setHeader export;
   dcl-pi *n;
      response likeds(RPGAPI_Response);
      header_name char(50) const;
      header_value varchar(1024) const;
   end-pi;
   dcl-s index int(10:0) inz;

   for index = 1 to %elem(response.headers) by 1;
      if response.headers(index).name = *blanks;
         response.headers(index).name = header_name;
         response.headers(index).value = header_value;
         index = %elem(response.headers) + 1;
      endif;
   endfor;
end-proc;



dcl-proc RPGAPI_routeMatches export;
   dcl-pi *n ind;
      route likeds(RPGAPI_route_ds);
      request likeds(RPGAPI_Request);
   end-pi;

   if request.method <> route.method;
      clear request.params;
      return *off;
   endif;

   return RPGAPI_pathMatches(route.url : request.route : *off :
                             request.params);
end-proc;


dcl-proc RPGAPI_mwMatches export;
   dcl-pi *n ind;
      route likeds(RPGAPI_route_ds);
      request likeds(RPGAPI_Request);
   end-pi;

            // allowing middlewares for all routes
   if %trim(route.url) = RPGAPI_GLOBAL_MIDDLEWARE;
      clear request.params;
      return *on;
   endif;

   return RPGAPI_pathMatches(route.url : request.route : *on :
                             request.params);
end-proc;


   // compares a route pattern with a request path one '/' segment at a time.
   // A '{name}' segment matches any segment and captures it as param 'name',
   // '*' matches any segment. With prefix on, the pattern only has to match
   // the leading segments of the path, so '/api' also matches '/api/users'.
   // params gets the captured values on a match and is cleared otherwise
dcl-proc RPGAPI_pathMatches;
   dcl-pi *n ind;
      pattern varchar(32000) const;
      path varchar(32000) const;
      prefix ind const;
      params likeds(RPGAPI_param_ds) dim(100);
   end-pi;
   dcl-s pattern_parts varchar(1024) dim(100);
   dcl-s path_parts varchar(1024) dim(100);
   dcl-s pattern_count int(10:0);
   dcl-s path_count int(10:0);
   dcl-s index int(10:0);
   dcl-s param_count int(10:0) inz;
   dcl-s part varchar(1024);
   dcl-ds found likeds(RPGAPI_param_ds) dim(100) inz;

   clear params;

      // %split drops empty segments, so '/api/users/' is '/api/users'
      // and '/' has no segments at all
   pattern_parts = %split(%trim(pattern) : '/');
   path_parts = %split(%trim(path) : '/');
   pattern_count = %lookup('' : pattern_parts) - 1;
   if pattern_count < 0;
      pattern_count = %elem(pattern_parts);
   endif;
   path_count = %lookup('' : path_parts) - 1;
   if path_count < 0;
      path_count = %elem(path_parts);
   endif;

   if path_count < pattern_count or
      (not prefix and path_count <> pattern_count);
      return *off;
   endif;

   for index = 1 to pattern_count;
      part = pattern_parts(index);

      if %len(part) > 2 and %subst(part : 1 : 1) = '{' and
         %subst(part : %len(part) : 1) = '}';
         if param_count < %elem(found);
            param_count += 1;
            found(param_count).name = %subst(part : 2 : %len(part) - 2);
            found(param_count).value = path_parts(index);
         endif;
      elseif part <> '*' and part <> path_parts(index);
         return *off;
      endif;
   endfor;

   params = found;
   return *on;
end-proc;


dcl-proc RPGAPI_sendResponse export;
   dcl-pi *n;
      config likeds(RPGAPI_App) const;
      response likeds(RPGAPI_Response) const;
   end-pi;
   dcl-s return_code int(10:0) inz(0);
   dcl-s head varchar(96000);
   dcl-s utf8_body varchar(96000);

      // Content-Length counts UTF-8 bytes, which is more than the length in
      // EBCDIC for any character outside ASCII, so convert the body first
   utf8_body = RPGAPI_convert(%trim(response.body) :
                              RPGAPI_JOB_CCSID : RPGAPI_UTF8);
   head = RPGAPI_convert(RPGAPI_buildHead(response : %len(utf8_body)) :
                         RPGAPI_JOB_CCSID : RPGAPI_UTF8);

   return_code = write( config.return_socket_descriptor :
                                %addr(head : *data) :
                                %len(head) );
   if %len(utf8_body) > 0;
      return_code = write( config.return_socket_descriptor :
                                   %addr(utf8_body : *data) :
                                   %len(utf8_body) );
   endif;
   close_port( config.return_socket_descriptor );
end-proc;


   // the status line and headers of a response, up to and including the blank
   // line before the body, in the job's CCSID. body_length is the size of the
   // body as it is sent, for Content-Length
dcl-proc RPGAPI_buildHead export;
   dcl-pi *n varchar(32766);
      response likeds(RPGAPI_Response) const;
      body_length int(10:0) const;
   end-pi;
   dcl-s head varchar(32766);
   dcl-s index int(10:0);

   head = 'HTTP/1.1 ' + %char(response.status) + ' ' +
          %trim(RPGAPI_getMessage(response.status)) + RPGAPI_CRLF +
          'Connection: close' + RPGAPI_CRLF;

   for index = 1 to %elem(response.headers) by 1;
      if response.headers(index).name = *blanks;
         leave;
      endif;

         // the connection is always closed after the response, and the
         // Connection header saying so is sent above
      if %upper(%trim(response.headers(index).name)) = 'CONNECTION';
         iter;
      endif;

      head += %trim(response.headers(index).name) + ': ' +
              %trim(response.headers(index).value) + RPGAPI_CRLF;
   endfor;

      // the CRLF that ends this header plus one more make the blank line
   head += 'Content-Length: ' + %char(body_length) + RPGAPI_DBL_CRLF;
   return head;
end-proc;


dcl-proc RPGAPI_initHttp export;
   HTTP_messages(1).status = HTTP_OK;
   HTTP_messages(1).text = 'OK';
   HTTP_messages(2).status = HTTP_CREATED;
   HTTP_messages(2).text = 'Created';
   HTTP_messages(3).status = HTTP_BAD_REQUEST;
   HTTP_messages(3).text = 'Bad Request';
   HTTP_messages(4).status = HTTP_UNAUTHORIZED;
   HTTP_messages(4).text = 'Unauthorized';
   HTTP_messages(5).status = HTTP_NOT_FOUND;
   HTTP_messages(5).text = 'Not Found';
   HTTP_messages(6).status = HTTP_INTERNAL_SERVER;
   HTTP_messages(6).text = 'Internal Server Error';
   HTTP_messages(7).status = HTTP_NO_CONTENT;
   HTTP_messages(7).text = 'No Content';
   HTTP_messages(8).status = HTTP_MOVED_PERMANENTLY;
   HTTP_messages(8).text = 'Moved Permanently';
   HTTP_messages(9).status = HTTP_FOUND;
   HTTP_messages(9).text = 'Found';
   HTTP_messages(10).status = HTTP_FORBIDDEN;
   HTTP_messages(10).text = 'Forbidden';
   HTTP_messages(11).status = HTTP_ACCEPTED;
   HTTP_messages(11).text = 'Accepted';
end-proc;


dcl-proc RPGAPI_setup;
   dcl-pi *n;
      config likeds(RPGAPI_App);
   end-pi;
   dcl-s return_code int(10:0) inz(0);
   dcl-ds socket_address likeds(socketaddr);
      // 1 turns SO_REUSEADDR on, so a restart can bind the port while
      // connections from the previous run are still in TIME_WAIT
   dcl-s reuse_address int(10:0) inz(1);

   RPGAPI_initHttp();

   config.socket_descriptor = socket(AF_INET : SOCK_STREAM : 0);
   if config.socket_descriptor < 0;
      RPGAPI_socketFailed(config : 'socket');
   endif;

   return_code = set_socket_options( config.socket_descriptor :
                                              SOL_SOCKET :
                                              SO_REUSEADDR :
                                              %addr(reuse_address) :
                                              %size(reuse_address) );
   if return_code < 0;
      RPGAPI_socketFailed(config : 'setsockopt');
   endif;

   clear socket_address;
   socket_address.sin_family = AF_INET;
   socket_address.sin_port = config.port;
   socket_address.sin_addr = INADDR_ANY;
   return_code = bind( config.socket_descriptor :
                                %addr(socket_address) :
                                %size(socket_address) );
   if return_code < 0;
      RPGAPI_socketFailed(config : 'bind');
   endif;

      // connections that arrive while one is being handled wait in this
      // queue; with room for only 1, the rest were refused
   return_code = listen( config.socket_descriptor : SOMAXCONN );
   if return_code < 0;
      RPGAPI_socketFailed(config : 'listen');
   endif;

      // worker jobs share this socket, and all of them may wake up for one
      // connection. Non-blocking, accept() then fails for those that lose it
      // instead of leaving them stuck until the next connection
   return_code = fcntl( config.socket_descriptor : F_GETFL );
   if return_code >= 0;
      return_code = fcntl( config.socket_descriptor : F_SETFL :
                           %bitor(return_code : O_NONBLOCK) );
   endif;
   if return_code < 0;
      RPGAPI_socketFailed(config : 'fcntl');
   endif;
end-proc;


   // closes the listening socket and ends the server with an escape message
   // naming the call that failed and why, e.g. when the port is already in use
dcl-proc RPGAPI_socketFailed;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      call_name varchar(20) const;
   end-pi;
   dcl-s error_number int(10:0) based(error_number_ptr);
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   error_number_ptr = get_errno();
   error_text = call_name + '() failed for port ' + %char(config.port) +
                ': ' + %str(strerror(error_number)) +
                ' (errno ' + %char(error_number) + ')';

   if config.socket_descriptor >= 0;
      close_port( config.socket_descriptor );
   endif;

      // counter 2 sends it past RPGAPI_setup to the procedure that called it
   send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                         %len(error_text) : '*ESCAPE' : '*' : 2 :
                         message_key : error_code );
end-proc;


   // converts text between two CCSIDs, e.g. RPGAPI_UTF8 and RPGAPI_JOB_CCSID
   // (0, the job's CCSID).
   // Ends with an escape message naming the CCSIDs if that is not possible
dcl-proc RPGAPI_convert;
   dcl-pi *n varchar(96000);
      text varchar(32766) const;
      from_ccsid int(10:0) const;
      to_ccsid int(10:0) const;
   end-pi;
   dcl-ds from_code likeds(RPGAPI_QtqCode_T) inz(*likeds);
   dcl-ds to_code likeds(RPGAPI_QtqCode_T) inz(*likeds);
   dcl-ds converter likeds(RPGAPI_iconv_t);
      // UTF-8 takes up to 3 bytes for a character that is 1 in EBCDIC
   dcl-s input varchar(32766);
   dcl-s output char(96000);
   dcl-s input_ptr pointer;
   dcl-s output_ptr pointer;
   dcl-s input_left uns(10:0);
   dcl-s output_left uns(10:0);
   dcl-s return_code int(10:0);
   dcl-s call_name varchar(20);
   dcl-s error_number int(10:0) based(error_number_ptr);
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   if %len(text) = 0;
      return '';
   endif;

   from_code.ccsid = from_ccsid;
   to_code.ccsid = to_ccsid;
   converter = iconv_open(to_code : from_code);
   if converter.return_value = -1;
      return_code = -1;
      call_name = 'QtqIconvOpen';
   else;
      call_name = 'iconv';
      input = text;
      input_ptr = %addr(input : *data);
      input_left = %len(input);
      output_ptr = %addr(output);
      output_left = %size(output);
      return_code = iconv(converter : %addr(input_ptr) : %addr(input_left) :
                          %addr(output_ptr) : %addr(output_left));
      iconv_close(converter);
   endif;

   if return_code = -1;
      error_number_ptr = get_errno();
      error_text = 'Converting from CCSID ' + %char(from_ccsid) + ' to ' +
                   %char(to_ccsid) + ' failed in ' + call_name + ': ' +
                   %str(strerror(error_number)) +
                   ' (errno ' + %char(error_number) + ')';
      send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                            %len(error_text) : '*ESCAPE' : '*' : 1 :
                            message_key : error_code );
   endif;

   return %subst(output : 1 : %size(output) - output_left);
end-proc;



dcl-proc RPGAPI_setRoute export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      method char(10) const;
      url varchar(32000) const;
      procedure pointer(*proc) const;
   end-pi;
   dcl-s index int(10:0) inz;

   for index = 1 to %elem(config.routes) by 1;
      if config.routes(index).url = *blanks;
         config.routes(index).method = method;
         config.routes(index).url = url;
         config.routes(index).procedure = procedure;
         index = %elem(config.routes) + 1;
      endif;
   endfor;
end-proc;


dcl-proc RPGAPI_setMiddleware export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      url varchar(32000) const;
      procedure pointer(*proc) const;
   end-pi;
   dcl-s index int(10:0) inz;

   for index = 1 to %elem(config.middlewares) by 1;
      if config.middlewares(index).url = *blanks;
         config.middlewares(index).url = url;
         config.middlewares(index).procedure = procedure;
         index = %elem(config.middlewares) + 1;
      endif;
   endfor;
end-proc;


dcl-proc RPGAPI_get export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      url varchar(32000) const;
      procedure pointer(*proc) const;
   end-pi;

   RPGAPI_setRoute(config: HTTP_GET : url : procedure);
end-proc;



dcl-proc RPGAPI_put export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      url varchar(32000) const;
      procedure pointer(*proc) const;
   end-pi;

   RPGAPI_setRoute(config: HTTP_PUT : url : procedure);
end-proc;



dcl-proc RPGAPI_post export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      url varchar(32000) const;
      procedure pointer(*proc) const;
   end-pi;

   RPGAPI_setRoute(config: HTTP_POST : url : procedure);
end-proc;



dcl-proc RPGAPI_delete export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      url varchar(32000) const;
      procedure pointer(*proc) const;
   end-pi;

   RPGAPI_setRoute(config: HTTP_DELETE : url : procedure);
end-proc;


dcl-proc RPGAPI_patch export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      url varchar(32000) const;
      procedure pointer(*proc) const;
   end-pi;

   RPGAPI_setRoute(config: HTTP_PATCH : url : procedure);
end-proc;



dcl-proc RPGAPI_setResponse export;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request);
      status zoned(3:0) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   clear response;
   response.status = status;

   return response;
end-proc;



dcl-proc RPGAPI_cleanString export;
   dcl-pi *n varchar(32000);
      dirty_string varchar(32000) const;
   end-pi;
   dcl-s cleaned_string varchar(32000);

   cleaned_string =
              %trim(%scanrpl(RPGAPI_CR : '' : 
                        %scanrpl(RPGAPI_LF : '' : dirty_string)));
   return cleaned_string;
end-proc;



dcl-proc RPGAPI_getMessage export;
   dcl-pi *n char(25);
      status zoned(3:0) const;
   end-pi;
   dcl-s index int(10:0);
   dcl-s message char(25) inz;

   for index = 1 to %elem(HTTP_messages) by 1;
      if HTTP_messages(index).status = status;
         message = HTTP_messages(index).text;
         index = %elem(HTTP_messages) + 1;
      endif;
   endfor;

   return %trim(message);
end-proc;