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
   // seconds a client may take no response data before it is given up on,
   // so a client that stops reading does not hold its job
dcl-c RPGAPI_WRITE_TIMEOUT 30;

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

   // the request being read. One job handles one connection at a time, so
   // this is kept here rather than in RPGAPI_Request, whose layout apps use
dcl-s RPGAPI_max_request_size int(10:0) inz(1048576);
   // raw bytes read from the connection and not used yet, still ASCII/UTF-8
dcl-s RPGAPI_input char(32000);
dcl-s RPGAPI_input_start int(10:0);
dcl-s RPGAPI_input_end int(10:0);
dcl-s RPGAPI_input_deadline timestamp;
   // the request body, as sent, on the heap
dcl-s RPGAPI_body_ptr pointer inz(*null);
dcl-s RPGAPI_body_capacity int(10:0) inz(0);
dcl-s RPGAPI_body_length int(10:0) inz(0);
dcl-s RPGAPI_body_position int(10:0) inz(0);
dcl-s RPGAPI_body_bytes char(16000000) based(RPGAPI_body_ptr);
   // the status to answer with when a request is refused before routing
dcl-s RPGAPI_reject_status int(10:0) inz(0);
   // the most setMaxRequestSize allows: what %alloc can hand out in one piece
dcl-c RPGAPI_MAX_BODY_LIMIT 16000000;

   // the connection being answered, for the procedures that stream a
   // response, and the protocol of its request (HTTP/1.0 has no chunking)
dcl-s RPGAPI_connection int(10:0) inz(-1);
   // set once writing to the connection failed or timed out: later writes
   // do nothing, so a procedure writing rows can still finish normally
dcl-s RPGAPI_connection_failed ind inz(*off);
dcl-s RPGAPI_request_protocol char(8);
   // a streamed response: RPGAPI_STREAM_... how its body is framed, and body
   // bytes waiting to be sent, already UTF-8 or raw
dcl-s RPGAPI_stream int(10:0) inz(0);
dcl-c RPGAPI_STREAM_NONE 0;
dcl-c RPGAPI_STREAM_CHUNKED 1;
dcl-c RPGAPI_STREAM_LENGTH 2;
dcl-c RPGAPI_STREAM_UNTIL_CLOSE 3;
dcl-c RPGAPI_STREAM_ENDED 9;
dcl-s RPGAPI_output char(32768);
dcl-s RPGAPI_output_length int(10:0) inz(0);
   // body_length values for RPGAPI_buildHead that are not a Content-Length
dcl-c RPGAPI_CHUNKED -1;
dcl-c RPGAPI_UNTIL_CLOSE -2;
   // open converters, kept for the job: opening one for every piece of a
   // streamed response would be slow
dcl-ds RPGAPI_converters qualified dim(4);
   from_ccsid int(10:0);
   to_ccsid int(10:0);
   in_use ind;
   cd char(52);
end-ds;

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

            // refused (413, 431, ...): answer with that status. Otherwise no
            // complete request arrived in time, and there is nothing to answer
         if request.method = *blanks;
            if RPGAPI_reject_status > 0;
               response = RPGAPI_setResponse(request : RPGAPI_reject_status);
               RPGAPI_sendResponse(config : response);
            else;
               close_port( config.return_socket_descriptor );
            endif;
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

            // a procedure that streamed its response has sent it already
         if RPGAPI_stream = RPGAPI_STREAM_NONE;
            RPGAPI_sendResponse(config : response);
         else;
            RPGAPI_endResponse();
         endif;
      on-error;
            // answer with a 500 and close the client socket, so the client
            // is not left waiting and the descriptor is not leaked. Once a
            // streamed response has begun, closing is all that is left
         monitor;
            if RPGAPI_stream = RPGAPI_STREAM_NONE;
               response = RPGAPI_setResponse(request :  HTTP_INTERNAL_SERVER);
               RPGAPI_sendResponse(config : response);
            else;
               RPGAPI_stream = RPGAPI_STREAM_ENDED;
               close_port( config.return_socket_descriptor );
            endif;
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

         // the connection inherits non-blocking from the listening socket,
         // and stays that way: reads and writes wait with poll, which can
         // time out, instead of blocking in read() or write()
      config.return_socket_descriptor = descriptor;
      RPGAPI_connection = descriptor;
      RPGAPI_connection_failed = *off;
      RPGAPI_stream = RPGAPI_STREAM_NONE;
      RPGAPI_output_length = 0;
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
   dcl-ds request likeds(RPGAPI_Request);
   dcl-ds refused likeds(RPGAPI_Request);
   dcl-s header_end int(10:0) inz(0);
   dcl-s headers varchar(32000);
   dcl-s transfer_encoding varchar(1024);
   dcl-s content_length varchar(1024);
   dcl-s length int(10:0) inz(0);
   dcl-s chunked ind inz(*off);
   dcl-s continue_text varchar(40);
   dcl-s continue_utf8 varchar(120);

   clear refused;
   RPGAPI_reject_status = 0;
   RPGAPI_input_start = 1;
   RPGAPI_input_end = 0;
   RPGAPI_body_length = 0;
   RPGAPI_body_position = 0;

      // the whole request has to arrive within the timeout. Read until the
      // blank line after the headers; they have to fit in RPGAPI_input
   RPGAPI_input_deadline = %timestamp() + %seconds(RPGAPI_READ_TIMEOUT);
   dou header_end > 0;
      if RPGAPI_input_end = %size(RPGAPI_input);
         RPGAPI_reject_status = HTTP_HEADERS_TOO_LARGE;
         return refused;
      endif;
      if RPGAPI_fillInput(config) <= 0;
         return refused;
      endif;
         // still ASCII here: CR LF CR LF
      header_end = %scan(x'0d0a0d0a' : %subst(RPGAPI_input : 1 : RPGAPI_input_end));
   enddo;

   request = RPGAPI_parse(RPGAPI_convert(%subst(RPGAPI_input : 1 : header_end + 3) :
                                         RPGAPI_UTF8 : RPGAPI_JOB_CCSID));
   RPGAPI_input_start = header_end + 4;
   RPGAPI_request_protocol = request.protocol;
   headers = %upper(RPGAPI_convert(%subst(RPGAPI_input : 1 : header_end - 1) :
                                   RPGAPI_UTF8 : RPGAPI_JOB_CCSID));

      // the body is either chunked or Content-Length bytes long
   transfer_encoding = RPGAPI_headerValue(headers : 'TRANSFER-ENCODING');
   content_length = RPGAPI_headerValue(headers : 'CONTENT-LENGTH');
   if transfer_encoding <> '';
      if transfer_encoding <> 'CHUNKED';
         RPGAPI_reject_status = HTTP_NOT_IMPLEMENTED;
         return refused;
      endif;
      chunked = *on;
   elseif content_length <> '';
      monitor;
         length = %int(content_length);
      on-error;
         length = -1;
      endmon;
      if length < 0;
         RPGAPI_reject_status = HTTP_BAD_REQUEST;
         return refused;
      endif;
         // refuse before reading it, or before the client even sends it
      if length > RPGAPI_max_request_size;
         RPGAPI_reject_status = HTTP_CONTENT_TOO_LARGE;
         return refused;
      endif;
   endif;

      // a client that sent Expect: 100-continue waits for this before
      // sending the body
   if RPGAPI_headerValue(headers : 'EXPECT') = '100-CONTINUE' and
      (chunked or length > 0) and RPGAPI_input_start > RPGAPI_input_end;
      continue_text = 'HTTP/1.1 100 Continue' + RPGAPI_DBL_CRLF;
      continue_utf8 = RPGAPI_convert(continue_text :
                                     RPGAPI_JOB_CCSID : RPGAPI_UTF8);
      RPGAPI_sendAll(%addr(continue_utf8 : *data) : %len(continue_utf8));
   endif;

   if chunked;
      if not RPGAPI_readChunkedBody(config);
         return refused;
      endif;
   elseif length > 0;
      if not RPGAPI_readInputToBody(config : length);
         return refused;
      endif;
   endif;

      // a body that fits is also handed over in request.body (a varchar,
      // so its size includes a 2-byte length)
   if RPGAPI_body_length > 0 and
      RPGAPI_body_length <= %size(request.body) - 2;
      request.body = RPGAPI_convert(%subst(RPGAPI_body_bytes : 1 :
                                           RPGAPI_body_length) :
                                    RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
   endif;
   return request;
end-proc;


   // reads more of the request into RPGAPI_input, waiting until the deadline.
   // Returns how many bytes arrived: 0 when the client closed, -1 on timeout
   // or error
dcl-proc RPGAPI_fillInput;
   dcl-pi *n int(10:0);
      config likeds(RPGAPI_App);
   end-pi;
   dcl-ds poll_fds likeds(PollFd) dim(1);
   dcl-s wait_ms int(20:0);
   dcl-s count int(10:0);

      // move what is left to the front, to make room after it
   if RPGAPI_input_start > 1;
      count = RPGAPI_input_end - RPGAPI_input_start + 1;
      if count > 0;
         %subst(RPGAPI_input : 1 : count) =
            %subst(RPGAPI_input : RPGAPI_input_start : count);
      endif;
      RPGAPI_input_start = 1;
      RPGAPI_input_end = count;
   endif;

      // *mseconds are microseconds; poll wants milliseconds
   wait_ms = %diff(RPGAPI_input_deadline : %timestamp() : *mseconds) / 1000;
   if wait_ms <= 0;
      return -1;
   endif;
   poll_fds(1).fd = config.return_socket_descriptor;
   poll_fds(1).events = POLLIN;
   poll_fds(1).revents = 0;
   if poll(poll_fds : 1 : wait_ms) <= 0;
      return -1;
   endif;

   count = read( config.return_socket_descriptor :
                 %addr(RPGAPI_input) + RPGAPI_input_end :
                 %size(RPGAPI_input) - RPGAPI_input_end );
   if count < 0;
      return -1;
   endif;
   RPGAPI_input_end += count;
   return count;
end-proc;


   // moves count bytes of the request into the body, reading as needed.
   // *off when the client closed or the time ran out first
dcl-proc RPGAPI_readInputToBody;
   dcl-pi *n ind;
      config likeds(RPGAPI_App);
      count int(10:0) const;
   end-pi;
   dcl-s needed int(10:0);
   dcl-s available int(10:0);
   dcl-s capacity int(10:0);

   needed = RPGAPI_body_length + count;
   if needed > RPGAPI_body_capacity;
         // at least double, so a chunked body is not copied for every chunk
      capacity = %max(needed : RPGAPI_body_capacity * 2);
      capacity = %min(capacity : %max(needed : RPGAPI_max_request_size));
      if RPGAPI_body_ptr = *null;
         RPGAPI_body_ptr = %alloc(capacity);
      else;
         RPGAPI_body_ptr = %realloc(RPGAPI_body_ptr : capacity);
      endif;
      RPGAPI_body_capacity = capacity;
   endif;

   dow RPGAPI_body_length < needed;
      if RPGAPI_input_start > RPGAPI_input_end;
         if RPGAPI_fillInput(config) <= 0;
            return *off;
         endif;
      endif;
      available = %min(RPGAPI_input_end - RPGAPI_input_start + 1 :
                       needed - RPGAPI_body_length);
      %subst(RPGAPI_body_bytes : RPGAPI_body_length + 1 : available) =
         %subst(RPGAPI_input : RPGAPI_input_start : available);
      RPGAPI_body_length += available;
      RPGAPI_input_start += available;
   enddo;
   return *on;
end-proc;


   // reads one line of the request, up to CR LF, still ASCII. *off when the
   // client closed or the time ran out, and with a 400 when the line is too long
dcl-proc RPGAPI_readInputLine;
   dcl-pi *n ind;
      config likeds(RPGAPI_App);
      line varchar(1024);
   end-pi;
   dcl-s stop int(10:0) inz(0);
   dcl-c LINE_MAX 1024;

   dou stop > 0;
      if RPGAPI_input_start <= RPGAPI_input_end;
         stop = %scan(x'0d0a' : %subst(RPGAPI_input : 1 : RPGAPI_input_end) :
                      RPGAPI_input_start);
      endif;
      if stop = 0;
         if RPGAPI_input_end - RPGAPI_input_start + 1 > LINE_MAX;
            RPGAPI_reject_status = HTTP_BAD_REQUEST;
            return *off;
         endif;
         if RPGAPI_fillInput(config) <= 0;
            return *off;
         endif;
      endif;
   enddo;

   if stop - RPGAPI_input_start > LINE_MAX;
      RPGAPI_reject_status = HTTP_BAD_REQUEST;
      return *off;
   endif;
   line = %subst(RPGAPI_input : RPGAPI_input_start : stop - RPGAPI_input_start);
   RPGAPI_input_start = stop + 2;
   return *on;
end-proc;


   // reads a Transfer-Encoding: chunked body into the body buffer: chunks of
   // a hex size line, the data and CR LF, then a 0 size chunk and trailer
   // lines up to an empty one. Sets RPGAPI_reject_status when it is too large
   // or not valid. *off when the body could not be read
dcl-proc RPGAPI_readChunkedBody;
   dcl-pi *n ind;
      config likeds(RPGAPI_App);
   end-pi;
   dcl-s line varchar(1024);
   dcl-s size int(10:0);
   dcl-s index int(10:0);
   dcl-s digit int(10:0);
   dcl-s stop int(10:0);
   dcl-c HEX_DIGITS '0123456789ABCDEF';

   dow *on;
      if not RPGAPI_readInputLine(config : line);
         return *off;
      endif;

         // the size is hex, optionally followed by ;extensions. The line is
         // ASCII: letters and digits are converted to compare them
      line = %upper(RPGAPI_convert(line : RPGAPI_UTF8 : RPGAPI_JOB_CCSID));
      stop = %scan(';' : line);
      if stop > 0;
         line = %subst(line : 1 : stop - 1);
      endif;
      line = %trim(line);
      if line = '';
         RPGAPI_reject_status = HTTP_BAD_REQUEST;
         return *off;
      endif;

      size = 0;
      for index = 1 to %len(line);
         digit = %scan(%subst(line : index : 1) : HEX_DIGITS) - 1;
         if digit < 0;
            RPGAPI_reject_status = HTTP_BAD_REQUEST;
            return *off;
         endif;
         size = size * 16 + digit;
         if size > RPGAPI_max_request_size;
            RPGAPI_reject_status = HTTP_CONTENT_TOO_LARGE;
            return *off;
         endif;
      endfor;

      if size = 0;
         leave;
      endif;
      if RPGAPI_body_length + size > RPGAPI_max_request_size;
         RPGAPI_reject_status = HTTP_CONTENT_TOO_LARGE;
         return *off;
      endif;
      if not RPGAPI_readInputToBody(config : size);
         return *off;
      endif;

         // every chunk's data is followed by CR LF
      if not RPGAPI_readInputLine(config : line);
         return *off;
      endif;
      if line <> '';
         RPGAPI_reject_status = HTTP_BAD_REQUEST;
         return *off;
      endif;
   enddo;

      // trailer fields, ignored, up to the empty line that ends the request
   dou line = '';
      if not RPGAPI_readInputLine(config : line);
         return *off;
      endif;
   enddo;
   return *on;
end-proc;


   // the value of a header, from the headers of a request converted to the
   // job's CCSID and in upper case. '' when it is not there
dcl-proc RPGAPI_headerValue;
   dcl-pi *n varchar(1024);
      headers varchar(32000) const;
      name varchar(50) const;
   end-pi;
   dcl-s start int(10:0);
   dcl-s stop int(10:0);

      // headers start after the request line, each after a CRLF
   start = %scan(RPGAPI_CRLF + name + ':' : headers);
   if start = 0;
      return '';
   endif;
   start += %len(RPGAPI_CRLF) + %len(name) + 1;
   stop = %scan(RPGAPI_CRLF : headers : start);
   if stop = 0;
      stop = %len(headers) + 1;
   endif;
   return %trim(%subst(headers : start : stop - start));
end-proc;


dcl-proc RPGAPI_setMaxRequestSize export;
   dcl-pi *n;
      bytes int(10:0) const;
   end-pi;
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   if bytes < 0 or bytes > RPGAPI_MAX_BODY_LIMIT;
      error_text = 'RPGAPI_setMaxRequestSize: ' + %char(bytes) +
                   ' is not between 0 and ' + %char(RPGAPI_MAX_BODY_LIMIT);
      send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                            %len(error_text) : '*ESCAPE' : '*' : 1 :
                            message_key : error_code );
   endif;
   RPGAPI_max_request_size = bytes;
end-proc;


dcl-proc RPGAPI_bodyLength export;
   dcl-pi *n int(10:0);
      request likeds(RPGAPI_Request) const;
   end-pi;

   return RPGAPI_body_length;
end-proc;


dcl-proc RPGAPI_readBody export;
   dcl-pi *n varchar(32000);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s count int(10:0);
   dcl-s next_byte char(1);

      // at most 16000 bytes, so the text fits even if the job's CCSID needs
      // more bytes per character than UTF-8
   count = %min(16000 : RPGAPI_body_length - RPGAPI_body_position);
   if count <= 0;
      return '';
   endif;

      // do not split a UTF-8 character: while the next byte continues one
      // (10xxxxxx), end this piece before the character starts
   if RPGAPI_body_position + count < RPGAPI_body_length;
      dow count > 0;
         next_byte = %subst(RPGAPI_body_bytes :
                            RPGAPI_body_position + count + 1 : 1);
         if next_byte < x'80' or next_byte > x'BF';
            leave;
         endif;
         count -= 1;
      enddo;
      if count = 0;
         count = %min(16000 : RPGAPI_body_length - RPGAPI_body_position);
      endif;
   endif;

   RPGAPI_body_position += count;
   return RPGAPI_convert(%subst(RPGAPI_body_bytes :
                                RPGAPI_body_position - count + 1 : count) :
                         RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
end-proc;


dcl-proc RPGAPI_readBodyBytes export;
   dcl-pi *n int(10:0);
      request likeds(RPGAPI_Request) const;
      buffer pointer value;
      size int(10:0) const;
   end-pi;
   dcl-s target char(16000000) based(buffer);
   dcl-s count int(10:0);

   count = %min(size : RPGAPI_body_length - RPGAPI_body_position);
   if count <= 0;
      return 0;
   endif;
   %subst(target : 1 : count) =
      %subst(RPGAPI_body_bytes : RPGAPI_body_position + 1 : count);
   RPGAPI_body_position += count;
   return count;
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

   if RPGAPI_sendAll(%addr(head : *data) : %len(head)) and
      %len(utf8_body) > 0;
      RPGAPI_sendAll(%addr(utf8_body : *data) : %len(utf8_body));
   endif;
   close_port( config.return_socket_descriptor );
end-proc;


   // the status line and headers of a response, up to and including the blank
   // line before the body, in the job's CCSID. body_length is the size of the
   // body as it is sent, for Content-Length, or RPGAPI_CHUNKED or
   // RPGAPI_UNTIL_CLOSE for a streamed body
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
         // Connection header saying so is sent above. How long the body is
         // is up to this procedure too
      if %upper(%trim(response.headers(index).name)) = 'CONNECTION' or
         %upper(%trim(response.headers(index).name)) = 'CONTENT-LENGTH' or
         %upper(%trim(response.headers(index).name)) = 'TRANSFER-ENCODING';
         iter;
      endif;

      head += %trim(response.headers(index).name) + ': ' +
              %trim(response.headers(index).value) + RPGAPI_CRLF;
   endfor;

      // the CRLF that ends the last header plus one more make the blank line
   select;
   when body_length = RPGAPI_CHUNKED;
      head += 'Transfer-Encoding: chunked' + RPGAPI_CRLF;
   when body_length >= 0;
      head += 'Content-Length: ' + %char(body_length) + RPGAPI_CRLF;
   endsl;
   head += RPGAPI_CRLF;
   return head;
end-proc;


   // writes all of length bytes to the connection. write() takes what fits;
   // when nothing fits, wait for the client to read, up to the timeout.
   // *off, and nothing more is written to this connection, when it failed
dcl-proc RPGAPI_sendAll;
   dcl-pi *n ind;
      data pointer value;
      length int(10:0) value;
   end-pi;
   dcl-ds poll_fds likeds(PollFd) dim(1);
   dcl-s written int(10:0);
   dcl-s error_number int(10:0) based(error_number_ptr);

   dow length > 0 and not RPGAPI_connection_failed;
      written = write(RPGAPI_connection : data : length);
      if written > 0;
         data += written;
         length -= written;
         iter;
      endif;

      error_number_ptr = get_errno();
      if written < 0 and error_number = EWOULDBLOCK;
         poll_fds(1).fd = RPGAPI_connection;
         poll_fds(1).events = POLLOUT;
         poll_fds(1).revents = 0;
         if poll(poll_fds : 1 : RPGAPI_WRITE_TIMEOUT * 1000) > 0;
            iter;
         endif;
      endif;
      RPGAPI_connection_failed = *on;
   enddo;
   return not RPGAPI_connection_failed;
end-proc;


   // sends the streamed body bytes waiting in RPGAPI_output: as one chunk,
   // a hex size line, the bytes and CR LF, or as they are
dcl-proc RPGAPI_flushOutput;
   dcl-s size_line varchar(12);
   dcl-s value int(10:0);
   dcl-c ASCII_HEX x'30313233343536373839414243444546';

   if RPGAPI_output_length = 0;
      return;
   endif;

   if RPGAPI_stream = RPGAPI_STREAM_CHUNKED;
         // written straight in ASCII, most significant digit first
      value = RPGAPI_output_length;
      dou value = 0;
         size_line = %subst(ASCII_HEX : %rem(value : 16) + 1 : 1) + size_line;
         value = %div(value : 16);
      enddo;
      size_line += x'0d0a';
      RPGAPI_sendAll(%addr(size_line : *data) : %len(size_line));
      RPGAPI_sendAll(%addr(RPGAPI_output) : RPGAPI_output_length);
      size_line = x'0d0a';
      RPGAPI_sendAll(%addr(size_line : *data) : %len(size_line));
   else;
      RPGAPI_sendAll(%addr(RPGAPI_output) : RPGAPI_output_length);
   endif;
   RPGAPI_output_length = 0;
end-proc;


   // ends with an escape message when no streamed response has begun
dcl-proc RPGAPI_checkStream;
   dcl-pi *n;
      procedure varchar(30) const;
   end-pi;
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   if RPGAPI_stream = RPGAPI_STREAM_NONE or
      RPGAPI_stream = RPGAPI_STREAM_ENDED;
      error_text = procedure + ': no response has been begun with ' +
                   'RPGAPI_beginResponse, or it has ended';
         // counter 2: to the procedure that called the one checking
      send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                            %len(error_text) : '*ESCAPE' : '*' : 2 :
                            message_key : error_code );
   endif;
end-proc;


dcl-proc RPGAPI_beginResponse export;
   dcl-pi *n;
      response likeds(RPGAPI_Response) const;
      length int(10:0) const options(*nopass);
   end-pi;
   dcl-ds head_response likeds(RPGAPI_Response);
   dcl-s head varchar(96000);
   dcl-s framing int(10:0);

   head_response = response;
   if head_response.status = 0;
      head_response.status = HTTP_OK;
   endif;

      // an HTTP/1.0 client cannot take chunks: the body ends where the
      // connection does, which it always does after a response
   if %parms >= 2;
      framing = length;
      RPGAPI_stream = RPGAPI_STREAM_LENGTH;
   elseif %trim(RPGAPI_request_protocol) = 'HTTP/1.0';
      framing = RPGAPI_UNTIL_CLOSE;
      RPGAPI_stream = RPGAPI_STREAM_UNTIL_CLOSE;
   else;
      framing = RPGAPI_CHUNKED;
      RPGAPI_stream = RPGAPI_STREAM_CHUNKED;
   endif;

   RPGAPI_output_length = 0;
   head = RPGAPI_convert(RPGAPI_buildHead(head_response : framing) :
                         RPGAPI_JOB_CCSID : RPGAPI_UTF8);
   RPGAPI_sendAll(%addr(head : *data) : %len(head));
end-proc;


dcl-proc RPGAPI_write export;
   dcl-pi *n;
      text varchar(32000) const;
   end-pi;
   dcl-s utf8 varchar(96000);

   RPGAPI_checkStream('RPGAPI_write');
      // the client is gone: skip the conversion too, for the rows still coming
   if RPGAPI_connection_failed;
      return;
   endif;
   utf8 = RPGAPI_convert(text : RPGAPI_JOB_CCSID : RPGAPI_UTF8);
   RPGAPI_writeBytes(%addr(utf8 : *data) : %len(utf8));
end-proc;


dcl-proc RPGAPI_writeBytes export;
   dcl-pi *n;
      buffer pointer value;
      length int(10:0) const;
   end-pi;
   dcl-s source char(16000000) based(buffer);
   dcl-s done int(10:0) inz(0);
   dcl-s count int(10:0);

   RPGAPI_checkStream('RPGAPI_writeBytes');
   if RPGAPI_connection_failed;
      return;
   endif;
   dow done < length;
      if RPGAPI_output_length = %size(RPGAPI_output);
         RPGAPI_flushOutput();
      endif;
      count = %min(length - done : %size(RPGAPI_output) - RPGAPI_output_length);
      %subst(RPGAPI_output : RPGAPI_output_length + 1 : count) =
         %subst(source : done + 1 : count);
      RPGAPI_output_length += count;
      done += count;
   enddo;
end-proc;


dcl-proc RPGAPI_endResponse export;
   dcl-s last_chunk char(5) inz(x'300d0a0d0a');

   if RPGAPI_stream = RPGAPI_STREAM_NONE or
      RPGAPI_stream = RPGAPI_STREAM_ENDED;
      return;
   endif;

   RPGAPI_flushOutput();
      // a chunked body ends with a chunk of size 0: 0 CR LF CR LF
   if RPGAPI_stream = RPGAPI_STREAM_CHUNKED;
      RPGAPI_sendAll(%addr(last_chunk) : %size(last_chunk));
   endif;
   RPGAPI_stream = RPGAPI_STREAM_ENDED;
   close_port(RPGAPI_connection);
end-proc;


dcl-proc RPGAPI_sendFile export;
   dcl-pi *n ind;
      response likeds(RPGAPI_Response) const;
      path varchar(1024) const;
   end-pi;
   dcl-ds file_response likeds(RPGAPI_Response);
   dcl-s descriptor int(10:0);
   dcl-s size int(10:0);
   dcl-s buffer char(65536);
   dcl-s count int(10:0);
   dcl-s index int(10:0);
   dcl-s has_type ind inz(*off);
   dcl-s extension varchar(10);
   dcl-s dot int(10:0);

      // no stepping out of the directory a procedure builds the path in
   if %scan('/../' : '/' + path + '/') > 0;
      return *off;
   endif;

   descriptor = open(%trim(path) : O_RDONLY);
   if descriptor < 0;
      return *off;
   endif;
   size = lseek(descriptor : 0 : SEEK_END);
   if size < 0 or lseek(descriptor : 0 : SEEK_SET) < 0;
      close_port(descriptor);
      return *off;
   endif;

   file_response = response;
   for index = 1 to %elem(file_response.headers);
      if file_response.headers(index).name = *blanks;
         leave;
      endif;
      if %upper(%trim(file_response.headers(index).name)) = 'CONTENT-TYPE';
         has_type = *on;
      endif;
   endfor;
   if not has_type;
      dot = %scanr('.' : path);
      if dot > 0 and dot < %len(path) and %len(path) - dot <= %size(extension) - 2;
         extension = %lower(%subst(path : dot + 1));
      endif;
      RPGAPI_setHeader(file_response : 'Content-Type' :
                       RPGAPI_contentType(extension));
   endif;

   RPGAPI_beginResponse(file_response : size);
   count = read(descriptor : %addr(buffer) : %size(buffer));
   dow count > 0;
      RPGAPI_writeBytes(%addr(buffer) : count);
      count = read(descriptor : %addr(buffer) : %size(buffer));
   enddo;
   close_port(descriptor);
   RPGAPI_endResponse();
   return *on;
end-proc;


   // the Content-Type for a file extension, in lower case
dcl-proc RPGAPI_contentType;
   dcl-pi *n varchar(100);
      extension varchar(10) const;
   end-pi;

   select;
   when extension = 'html' or extension = 'htm';
      return 'text/html; charset=utf-8';
   when extension = 'css';
      return 'text/css; charset=utf-8';
   when extension = 'js';
      return 'text/javascript; charset=utf-8';
   when extension = 'json';
      return 'application/json';
   when extension = 'txt';
      return 'text/plain; charset=utf-8';
   when extension = 'csv';
      return 'text/csv; charset=utf-8';
   when extension = 'xml';
      return 'application/xml';
   when extension = 'svg';
      return 'image/svg+xml';
   when extension = 'png';
      return 'image/png';
   when extension = 'jpg' or extension = 'jpeg';
      return 'image/jpeg';
   when extension = 'gif';
      return 'image/gif';
   when extension = 'ico';
      return 'image/x-icon';
   when extension = 'pdf';
      return 'application/pdf';
   when extension = 'zip';
      return 'application/zip';
   other;
      return 'application/octet-stream';
   endsl;
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
   HTTP_messages(12).status = HTTP_CONTENT_TOO_LARGE;
   HTTP_messages(12).text = 'Content Too Large';
   HTTP_messages(13).status = HTTP_HEADERS_TOO_LARGE;
   HTTP_messages(13).text = 'Request Header Fields Too Large';
   HTTP_messages(14).status = HTTP_NOT_IMPLEMENTED;
   HTTP_messages(14).text = 'Not Implemented';
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
   dcl-s slot int(10:0);
   dcl-s error_number int(10:0) based(error_number_ptr);
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   if %len(text) = 0;
      return '';
   endif;

      // reuse the converter for this pair of CCSIDs if one is open
   for slot = 1 to %elem(RPGAPI_converters);
      if not RPGAPI_converters(slot).in_use or
         (RPGAPI_converters(slot).from_ccsid = from_ccsid and
          RPGAPI_converters(slot).to_ccsid = to_ccsid);
         leave;
      endif;
   endfor;
   if slot > %elem(RPGAPI_converters);
      slot = %elem(RPGAPI_converters);
      converter = RPGAPI_converters(slot).cd;
      iconv_close(converter);
      RPGAPI_converters(slot).in_use = *off;
   endif;

   return_code = 0;
   if not RPGAPI_converters(slot).in_use;
      from_code.ccsid = from_ccsid;
      to_code.ccsid = to_ccsid;
      converter = iconv_open(to_code : from_code);
      if converter.return_value = -1;
         return_code = -1;
         call_name = 'QtqIconvOpen';
      else;
         RPGAPI_converters(slot).from_ccsid = from_ccsid;
         RPGAPI_converters(slot).to_ccsid = to_ccsid;
         RPGAPI_converters(slot).cd = converter;
         RPGAPI_converters(slot).in_use = *on;
      endif;
   endif;

   if return_code = 0;
      call_name = 'iconv';
      converter = RPGAPI_converters(slot).cd;
      input = text;
      input_ptr = %addr(input : *data);
      input_left = %len(input);
      output_ptr = %addr(output);
      output_left = %size(output);
      return_code = iconv(converter : %addr(input_ptr) : %addr(input_left) :
                          %addr(output_ptr) : %addr(output_left));
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
   dcl-pi *n char(40);
      status zoned(3:0) const;
   end-pi;
   dcl-s index int(10:0);
   dcl-s message char(40) inz;

   for index = 1 to %elem(HTTP_messages) by 1;
      if HTTP_messages(index).status = status;
         message = HTTP_messages(index).text;
         index = %elem(HTTP_messages) + 1;
      endif;
   endfor;

   return %trim(message);
end-proc;