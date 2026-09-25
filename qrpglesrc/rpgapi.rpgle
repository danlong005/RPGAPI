**free

ctl-opt option(*nodebugio:*srcstmt) nomain;
/include 'rpgapi_h.rpgle'
/include 'socket_h.rpgle'

   // HTTP text is UTF-8 on the wire and the job's CCSID in the program
dcl-c RPGAPI_UTF8 1208;
dcl-c RPGAPI_JOB_CCSID 0;

   // seconds a client has to send its whole request. The server handles one
   // connection at a time, so a client that stalls holds up everyone else
dcl-s RPGAPI_READ_TIMEOUT int(10:0) inz(30);
   // seconds a client may take no response data before it is given up on,
   // so a client that stops reading does not hold its job
dcl-s RPGAPI_WRITE_TIMEOUT int(10:0) inz(30);
   // RPGAPI_connectionRead / Write: nothing can be read or written right now
dcl-c RPGAPI_WOULD_BLOCK -2;

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
dcl-c RPGAPI_DEFAULT_REQUEST_SIZE 1048576;
   // how much is logged, RPGAPI_LOG_..., from the app's settings
dcl-s RPGAPI_log_level int(10:0) inz(0);
   // for the line logged at the end of each request
dcl-s RPGAPI_request_started timestamp;
dcl-s RPGAPI_request_route varchar(250);
dcl-s RPGAPI_response_status int(10:0) inz(0);
dcl-s RPGAPI_bytes_sent int(20:0) inz(0);
   // counts the connections this job has taken, to tell requests apart in
   // the job log: every message during one carries its number
dcl-s RPGAPI_request_number int(20:0) inz(0);
dcl-s RPGAPI_in_request ind inz(*off);
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
   // a body larger than RPGAPI_max_request_size, up to this, is left on the
   // connection and read as the procedure asks for it. 0: not allowed
dcl-s RPGAPI_max_upload_size int(10:0) inz(0);
   // the part of the body still on the connection: streamed says there is
   // one, done that it has all been read. remaining is what is left of the
   // Content-Length, or of the current chunk
dcl-s RPGAPI_body_streamed ind inz(*off);
dcl-s RPGAPI_body_done ind inz(*off);
dcl-s RPGAPI_body_chunked ind inz(*off);
dcl-s RPGAPI_body_remaining int(10:0) inz(0);
dcl-s RPGAPI_body_crlf_due ind inz(*off);
dcl-s RPGAPI_body_streamed_bytes int(10:0) inz(0);
dcl-s RPGAPI_body_declared int(10:0) inz(0);
dcl-s RPGAPI_continue_pending ind inz(*off);
   // reading a multipart/form-data body: state is RPGAPI_MP_..., delimiter
   // the CR LF -- boundary line between parts in UTF-8, and buffer bytes of
   // the body read ahead to find it
dcl-s RPGAPI_mp_state int(10:0) inz(0);
dcl-c RPGAPI_MP_NOT_STARTED 0;
dcl-c RPGAPI_MP_IN_PART 1;
dcl-c RPGAPI_MP_AT_DELIMITER 2;
dcl-c RPGAPI_MP_DONE 3;
dcl-s RPGAPI_mp_delimiter varchar(80);
dcl-s RPGAPI_mp_buffer char(65536);
dcl-s RPGAPI_mp_start int(10:0) inz(1);
dcl-s RPGAPI_mp_end int(10:0) inz(0);
dcl-s RPGAPI_mp_carry char(4);
dcl-s RPGAPI_mp_carry_length int(10:0) inz(0);
   // the start of a UTF-8 character RPGAPI_readBody could not convert yet
dcl-s RPGAPI_carry char(4);
dcl-s RPGAPI_carry_length int(10:0) inz(0);
   // the client may still be sending a body nobody read: read and drop it
   // for a moment before closing, or the close can lose the response
dcl-s RPGAPI_linger ind inz(*off);
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
   // the method and headers of that request (RPGAPI_sendFile needs them and
   // is not passed the request), converted, and in upper case for finding
   // header names
dcl-s RPGAPI_request_method char(10);
dcl-s RPGAPI_request_headers varchar(32000);
dcl-s RPGAPI_request_headers_upper varchar(32000);
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

   // TLS through the Global Security Kit (GSKit) in QSYS/QSOSSLSR
dcl-c GSK_OK 0;
dcl-c GSK_ERROR_IO 406;
dcl-c GSK_ERROR_SOCKET_CLOSED 420;
dcl-c GSK_WOULD_BLOCK 502;
dcl-c GSK_KEYRING_FILE 201;
dcl-c GSK_KEYRING_PW 202;
dcl-c GSK_KEYRING_LABEL 203;
dcl-c GSK_IBMI_APPLICATION_ID 6999;
dcl-c GSK_FD 300;
dcl-c GSK_HANDSHAKE_TIMEOUT 6998;
dcl-c GSK_SESSION_TYPE 402;
dcl-c GSK_SERVER_SESSION 508;

dcl-pr gsk_environment_open int(10:0) extproc('gsk_environment_open');
   environment pointer;
end-pr;
dcl-pr gsk_environment_init int(10:0) extproc('gsk_environment_init');
   environment pointer value;
end-pr;
dcl-pr gsk_environment_close int(10:0) extproc('gsk_environment_close');
   environment pointer;
end-pr;
dcl-pr gsk_attribute_set_buffer int(10:0) extproc('gsk_attribute_set_buffer');
   handle pointer value;
   id int(10:0) value;
   buffer pointer value options(*string);
   length int(10:0) value;
end-pr;
dcl-pr gsk_attribute_set_enum int(10:0) extproc('gsk_attribute_set_enum');
   handle pointer value;
   id int(10:0) value;
   value int(10:0) value;
end-pr;
dcl-pr gsk_attribute_set_numeric_value int(10:0)
       extproc('gsk_attribute_set_numeric_value');
   handle pointer value;
   id int(10:0) value;
   value int(10:0) value;
end-pr;
dcl-pr gsk_secure_soc_open int(10:0) extproc('gsk_secure_soc_open');
   environment pointer value;
   session pointer;
end-pr;
dcl-pr gsk_secure_soc_init int(10:0) extproc('gsk_secure_soc_init');
   session pointer value;
end-pr;
dcl-pr gsk_secure_soc_read int(10:0) extproc('gsk_secure_soc_read');
   session pointer value;
   buffer pointer value;
   size int(10:0) value;
   received int(10:0);
end-pr;
dcl-pr gsk_secure_soc_write int(10:0) extproc('gsk_secure_soc_write');
   session pointer value;
   buffer pointer value;
   size int(10:0) value;
   written int(10:0);
end-pr;
dcl-pr gsk_secure_soc_close int(10:0) extproc('gsk_secure_soc_close');
   session pointer;
end-pr;
dcl-pr gsk_strerror pointer extproc('gsk_strerror');
   return_code int(10:0) value;
end-pr;

   // how the certificate for TLS is found: RPGAPI_TLS_..., and the
   // application ID or keystore it is found in, from the app's settings. The
   // environment is opened once per job, a session per connection
dcl-s RPGAPI_tls int(10:0) inz(0);
dcl-c RPGAPI_TLS_OFF 0;
dcl-c RPGAPI_TLS_APPLICATION 1;
dcl-c RPGAPI_TLS_KEYSTORE 2;
dcl-s RPGAPI_tls_app_id varchar(100);
dcl-s RPGAPI_tls_keystore_path varchar(1024);
dcl-s RPGAPI_tls_password varchar(128);
dcl-s RPGAPI_tls_label varchar(128);
dcl-s RPGAPI_tls_environment pointer inz(*null);
dcl-s RPGAPI_tls_session pointer inz(*null);

dcl-pr receive_program_message extpgm('QMHRCVPM');
   receiver char(4096) options(*varsize);
   receiver_length int(10:0) const;
   format char(8) const;
   call_stack_entry char(10) const;
   call_stack_counter int(10:0) const;
   message_type char(10) const;
   message_key char(4) const;
   wait_time int(10:0) const;
   action char(10) const;
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
   elseif %parms < 3 and config.jobs > 1;
      worker_count = config.jobs;
   endif;
   RPGAPI_applySettings(config);

      // a worker job was started by RPGAPI_startWorkers from the main job, and
      // serves the socket the main job opened
   worker_env = getenv(RPGAPI_WORKER_VAR);
   RPGAPI_tlsSetup();
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

   if RPGAPI_logging(RPGAPI_LOG_INFO);
      if worker_env <> *null;
         RPGAPI_log(RPGAPI_LOG_INFO : 'worker job serving port ' +
                    %char(config.port));
      else;
         RPGAPI_log(RPGAPI_LOG_INFO : 'serving port ' + %char(config.port) +
                    ' in ' + %char(worker_count) + ' job(s), ' +
                    RPGAPI_tlsDescription() +
                    ', request limit ' + %char(RPGAPI_max_request_size) +
                    ' bytes, upload limit ' + %char(RPGAPI_max_upload_size) +
                    ' bytes, timeouts ' + %char(RPGAPI_READ_TIMEOUT) + 's read ' +
                    %char(RPGAPI_WRITE_TIMEOUT) + 's write');
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
               RPGAPI_closeClient();
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
                  RPGAPI_log(RPGAPI_LOG_DEBUG : 'middleware ' +
                             config.middlewares(index2).url +
                             ' ended the request with ' +
                             %char(response.status));
                  leave;
               endif;
               RPGAPI_log(RPGAPI_LOG_DEBUG : 'middleware ' +
                          config.middlewares(index2).url + ' ran');
            endif;
         endfor;

         if middleware_completed = *on;
            for index = 1 to %elem(config.routes) by 1;
               if config.routes(index).url = *blanks;
                  leave;
               endif;

               if RPGAPI_routeMatches(config.routes(index) : request);
                  RPGAPI_log(RPGAPI_LOG_DEBUG : 'route ' +
                             %trim(config.routes(index).method) + ' ' +
                             config.routes(index).url + ' matched');
                  RPGAPI_callback_ptr = config.routes(index).procedure;
                  response = RPGAPI_callback(request);
                  route_found = *on;
                  leave;
               endif;
            endfor;

            if not route_found;
               RPGAPI_log(RPGAPI_LOG_DEBUG : 'no route matched');
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
            // answer with a 500, or the status a request body failed with,
            // and close the client socket, so the client is not left
            // waiting and the descriptor is not leaked. Once a streamed
            // response has begun, closing is all that is left
            // a request body that failed has logged why itself
         if RPGAPI_reject_status = 0;
            RPGAPI_log(RPGAPI_LOG_ERROR : %trim(request.method) + ' ' +
                       %trim(request.route) + ' failed: ' +
                       RPGAPI_lastException() + '; ' + RPGAPI_failureOutcome());
         endif;
         monitor;
            if RPGAPI_stream = RPGAPI_STREAM_NONE;
               if RPGAPI_reject_status > 0;
                  response = RPGAPI_setResponse(request : RPGAPI_reject_status);
               else;
                  response = RPGAPI_setResponse(request : HTTP_INTERNAL_SERVER);
               endif;
               RPGAPI_sendResponse(config : response);
            else;
               RPGAPI_stream = RPGAPI_STREAM_ENDED;
               RPGAPI_closeClient();
            endif;
         on-error;
            close_port( config.return_socket_descriptor );
         endmon;
      endmon;
   enddo;

   if main_job_pid > 0;
      RPGAPI_log(RPGAPI_LOG_INFO : 'the main job has ended, so this worker ' +
                 'job ends too');
   endif;
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

         // with TLS, a client that does not complete the handshake, such as
         // one sending plain HTTP, is closed and not answered
      if RPGAPI_tls <> RPGAPI_TLS_OFF and not RPGAPI_tlsHandshake(descriptor);
         close_port(descriptor);
         iter;
      endif;

         // the connection inherits non-blocking from the listening socket,
         // and stays that way: reads and writes wait with poll, which can
         // time out, instead of blocking in read() or write()
      config.return_socket_descriptor = descriptor;
      RPGAPI_connection = descriptor;
      RPGAPI_request_started = %timestamp();
      RPGAPI_request_number += 1;
      RPGAPI_in_request = *on;
      RPGAPI_request_route = '';
      RPGAPI_request_method = '';
      RPGAPI_response_status = 0;
      RPGAPI_bytes_sent = 0;
      RPGAPI_log(RPGAPI_LOG_DEBUG : 'connection accepted' +
                 RPGAPI_tlsDescriptionShort());
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

   RPGAPI_log(RPGAPI_LOG_DEBUG : 'starting ' + %char(count) +
              ' worker job(s) running ' + path);
   for index = 1 to count;
      if spawn(%addr(path_z) : 1 : fd_map : inherit : argv : envp) < 0;
         error_number_ptr = get_errno();
         error_text = 'Starting worker job ' + %char(index) + ' of ' +
                      %char(count) + ' (' + path + ') failed: ' +
                      %str(strerror(error_number)) +
                      ' (errno ' + %char(error_number) + ')';
         RPGAPI_log(RPGAPI_LOG_ERROR : error_text);
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
   dcl-s expects_continue ind;
   dcl-s count int(10:0);

   clear refused;
   RPGAPI_reject_status = 0;
   RPGAPI_input_start = 1;
   RPGAPI_input_end = 0;
   RPGAPI_body_length = 0;
   RPGAPI_body_position = 0;
   RPGAPI_body_streamed = *off;
   RPGAPI_body_done = *off;
   RPGAPI_body_chunked = *off;
   RPGAPI_body_remaining = 0;
   RPGAPI_body_crlf_due = *off;
   RPGAPI_body_streamed_bytes = 0;
   RPGAPI_body_declared = 0;
   RPGAPI_continue_pending = *off;
   RPGAPI_carry_length = 0;
   RPGAPI_linger = *off;
   RPGAPI_mp_state = RPGAPI_MP_NOT_STARTED;
   RPGAPI_mp_start = 1;
   RPGAPI_mp_end = 0;
   RPGAPI_mp_carry_length = 0;

      // the whole request has to arrive within the timeout. Read until the
      // blank line after the headers; they have to fit in RPGAPI_input
   RPGAPI_input_deadline = %timestamp() + %seconds(RPGAPI_READ_TIMEOUT);
   dou header_end > 0;
      if RPGAPI_input_end = %size(RPGAPI_input);
         RPGAPI_log(RPGAPI_LOG_WARN : 'request line and headers are over ' +
                    %char(%size(RPGAPI_input)) + ' bytes: answered 431');
         RPGAPI_reject_status = HTTP_HEADERS_TOO_LARGE;
         return refused;
      endif;
      count = RPGAPI_fillInput();
      if count < 0;
         RPGAPI_log(RPGAPI_LOG_WARN : 'no complete request within ' +
                    %char(RPGAPI_READ_TIMEOUT) + 's: connection closed');
         return refused;
      elseif count = 0;
         RPGAPI_log(RPGAPI_LOG_DEBUG : 'the client closed the connection ' +
                    'without sending a request');
         return refused;
      endif;
         // still ASCII here: CR LF CR LF
      header_end = %scan(x'0d0a0d0a' : %subst(RPGAPI_input : 1 : RPGAPI_input_end));
   enddo;

   request = RPGAPI_parse(RPGAPI_convert(%subst(RPGAPI_input : 1 : header_end + 3) :
                                         RPGAPI_UTF8 : RPGAPI_JOB_CCSID));
   RPGAPI_input_start = header_end + 4;
   RPGAPI_request_protocol = request.protocol;
   RPGAPI_request_headers = RPGAPI_convert(
                               %subst(RPGAPI_input : 1 : header_end - 1) :
                               RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
   RPGAPI_request_headers_upper = %upper(RPGAPI_request_headers);
   RPGAPI_request_method = request.method;
   RPGAPI_request_route = %trim(request.route);
   headers = RPGAPI_request_headers_upper;
   if RPGAPI_logging(RPGAPI_LOG_DEBUG);
      RPGAPI_logRequestHeaders(request);
   endif;

      // the body is either chunked or Content-Length bytes long
   transfer_encoding = RPGAPI_headerValue(headers : 'TRANSFER-ENCODING');
   content_length = RPGAPI_headerValue(headers : 'CONTENT-LENGTH');
   if transfer_encoding <> '';
      if transfer_encoding <> 'CHUNKED';
         RPGAPI_log(RPGAPI_LOG_WARN : 'Transfer-Encoding ' + transfer_encoding +
                    ' is not supported: answered 501');
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
         RPGAPI_log(RPGAPI_LOG_WARN : 'Content-Length ' + content_length +
                    ' is not a number: answered 400');
         RPGAPI_reject_status = HTTP_BAD_REQUEST;
         return refused;
      endif;
   endif;

      // a client that sent Expect: 100-continue waits for 100 Continue
      // before sending the body
   expects_continue = RPGAPI_headerValue(headers : 'EXPECT') = '100-CONTINUE'
                      and RPGAPI_input_start > RPGAPI_input_end;

   if length > RPGAPI_max_request_size;
         // too large to keep in memory: left on the connection for the
         // procedure to read, when uploads that large are allowed. Only its
         // first read asks the client for it, so a procedure that refuses
         // without reading never gets sent it
      if RPGAPI_max_upload_size > 0 and length <= RPGAPI_max_upload_size;
         RPGAPI_body_streamed = *on;
         RPGAPI_body_remaining = length;
         RPGAPI_body_declared = length;
         RPGAPI_continue_pending = expects_continue;
         RPGAPI_log(RPGAPI_LOG_DEBUG : 'body of ' + %char(length) +
                    ' bytes left on the connection for the procedure to read');
         length = 0;
      else;
         RPGAPI_log(RPGAPI_LOG_WARN : 'body of ' + %char(length) +
                    ' bytes is over the limit of ' +
                    %char(%max(RPGAPI_max_request_size :
                               RPGAPI_max_upload_size)) +
                    ' bytes: answered 413');
            // refused before reading it, or before the client even sends it
         RPGAPI_reject_status = HTTP_CONTENT_TOO_LARGE;
         RPGAPI_linger = not expects_continue;
         return refused;
      endif;
   endif;

   if expects_continue and (chunked or length > 0);
      RPGAPI_log(RPGAPI_LOG_DEBUG : 'sent 100 Continue');
      RPGAPI_sendContinue();
   endif;

   if chunked;
      if not RPGAPI_readChunkedBody();
         if RPGAPI_reject_status > 0;
            RPGAPI_log(RPGAPI_LOG_WARN : 'chunked body refused: answered ' +
                       %char(RPGAPI_reject_status));
         else;
            RPGAPI_log(RPGAPI_LOG_WARN : 'chunked body did not arrive whole ' +
                       'within ' + %char(RPGAPI_READ_TIMEOUT) +
                       's: connection closed');
         endif;
         return refused;
      endif;
   elseif length > 0;
      if not RPGAPI_readInputToBody(length);
         RPGAPI_log(RPGAPI_LOG_WARN : 'body of ' + %char(length) +
                    ' bytes did not arrive whole within ' +
                    %char(RPGAPI_READ_TIMEOUT) + 's: connection closed');
         return refused;
      endif;
   endif;
   if RPGAPI_body_length > 0 or RPGAPI_body_streamed;
      RPGAPI_log(RPGAPI_LOG_DEBUG : 'body: ' + %char(RPGAPI_body_length) +
                 ' bytes in memory' + %trim(RPGAPI_choose(RPGAPI_body_streamed :
                 ', the rest streamed' : '')) +
                 %trim(RPGAPI_choose(chunked : ', chunked' : '')));
   endif;

      // a body that fits is also handed over in request.body (a varchar,
      // so its size includes a 2-byte length)
   if not RPGAPI_body_streamed and RPGAPI_body_length > 0 and
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

      // read what is there; wait only when nothing is. With TLS, GSKit can
      // hold data it has already decrypted, which poll() does not see
   dow *on;
      count = RPGAPI_connectionRead(%addr(RPGAPI_input) + RPGAPI_input_end :
                                    %size(RPGAPI_input) - RPGAPI_input_end);
      if count >= 0;
         leave;
      endif;
      if count <> RPGAPI_WOULD_BLOCK;
         return -1;
      endif;

         // *mseconds are microseconds; poll wants milliseconds
      wait_ms = %diff(RPGAPI_input_deadline : %timestamp() : *mseconds) / 1000;
      if wait_ms <= 0;
         return -1;
      endif;
      poll_fds(1).fd = RPGAPI_connection;
      poll_fds(1).events = POLLIN;
      poll_fds(1).revents = 0;
      if poll(poll_fds : 1 : wait_ms) <= 0;
         return -1;
      endif;
   enddo;
   RPGAPI_input_end += count;
   return count;
end-proc;


   // moves count bytes of the request into the body, reading as needed.
   // *off when the client closed or the time ran out first
dcl-proc RPGAPI_readInputToBody;
   dcl-pi *n ind;
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
         if RPGAPI_fillInput() <= 0;
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
         if RPGAPI_fillInput() <= 0;
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
   end-pi;
   dcl-s line varchar(1024);
   dcl-s size int(10:0);

   dow *on;
      if not RPGAPI_readInputLine(line);
         return *off;
      endif;
      size = RPGAPI_chunkSize(line);
      if size < 0;
         return *off;
      endif;
      if size = 0;
         leave;
      endif;

      if RPGAPI_body_length + size > RPGAPI_max_request_size;
            // too large to keep in memory: the rest, from this chunk on, is
            // read by the procedure when uploads that large are allowed
         if RPGAPI_max_upload_size > 0 and
            RPGAPI_body_length + size <= RPGAPI_max_upload_size;
            RPGAPI_body_streamed = *on;
            RPGAPI_body_chunked = *on;
            RPGAPI_body_remaining = size;
            RPGAPI_body_declared = -1;
            return *on;
         endif;
         RPGAPI_reject_status = HTTP_CONTENT_TOO_LARGE;
         RPGAPI_linger = *on;
         return *off;
      endif;
      if not RPGAPI_readInputToBody(size);
         return *off;
      endif;

         // every chunk's data is followed by CR LF
      if not RPGAPI_readInputLine(line);
         return *off;
      endif;
      if line <> '';
         RPGAPI_reject_status = HTTP_BAD_REQUEST;
         return *off;
      endif;
   enddo;

   return RPGAPI_readTrailers();
end-proc;


   // the trailer fields after the last chunk, ignored, up to the empty line
   // that ends the request
dcl-proc RPGAPI_readTrailers;
   dcl-pi *n ind;
   end-pi;
   dcl-s line varchar(1024);

   dou line = '';
      if not RPGAPI_readInputLine(line);
         return *off;
      endif;
   enddo;
   return *on;
end-proc;


   // the size of a chunk from its size line: hex, optionally followed by
   // ;extensions. Sets RPGAPI_reject_status and returns -1 when the line is
   // not valid or the size is out of all bounds
dcl-proc RPGAPI_chunkSize;
   dcl-pi *n int(10:0);
      ascii_line varchar(1024) const;
   end-pi;
   dcl-s line varchar(1024);
   dcl-s size int(10:0) inz(0);
   dcl-s index int(10:0);
   dcl-s digit int(10:0);
   dcl-s stop int(10:0);
   dcl-c HEX_DIGITS '0123456789ABCDEF';

      // the line is ASCII: converted to compare its letters and digits
   line = %upper(RPGAPI_convert(ascii_line : RPGAPI_UTF8 : RPGAPI_JOB_CCSID));
   stop = %scan(';' : line);
   if stop > 0;
      line = %subst(line : 1 : stop - 1);
   endif;
   line = %trim(line);
   if line = '';
      RPGAPI_reject_status = HTTP_BAD_REQUEST;
      return -1;
   endif;

   for index = 1 to %len(line);
      digit = %scan(%subst(line : index : 1) : HEX_DIGITS) - 1;
      if digit < 0;
         RPGAPI_reject_status = HTTP_BAD_REQUEST;
         return -1;
      endif;
         // one more digit would not fit
      if size > 134217727;
         RPGAPI_reject_status = HTTP_CONTENT_TOO_LARGE;
         RPGAPI_linger = *on;
         return -1;
      endif;
      size = size * 16 + digit;
   endfor;
   return size;
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
      config likeds(RPGAPI_App);
      bytes int(10:0) const;
   end-pi;

   if bytes < 1 or bytes > RPGAPI_MAX_BODY_LIMIT;
      RPGAPI_settingFailed('RPGAPI_setMaxRequestSize: ' + %char(bytes) +
                           ' is not between 1 and ' +
                           %char(RPGAPI_MAX_BODY_LIMIT));
   endif;
   config.max_request_size = bytes;
end-proc;


dcl-proc RPGAPI_setLogLevel export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      level int(10:0) const;
   end-pi;

   if level < RPGAPI_LOG_OFF or level > RPGAPI_LOG_DEBUG;
      RPGAPI_settingFailed('RPGAPI_setLogLevel: ' + %char(level) +
                           ' is not a level, RPGAPI_LOG_OFF to _DEBUG');
   endif;
   config.log_level = level;
end-proc;


dcl-proc RPGAPI_setTimeouts export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      read_seconds int(10:0) const;
      write_seconds int(10:0) const;
   end-pi;

   if read_seconds < 1 or write_seconds < 1;
      RPGAPI_settingFailed('RPGAPI_setTimeouts: the timeouts have to be at ' +
                           'least 1 second');
   endif;
   config.read_timeout = read_seconds;
   config.write_timeout = write_seconds;
end-proc;


   // ends the procedure that called the setter with an escape message
dcl-proc RPGAPI_settingFailed;
   dcl-pi *n;
      error_text varchar(512) const;
   end-pi;
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

      // counter 2: past the setter, to the procedure that called it
   send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                         %len(error_text) : '*ESCAPE' : '*' : 2 :
                         message_key : error_code );
end-proc;


   // copies the app's settings into the job, with their defaults, when
   // RPGAPI_start begins
dcl-proc RPGAPI_applySettings;
   dcl-pi *n;
      config likeds(RPGAPI_App);
   end-pi;

   RPGAPI_log_level = RPGAPI_LOG_OFF;
   if config.log_level >= RPGAPI_LOG_OFF and config.log_level <= RPGAPI_LOG_DEBUG;
      RPGAPI_log_level = config.log_level;
   endif;
   RPGAPI_max_request_size = RPGAPI_DEFAULT_REQUEST_SIZE;
   if config.max_request_size > 0;
      RPGAPI_max_request_size = %min(config.max_request_size :
                                     RPGAPI_MAX_BODY_LIMIT);
   endif;
   RPGAPI_max_upload_size = %max(config.max_upload_size : 0);
   RPGAPI_READ_TIMEOUT = 30;
   if config.read_timeout > 0;
      RPGAPI_READ_TIMEOUT = config.read_timeout;
   endif;
   RPGAPI_WRITE_TIMEOUT = 30;
   if config.write_timeout > 0;
      RPGAPI_WRITE_TIMEOUT = config.write_timeout;
   endif;

   RPGAPI_tls = RPGAPI_TLS_OFF;
   if %len(%trim(config.tls_application_id)) > 0;
      RPGAPI_tls = RPGAPI_TLS_APPLICATION;
      RPGAPI_tls_app_id = %trim(config.tls_application_id);
   elseif %len(%trim(config.tls_keystore)) > 0;
      RPGAPI_tls = RPGAPI_TLS_KEYSTORE;
      RPGAPI_tls_keystore_path = %trim(config.tls_keystore);
      RPGAPI_tls_password = config.tls_password;
      RPGAPI_tls_label = %trim(config.tls_label);
   endif;
end-proc;


dcl-proc RPGAPI_setMaxUploadSize export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      bytes int(10:0) const;
   end-pi;

   if bytes < 0;
      RPGAPI_settingFailed('RPGAPI_setMaxUploadSize: ' + %char(bytes) +
                           ' is less than 0');
   endif;
   config.max_upload_size = bytes;
end-proc;


dcl-proc RPGAPI_bodyLength export;
   dcl-pi *n int(10:0);
      request likeds(RPGAPI_Request) const;
   end-pi;

   select;
   when not RPGAPI_body_streamed;
      return RPGAPI_body_length;
   when RPGAPI_body_declared >= 0;
      return RPGAPI_body_declared;
   when RPGAPI_body_done;
      return RPGAPI_body_length + RPGAPI_body_streamed_bytes;
   other;
      return -1;
   endsl;
end-proc;


dcl-proc RPGAPI_readBody export;
   dcl-pi *n varchar(32000);
      request likeds(RPGAPI_Request) const;
   end-pi;
      // at most 16000 bytes, so the text fits even if the job's CCSID needs
      // more bytes per character than UTF-8, plus a carried character
   dcl-s raw char(16004);
   dcl-s length int(10:0);
   dcl-s count int(10:0);

   dow *on;
      length = RPGAPI_carry_length;
      if length > 0;
         %subst(raw : 1 : length) = %subst(RPGAPI_carry : 1 : length);
      endif;
      RPGAPI_carry_length = 0;
      count = RPGAPI_nextBodyBytes(%addr(raw) + length : 16000);
      length += count;
      if length = 0;
         return '';
      endif;
      if count > 0;
         length = RPGAPI_holdPartialUtf8(%addr(raw) : length :
                                         RPGAPI_carry : RPGAPI_carry_length);
      endif;
      if length > 0;
         return RPGAPI_convert(%subst(raw : 1 : length) :
                               RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
      endif;
   enddo;
end-proc;


   // when the length bytes at raw end inside a UTF-8 character, moves that
   // character's bytes to carry, to go in front of the next piece, and
   // returns how many bytes are left. Continuation bytes are 10xxxxxx, and a
   // lead byte says how many bytes its character has
dcl-proc RPGAPI_holdPartialUtf8;
   dcl-pi *n int(10:0);
      raw pointer value;
      length int(10:0) const;
      carry char(4);
      carry_length int(10:0);
   end-pi;
   dcl-s bytes char(16004) based(raw);
   dcl-s continuation int(10:0) inz(0);
   dcl-s lead int(10:0);
   dcl-s needed int(10:0);
   dcl-ds one_byte;
      character char(1);
      number uns(3:0) overlay(character);
   end-ds;

   dow continuation < 3 and continuation < length;
      character = %subst(bytes : length - continuation : 1);
      if number < 128 or number > 191;
         leave;
      endif;
      continuation += 1;
   enddo;
   lead = length - continuation;
   if lead < 1;
      return length;
   endif;

   character = %subst(bytes : lead : 1);
   select;
   when number >= 240;
      needed = 4;
   when number >= 224;
      needed = 3;
   when number >= 192;
      needed = 2;
   other;
      needed = 1;
   endsl;
   if needed <= continuation + 1;
      return length;
   endif;
   carry_length = length - lead + 1;
   carry = %subst(bytes : lead : carry_length);
   return lead - 1;
end-proc;


dcl-proc RPGAPI_readBodyBytes export;
   dcl-pi *n int(10:0);
      request likeds(RPGAPI_Request) const;
      buffer pointer value;
      size int(10:0) const;
   end-pi;

   return RPGAPI_nextBodyBytes(buffer : size);
end-proc;


   // up to size bytes of the body: what was read before routing first, then
   // what is left on the connection. 0 at its end
dcl-proc RPGAPI_nextBodyBytes;
   dcl-pi *n int(10:0);
      buffer pointer value;
      size int(10:0) const;
   end-pi;
   dcl-s target char(16000000) based(buffer);
   dcl-s count int(10:0);

   count = %min(size : RPGAPI_body_length - RPGAPI_body_position);
   if count > 0;
      %subst(target : 1 : count) =
         %subst(RPGAPI_body_bytes : RPGAPI_body_position + 1 : count);
      RPGAPI_body_position += count;
      return count;
   endif;
   if RPGAPI_body_streamed and size > 0;
      return RPGAPI_streamBody(buffer : size);
   endif;
   return 0;
end-proc;


   // reads up to size bytes of the part of the body still on the
   // connection into buffer: 0 at its end. A body that is too large, not
   // valid, or stops arriving ends the procedure reading it with an escape
   // message, and the request is answered with 413, 400 or 408
dcl-proc RPGAPI_streamBody;
   dcl-pi *n int(10:0);
      buffer pointer value;
      size int(10:0) const;
   end-pi;
   dcl-s target char(16000000) based(buffer);
   dcl-s line varchar(1024);
   dcl-s chunk int(10:0);
   dcl-s count int(10:0);

   if RPGAPI_body_done;
      return 0;
   endif;
   if RPGAPI_continue_pending;
      RPGAPI_continue_pending = *off;
      RPGAPI_sendContinue();
   endif;
      // the client has the timeout for every piece, not for the whole body
   RPGAPI_input_deadline = %timestamp() + %seconds(RPGAPI_READ_TIMEOUT);

   if RPGAPI_body_chunked and RPGAPI_body_remaining = 0;
      if RPGAPI_body_crlf_due;
         if not RPGAPI_readInputLine(line) or line <> '';
            RPGAPI_bodyFailed('ends a chunk without CR LF');
         endif;
         RPGAPI_body_crlf_due = *off;
      endif;
      if not RPGAPI_readInputLine(line);
         RPGAPI_bodyFailed('has a chunk size line that did not arrive whole');
      endif;
      chunk = RPGAPI_chunkSize(line);
      if chunk < 0;
         RPGAPI_bodyFailed('has a chunk size that is not valid');
      endif;
      if chunk = 0;
         if not RPGAPI_readTrailers();
            RPGAPI_bodyFailed('has trailers that did not arrive whole');
         endif;
         RPGAPI_body_done = *on;
         return 0;
      endif;
      if RPGAPI_body_length + RPGAPI_body_streamed_bytes + chunk >
         RPGAPI_max_upload_size;
         RPGAPI_reject_status = HTTP_CONTENT_TOO_LARGE;
         RPGAPI_linger = *on;
         RPGAPI_bodyFailed('is larger than the upload limit of ' +
                           %char(RPGAPI_max_upload_size) + ' bytes');
      endif;
      RPGAPI_body_remaining = chunk;
   endif;

   if RPGAPI_input_start > RPGAPI_input_end;
      if RPGAPI_fillInput() <= 0;
         RPGAPI_bodyFailed('stopped before it was complete');
      endif;
   endif;
   count = %min(%min(size : RPGAPI_body_remaining) :
                RPGAPI_input_end - RPGAPI_input_start + 1);
   %subst(target : 1 : count) = %subst(RPGAPI_input : RPGAPI_input_start : count);
   RPGAPI_input_start += count;
   RPGAPI_body_remaining -= count;
   RPGAPI_body_streamed_bytes += count;
   if RPGAPI_body_remaining = 0;
      if RPGAPI_body_chunked;
         RPGAPI_body_crlf_due = *on;
      else;
         RPGAPI_body_done = *on;
      endif;
   endif;
   return count;
end-proc;


   // ends the procedure reading a streamed body with an escape message. The
   // request is answered with RPGAPI_reject_status: 408 when the time ran
   // out, 400 when nothing else was set
dcl-proc RPGAPI_bodyFailed;
   dcl-pi *n;
      problem varchar(200) const;
   end-pi;
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   if RPGAPI_reject_status = 0;
      if %timestamp() >= RPGAPI_input_deadline;
         RPGAPI_reject_status = HTTP_REQUEST_TIMEOUT;
      else;
         RPGAPI_reject_status = HTTP_BAD_REQUEST;
      endif;
   endif;
   RPGAPI_body_done = *on;
   RPGAPI_log(RPGAPI_LOG_WARN : 'the request body ' + problem + ': answered ' +
              %char(RPGAPI_reject_status));
   error_text = 'The request body ' + problem;
   send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                         %len(error_text) : '*ESCAPE' : '*' : 1 :
                         message_key : error_code );
end-proc;


dcl-proc RPGAPI_sendContinue;
   dcl-s text varchar(40);
   dcl-s utf8 varchar(120);

   text = 'HTTP/1.1 100 Continue' + RPGAPI_DBL_CRLF;
   utf8 = RPGAPI_convert(text : RPGAPI_JOB_CCSID : RPGAPI_UTF8);
   RPGAPI_sendAll(%addr(utf8 : *data) : %len(utf8));
end-proc;


dcl-proc RPGAPI_saveBody export;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      path varchar(1024) const;
   end-pi;
   dcl-s descriptor int(10:0);
   dcl-s buffer char(65536);
   dcl-s count int(10:0);
   dcl-s written int(10:0);
   dcl-s done int(10:0);
   dcl-s failed ind inz(*off);
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');
      // rw-r--r--
   dcl-c FILE_MODE 420;

   descriptor = open(%trim(path) : O_WRONLY + O_CREAT + O_TRUNC : FILE_MODE);
   if descriptor < 0;
      return *off;
   endif;

   monitor;
      count = RPGAPI_nextBodyBytes(%addr(buffer) : %size(buffer));
      dow count > 0 and not failed;
         done = 0;
         dow done < count;
            written = write(descriptor : %addr(buffer) + done : count - done);
            if written <= 0;
               failed = *on;
               leave;
            endif;
            done += written;
         enddo;
         count = RPGAPI_nextBodyBytes(%addr(buffer) : %size(buffer));
      enddo;
   on-error;
      failed = *on;
   endmon;

   close_port(descriptor);
   if failed;
         // no half-written upload left behind
      unlink(%trim(path));
      if RPGAPI_reject_status = 0;
         RPGAPI_reject_status = HTTP_INTERNAL_SERVER;
      endif;
      error_text = 'RPGAPI_saveBody: the request body could not be saved to ' +
                   %trim(path);
      RPGAPI_log(RPGAPI_LOG_ERROR : error_text);
      send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                            %len(error_text) : '*ESCAPE' : '*' : 1 :
                            message_key : error_code );
   endif;
   return *on;
end-proc;


dcl-proc RPGAPI_nextPart export;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      part likeds(RPGAPI_Part);
   end-pi;
   dcl-s scratch char(8192);
   dcl-s line varchar(8192);
   dcl-s text varchar(8192);
   dcl-s eof ind;

   clear part;
   if RPGAPI_mp_state = RPGAPI_MP_NOT_STARTED and not RPGAPI_startMultipart(request);
      RPGAPI_mp_state = RPGAPI_MP_DONE;
   endif;
   if RPGAPI_mp_state = RPGAPI_MP_DONE;
      return *off;
   endif;

      // skip what is left of the part before, or of the preamble
   dow RPGAPI_partBytes(%addr(scratch) : %size(scratch)) > 0;
   enddo;

      // the rest of the delimiter line: -- after the last part, else nothing
      // but perhaps spaces
   eof = RPGAPI_partLine(line);
   if %len(line) >= 2 and %subst(line : 1 : 2) = x'2d2d';
      RPGAPI_mp_state = RPGAPI_MP_DONE;
      return *off;
   endif;
   if eof or %len(%trim(line : x'2009')) > 0;
      RPGAPI_multipartFailed('a boundary line is not followed by CR LF');
   endif;

      // the part's headers, up to an empty line
   dow *on;
      if RPGAPI_partLine(line);
         RPGAPI_multipartFailed('the body ends in the headers of a part');
      endif;
      if line = '';
         leave;
      endif;
      text = RPGAPI_convert(line : RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
      select;
      when RPGAPI_startsWith(text : 'content-disposition:');
         part.name = RPGAPI_headerParam(text : 'name');
         part.filename = RPGAPI_headerParam(text : 'filename');
      when RPGAPI_startsWith(text : 'content-type:');
         part.content_type = %trim(%subst(text : 14));
      endsl;
   enddo;

   RPGAPI_mp_state = RPGAPI_MP_IN_PART;
   RPGAPI_mp_carry_length = 0;
   RPGAPI_log(RPGAPI_LOG_DEBUG : 'multipart part name=' + part.name +
              ' filename=' + part.filename + ' type=' + part.content_type);
   return *on;
end-proc;


dcl-proc RPGAPI_readPart export;
   dcl-pi *n varchar(32000);
      request likeds(RPGAPI_Request) const;
   end-pi;
      // at most 16000 bytes, as for RPGAPI_readBody
   dcl-s raw char(16004);
   dcl-s length int(10:0);
   dcl-s count int(10:0);

   dow *on;
      length = RPGAPI_mp_carry_length;
      if length > 0;
         %subst(raw : 1 : length) = %subst(RPGAPI_mp_carry : 1 : length);
      endif;
      RPGAPI_mp_carry_length = 0;
      count = RPGAPI_partBytes(%addr(raw) + length : 16000);
      length += count;
      if length = 0;
         return '';
      endif;
      if count > 0;
         length = RPGAPI_holdPartialUtf8(%addr(raw) : length :
                                         RPGAPI_mp_carry : RPGAPI_mp_carry_length);
      endif;
      if length > 0;
         return RPGAPI_convert(%subst(raw : 1 : length) :
                               RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
      endif;
   enddo;
end-proc;


dcl-proc RPGAPI_readPartBytes export;
   dcl-pi *n int(10:0);
      request likeds(RPGAPI_Request) const;
      buffer pointer value;
      size int(10:0) const;
   end-pi;

   return RPGAPI_partBytes(buffer : size);
end-proc;


dcl-proc RPGAPI_savePart export;
   dcl-pi *n int(10:0);
      request likeds(RPGAPI_Request) const;
      path varchar(1024) const;
   end-pi;
   dcl-s descriptor int(10:0);
   dcl-s buffer char(65536);
   dcl-s count int(10:0);
   dcl-s written int(10:0);
   dcl-s done int(10:0);
   dcl-s total int(10:0) inz(0);
   dcl-s failed ind inz(*off);
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');
      // rw-r--r--
   dcl-c FILE_MODE 420;

   descriptor = open(%trim(path) : O_WRONLY + O_CREAT + O_TRUNC : FILE_MODE);
   if descriptor < 0;
      return -1;
   endif;

   monitor;
      count = RPGAPI_partBytes(%addr(buffer) : %size(buffer));
      dow count > 0 and not failed;
         done = 0;
         dow done < count;
            written = write(descriptor : %addr(buffer) + done : count - done);
            if written <= 0;
               failed = *on;
               leave;
            endif;
            done += written;
         enddo;
         total += count;
         count = RPGAPI_partBytes(%addr(buffer) : %size(buffer));
      enddo;
   on-error;
      failed = *on;
   endmon;

   close_port(descriptor);
   if failed;
         // no half-written file left behind
      unlink(%trim(path));
      if RPGAPI_reject_status = 0;
         RPGAPI_reject_status = HTTP_INTERNAL_SERVER;
      endif;
      error_text = 'RPGAPI_savePart: the part could not be saved to ' +
                   %trim(path);
      RPGAPI_log(RPGAPI_LOG_ERROR : error_text);
      send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                            %len(error_text) : '*ESCAPE' : '*' : 1 :
                            message_key : error_code );
   endif;
   return total;
end-proc;


   // sets up reading the body as multipart/form-data from the boundary in
   // its Content-Type. *off when it is not multipart/form-data
dcl-proc RPGAPI_startMultipart;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s content_type varchar(1024);
   dcl-s boundary varchar(256);

   content_type = RPGAPI_getHeader(request : 'Content-Type');
   if not RPGAPI_startsWith(content_type : 'multipart/form-data');
      return *off;
   endif;
   boundary = RPGAPI_headerParam(content_type : 'boundary');
   if boundary = '' or %len(boundary) > 70;
      return *off;
   endif;

      // the body starts with --boundary, and every other delimiter is CR LF
      // --boundary: put a CR LF in front so the first is found the same way,
      // and whatever is before it (the preamble) is the data of no part
   RPGAPI_mp_delimiter = x'0d0a' + RPGAPI_convert('--' + boundary :
                                                  RPGAPI_JOB_CCSID : RPGAPI_UTF8);
   %subst(RPGAPI_mp_buffer : 1 : 2) = x'0d0a';
   RPGAPI_mp_start = 1;
   RPGAPI_mp_end = 2;
   RPGAPI_mp_state = RPGAPI_MP_IN_PART;
   return *on;
end-proc;


   // up to size bytes of the current part, up to the next delimiter, which
   // is then passed over. 0 at the end of the part
dcl-proc RPGAPI_partBytes;
   dcl-pi *n int(10:0);
      buffer pointer value;
      size int(10:0) const;
   end-pi;
   dcl-s target char(16000000) based(buffer);
   dcl-s available int(10:0);
   dcl-s found int(10:0);
   dcl-s count int(10:0);

   if RPGAPI_mp_state <> RPGAPI_MP_IN_PART or size <= 0;
      return 0;
   endif;

   dow *on;
      available = RPGAPI_mp_end - RPGAPI_mp_start + 1;
      found = 0;
      if available >= %len(RPGAPI_mp_delimiter);
         found = %scan(RPGAPI_mp_delimiter :
                       %subst(RPGAPI_mp_buffer : RPGAPI_mp_start : available));
      endif;
      if found = 1;
         RPGAPI_mp_start += %len(RPGAPI_mp_delimiter);
         RPGAPI_mp_state = RPGAPI_MP_AT_DELIMITER;
         return 0;
      endif;

         // without a delimiter in sight, the last bytes could be the start
         // of one: keep them until more has arrived
      if found > 1;
         count = %min(size : found - 1);
      else;
         count = %min(size : available - %len(RPGAPI_mp_delimiter) + 1);
      endif;
      if count > 0;
         %subst(target : 1 : count) =
            %subst(RPGAPI_mp_buffer : RPGAPI_mp_start : count);
         RPGAPI_mp_start += count;
         return count;
      endif;

      if RPGAPI_fillMultipart() = 0;
         RPGAPI_multipartFailed('the body ends inside a part');
      endif;
   enddo;
end-proc;


   // the next line of the body, without its CR LF. *on when the body ended
   // before a CR LF: line then has what was left
dcl-proc RPGAPI_partLine;
   dcl-pi *n ind;
      line varchar(8192);
   end-pi;
   dcl-s found int(10:0);
   dcl-s available int(10:0);

   dow *on;
      available = RPGAPI_mp_end - RPGAPI_mp_start + 1;
      found = 0;
      if available > 0;
         found = %scan(x'0d0a' :
                       %subst(RPGAPI_mp_buffer : RPGAPI_mp_start : available));
      endif;
      if found > 0;
         if found - 1 > 8192;
            RPGAPI_multipartFailed('has a header line over 8192 bytes');
         endif;
         line = %subst(RPGAPI_mp_buffer : RPGAPI_mp_start : found - 1);
         RPGAPI_mp_start += found + 1;
         return *off;
      endif;
      if available > 8192;
         RPGAPI_multipartFailed('has a header line over 8192 bytes');
      endif;
      if RPGAPI_fillMultipart() = 0;
         line = '';
         if available > 0;
            line = %subst(RPGAPI_mp_buffer : RPGAPI_mp_start : available);
         endif;
         RPGAPI_mp_start = RPGAPI_mp_end + 1;
         return *on;
      endif;
   enddo;
end-proc;


   // reads more of the body into the multipart buffer, after moving what is
   // left to its front. 0 at the end of the body
dcl-proc RPGAPI_fillMultipart;
   dcl-pi *n int(10:0);
   end-pi;
   dcl-s count int(10:0);

   count = RPGAPI_mp_end - RPGAPI_mp_start + 1;
   if count > 0 and RPGAPI_mp_start > 1;
      %subst(RPGAPI_mp_buffer : 1 : count) =
         %subst(RPGAPI_mp_buffer : RPGAPI_mp_start : count);
   endif;
   RPGAPI_mp_start = 1;
   RPGAPI_mp_end = %max(count : 0);

   count = RPGAPI_nextBodyBytes(%addr(RPGAPI_mp_buffer) + RPGAPI_mp_end :
                                %size(RPGAPI_mp_buffer) - RPGAPI_mp_end);
   RPGAPI_mp_end += count;
   return count;
end-proc;


dcl-proc RPGAPI_multipartFailed;
   dcl-pi *n;
      problem varchar(200) const;
   end-pi;

   RPGAPI_mp_state = RPGAPI_MP_DONE;
   RPGAPI_reject_status = HTTP_BAD_REQUEST;
   RPGAPI_bodyFailed('is not valid multipart/form-data: ' + problem);
end-proc;


   // whether text starts with prefix, in any case
dcl-proc RPGAPI_startsWith;
   dcl-pi *n ind;
      text varchar(8192) const;
      prefix varchar(100) const;
   end-pi;

   return %len(text) >= %len(prefix) and
          %lower(%subst(text : 1 : %len(prefix))) = %lower(prefix);
end-proc;


   // the value of a parameter such as name="x" in a header value such as
   // form-data; name="x"; filename="a.txt", without its quotes. '' when it
   // is not there. The parameter name is matched in any case, and only as a
   // whole word, so name does not find the one in filename
dcl-proc RPGAPI_headerParam;
   dcl-pi *n varchar(1024);
      text varchar(8192) const;
      parameter varchar(50) const;
   end-pi;
   dcl-s lower varchar(8192);
   dcl-s position int(10:0) inz(0);
   dcl-s start int(10:0);
   dcl-s stop int(10:0);
   dcl-s before char(1);

   lower = %lower(text);
   dow *on;
      position = %scan(%lower(parameter) + '=' : lower : position + 1);
      if position = 0;
         return '';
      endif;
      if position = 1;
         leave;
      endif;
      before = %subst(lower : position - 1 : 1);
      if before = ' ' or before = ';' or before = x'05';
         leave;
      endif;
   enddo;

   start = position + %len(parameter) + 1;
   if start > %len(text);
      return '';
   endif;
   if %subst(text : start : 1) = '"';
      stop = %scan('"' : text : start + 1);
      if stop = 0;
         stop = %len(text) + 1;
      endif;
      return %subst(text : start + 1 : stop - start - 1);
   endif;
   stop = %scan(';' : text : start);
   if stop = 0;
      stop = %len(text) + 1;
   endif;
   return %trim(%subst(text : start : stop - start));
end-proc;


dcl-proc RPGAPI_setTlsApplication export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      application_id varchar(100) const;
   end-pi;

   config.tls_application_id = %trim(application_id);
   config.tls_keystore = '';
end-proc;


dcl-proc RPGAPI_setTlsKeystore export;
   dcl-pi *n;
      config likeds(RPGAPI_App);
      path varchar(1024) const;
      password varchar(128) const;
      label varchar(128) const options(*nopass);
   end-pi;

   config.tls_application_id = '';
   config.tls_keystore = %trim(path);
   config.tls_password = password;
   config.tls_label = '';
   if %parms >= 4;
      config.tls_label = %trim(label);
   endif;
end-proc;


   // opens this job's GSKit environment for serving TLS, when TLS is set.
   // A certificate that cannot be used ends RPGAPI_start with an escape
   // message giving GSKit's reason
dcl-proc RPGAPI_tlsSetup;
   dcl-s return_code int(10:0);

   if RPGAPI_tls = RPGAPI_TLS_OFF or RPGAPI_tls_environment <> *null;
      return;
   endif;

   return_code = gsk_environment_open(RPGAPI_tls_environment);
   if return_code <> GSK_OK;
      RPGAPI_tlsFailed('gsk_environment_open' : return_code);
   endif;
   return_code = gsk_attribute_set_enum(RPGAPI_tls_environment :
                                        GSK_SESSION_TYPE : GSK_SERVER_SESSION);
   if return_code <> GSK_OK;
      RPGAPI_tlsFailed('setting the session type' : return_code);
   endif;

   if RPGAPI_tls = RPGAPI_TLS_APPLICATION;
      return_code = gsk_attribute_set_buffer(RPGAPI_tls_environment :
                       GSK_IBMI_APPLICATION_ID : RPGAPI_tls_app_id :
                       %len(RPGAPI_tls_app_id));
      if return_code <> GSK_OK;
         RPGAPI_tlsFailed('setting the application ID' : return_code);
      endif;
   else;
      return_code = gsk_attribute_set_buffer(RPGAPI_tls_environment :
                       GSK_KEYRING_FILE : RPGAPI_tls_keystore_path :
                       %len(RPGAPI_tls_keystore_path));
      if return_code = GSK_OK;
         return_code = gsk_attribute_set_buffer(RPGAPI_tls_environment :
                          GSK_KEYRING_PW : RPGAPI_tls_password :
                          %len(RPGAPI_tls_password));
      endif;
      if return_code = GSK_OK and RPGAPI_tls_label <> '';
         return_code = gsk_attribute_set_buffer(RPGAPI_tls_environment :
                          GSK_KEYRING_LABEL : RPGAPI_tls_label :
                          %len(RPGAPI_tls_label));
      endif;
      if return_code <> GSK_OK;
         RPGAPI_tlsFailed('setting the keystore' : return_code);
      endif;
   endif;

   return_code = gsk_environment_init(RPGAPI_tls_environment);
   if return_code <> GSK_OK;
      RPGAPI_tlsFailed('gsk_environment_init' : return_code);
   endif;
end-proc;


dcl-proc RPGAPI_tlsFailed;
   dcl-pi *n;
      step varchar(50) const;
      return_code int(10:0) const;
   end-pi;
   dcl-s error_number int(10:0) based(error_number_ptr);
   dcl-s error_text varchar(512);
   dcl-s message_key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   if RPGAPI_tls_environment <> *null;
      gsk_environment_close(RPGAPI_tls_environment);
      RPGAPI_tls_environment = *null;
   endif;
   error_text = 'TLS could not be set up, ' + step + ' failed: ' +
                %str(gsk_strerror(return_code)) +
                ' (GSKit ' + %char(return_code) + ')';
   RPGAPI_log(RPGAPI_LOG_ERROR : error_text);
      // an I/O error's GSKit text only says to look at errno, when it is set
   if return_code = GSK_ERROR_IO;
      error_number_ptr = get_errno();
      if error_number <> 0;
         error_text += ' ' + %str(strerror(error_number)) +
                       ' (errno ' + %char(error_number) + ')';
      endif;
   endif;
      // counter 2: past RPGAPI_tlsSetup, to the procedure that called it
   send_program_message( 'CPF9898' : 'QCPFMSG   *LIBL' : error_text :
                         %len(error_text) : '*ESCAPE' : '*' : 2 :
                         message_key : error_code );
end-proc;


   // the TLS handshake on a connection just accepted. The connection is
   // blocking for it, with GSKit's handshake timeout set to the read timeout
   // so a client cannot hold the job; afterwards it is non-blocking again
dcl-proc RPGAPI_tlsHandshake;
   dcl-pi *n ind;
      descriptor int(10:0) const;
   end-pi;
   dcl-s flags int(10:0);
   dcl-s return_code int(10:0);

   RPGAPI_tlsClose();
   flags = fcntl(descriptor : F_GETFL);
   if flags >= 0 and %bitand(flags : O_NONBLOCK) <> 0;
      fcntl(descriptor : F_SETFL : flags - O_NONBLOCK);
   endif;

   return_code = gsk_secure_soc_open(RPGAPI_tls_environment :
                                     RPGAPI_tls_session);
   if return_code = GSK_OK;
      return_code = gsk_attribute_set_numeric_value(RPGAPI_tls_session :
                                                    GSK_FD : descriptor);
   endif;
   if return_code = GSK_OK;
      return_code = gsk_attribute_set_numeric_value(RPGAPI_tls_session :
                       GSK_HANDSHAKE_TIMEOUT : RPGAPI_READ_TIMEOUT);
   endif;
   if return_code = GSK_OK;
      return_code = gsk_secure_soc_init(RPGAPI_tls_session);
   endif;
   if return_code <> GSK_OK;
      RPGAPI_log(RPGAPI_LOG_WARN : 'TLS handshake failed: ' +
                 %str(gsk_strerror(return_code)) + ' (GSKit ' +
                 %char(return_code) + '); connection closed');
      RPGAPI_tlsClose();
      return *off;
   endif;

   if flags >= 0;
      fcntl(descriptor : F_SETFL : %bitor(flags : O_NONBLOCK));
   endif;
   return *on;
end-proc;


   // ends the TLS session of the connection, if there is one
dcl-proc RPGAPI_tlsClose;
   if RPGAPI_tls_session <> *null;
      gsk_secure_soc_close(RPGAPI_tls_session);
      RPGAPI_tls_session = *null;
   endif;
end-proc;


   // reads what has arrived on the connection, decrypted with TLS: the
   // number of bytes, 0 when the client closed it, RPGAPI_WOULD_BLOCK when
   // nothing has arrived, -1 when it failed
dcl-proc RPGAPI_connectionRead;
   dcl-pi *n int(10:0);
      buffer pointer value;
      size int(10:0) value;
   end-pi;
   dcl-s count int(10:0) inz(0);
   dcl-s return_code int(10:0);
   dcl-s error_number int(10:0) based(error_number_ptr);

   if RPGAPI_tls_session <> *null;
      return_code = gsk_secure_soc_read(RPGAPI_tls_session : buffer : size :
                                        count);
      select;
      when return_code = GSK_OK;
         return count;
      when return_code = GSK_WOULD_BLOCK;
         return RPGAPI_WOULD_BLOCK;
      when return_code = GSK_ERROR_SOCKET_CLOSED;
         return 0;
      other;
         return -1;
      endsl;
   endif;

   count = read(RPGAPI_connection : buffer : size);
   if count < 0;
      error_number_ptr = get_errno();
      if error_number = EWOULDBLOCK;
         return RPGAPI_WOULD_BLOCK;
      endif;
      return -1;
   endif;
   return count;
end-proc;


   // writes what it can of length bytes to the connection, encrypted with
   // TLS: how many, RPGAPI_WOULD_BLOCK when none fit right now, -1 when it
   // failed. With TLS, after RPGAPI_WOULD_BLOCK the same bytes have to be
   // written again
dcl-proc RPGAPI_connectionWrite;
   dcl-pi *n int(10:0);
      data pointer value;
      length int(10:0) value;
   end-pi;
   dcl-s count int(10:0) inz(0);
   dcl-s return_code int(10:0);
   dcl-s error_number int(10:0) based(error_number_ptr);

   if RPGAPI_tls_session <> *null;
      return_code = gsk_secure_soc_write(RPGAPI_tls_session : data : length :
                                         count);
      select;
      when return_code = GSK_OK;
         return count;
      when return_code = GSK_WOULD_BLOCK;
         return RPGAPI_WOULD_BLOCK;
      other;
         return -1;
      endsl;
   endif;

   count = write(RPGAPI_connection : data : length);
   if count < 0;
      error_number_ptr = get_errno();
      if error_number = EWOULDBLOCK;
         return RPGAPI_WOULD_BLOCK;
      endif;
      return -1;
   endif;
   return count;
end-proc;


   // whether messages of this level are logged, to skip building ones that
   // are not
dcl-proc RPGAPI_logging;
   dcl-pi *n ind;
      level int(10:0) const;
   end-pi;

   return level > RPGAPI_LOG_OFF and level <= RPGAPI_log_level;
end-proc;


   // writes a message to the job log, as an informational message
   // RPGAPI <LEVEL>: text, when the app's log level includes level
dcl-proc RPGAPI_log;
   dcl-pi *n;
      level int(10:0) const;
      text varchar(1000) const;
   end-pi;
   dcl-s message varchar(512);
   dcl-s message_key char(4);
   dcl-s error_code char(8) inz(*allx'00');

   if not RPGAPI_logging(level);
      return;
   endif;
   select;
   when level = RPGAPI_LOG_ERROR;
      message = 'RPGAPI ERROR: ';
   when level = RPGAPI_LOG_WARN;
      message = 'RPGAPI WARN: ';
   when level = RPGAPI_LOG_INFO;
      message = 'RPGAPI INFO: ';
   other;
      message = 'RPGAPI DEBUG: ';
   endsl;
   if RPGAPI_in_request;
      message = %trimr(message : ': ') + ' #' +
                %char(RPGAPI_request_number) + ': ';
   endif;
   message += %subst(text : 1 : %min(%len(text) : 512 - %len(message)));

      // logging never ends a request: a message that cannot be sent is lost
   monitor;
      send_program_message( 'CPF9897' : 'QCPFMSG   *LIBL' : message :
                            %len(message) : '*INFO' : '*' : 1 :
                            message_key : error_code );
   on-error;
   endmon;
end-proc;


   // the request line and headers, at DEBUG. Values that carry credentials
   // are left out
dcl-proc RPGAPI_logRequestHeaders;
   dcl-pi *n;
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s index int(10:0);
   dcl-s name varchar(50);
   dcl-s value varchar(1024);

   RPGAPI_log(RPGAPI_LOG_DEBUG : 'request ' + %trim(request.method) + ' ' +
              %trim(request.route) +
              %trim(RPGAPI_choose(request.query_string <> '' :
                    '?' + %trim(request.query_string) : '')) + ' ' +
              %trim(request.protocol));
   for index = 1 to %elem(request.headers);
      if request.headers(index).name = *blanks;
         leave;
      endif;
      name = %trim(request.headers(index).name);
      value = request.headers(index).value;
      if %upper(name) = 'AUTHORIZATION' or %upper(name) = 'COOKIE' or
         %upper(name) = 'PROXY-AUTHORIZATION';
         value = '(not logged)';
      endif;
      RPGAPI_log(RPGAPI_LOG_DEBUG : 'header ' + name + ': ' + value);
   endfor;
end-proc;


   // yes when condition is on, otherwise no
dcl-proc RPGAPI_choose;
   dcl-pi *n varchar(1000);
      condition ind const;
      yes varchar(1000) const;
      no varchar(1000) const;
   end-pi;

   if condition;
      return yes;
   endif;
   return no;
end-proc;


   // how the server serves: TLS and how, or plain HTTP
dcl-proc RPGAPI_tlsDescription;
   dcl-pi *n varchar(1200);
   end-pi;

   select;
   when RPGAPI_tls = RPGAPI_TLS_APPLICATION;
      return 'HTTPS with application ID ' + RPGAPI_tls_app_id;
   when RPGAPI_tls = RPGAPI_TLS_KEYSTORE;
      return 'HTTPS with keystore ' + RPGAPI_tls_keystore_path +
             %trim(RPGAPI_choose(RPGAPI_tls_label <> '' :
                   ' label ' + RPGAPI_tls_label : ''));
   other;
      return 'plain HTTP';
   endsl;
end-proc;


dcl-proc RPGAPI_tlsDescriptionShort;
   dcl-pi *n varchar(20);
   end-pi;

   if RPGAPI_tls_session <> *null;
      return ', TLS handshake done';
   endif;
   return '';
end-proc;


   // the exception a failed procedure ended with, from this procedure's
   // caller's messages, as message ID and text: MCH1211 Attempt made to
   // divide by zero for fixed point operation. It stays in the job log
dcl-proc RPGAPI_lastException;
   dcl-pi *n varchar(400);
   end-pi;
   dcl-ds received len(4096) qualified;
      bytes_returned int(10:0) pos(1);
      message_id char(7) pos(13);
      data_length int(10:0) pos(153);
      text_length int(10:0) pos(161);
   end-ds;
   dcl-s error_code char(8) inz(*allx'00');
   dcl-s text varchar(400);

   monitor;
         // counter 1: the messages of RPGAPI_start, where the exception
         // ended up; received with *SAME, so it stays as it is
      receive_program_message(received : %size(received) : 'RCVM0200' :
                              '*' : 1 : '*EXCP' : ' ' : 0 : '*SAME' :
                              error_code);
      if received.bytes_returned = 0 or received.message_id = *blanks;
         return 'no exception message found';
      endif;
      text = received.message_id;
      if received.text_length > 0 and
         176 + received.data_length + received.text_length <= %size(received);
         text += ' ' + %subst(received : 177 + received.data_length :
                              %min(received.text_length : 380));
      endif;
      return text;
   on-error;
      return 'its exception message could not be read';
   endmon;
end-proc;


   // what happens after a procedure failed, for the log
dcl-proc RPGAPI_failureOutcome;
   dcl-pi *n varchar(100);
   end-pi;

   if RPGAPI_stream = RPGAPI_STREAM_NONE;
      return 'answered 500';
   endif;
   return 'its streamed response was cut off';
end-proc;


   // closes the client's connection. When it may still be sending a body
   // that was not read, stop sending, then read and drop what arrives for a
   // moment first: closing with unread data resets the connection, and the
   // client can lose the response
dcl-proc RPGAPI_closeClient;
   dcl-ds poll_fds likeds(PollFd) dim(1);
   dcl-s until timestamp;

   if RPGAPI_logging(RPGAPI_LOG_INFO) and
      (RPGAPI_response_status > 0 or RPGAPI_request_method <> '');
      RPGAPI_log(RPGAPI_LOG_INFO :
         %trim(RPGAPI_choose(RPGAPI_request_method <> '' :
                             %trim(RPGAPI_request_method) : '-')) + ' ' +
         %trim(RPGAPI_choose(RPGAPI_request_route <> '' :
                             RPGAPI_request_route : '-')) + ' -> ' +
         %trim(RPGAPI_choose(RPGAPI_response_status > 0 :
                             %char(RPGAPI_response_status) : 'no response')) +
         ', ' + %char(RPGAPI_bytes_sent) + ' bytes, ' +
         %char(%div(%diff(%timestamp() : RPGAPI_request_started : *mseconds) :
                    1000)) + ' ms');
   endif;
   RPGAPI_request_method = '';
   RPGAPI_response_status = 0;
   RPGAPI_in_request = *off;

   RPGAPI_tlsClose();
   if RPGAPI_linger or (RPGAPI_body_streamed and not RPGAPI_body_done);
      shutdown(RPGAPI_connection : SHUT_WR);
      until = %timestamp() + %seconds(2);
      dow %timestamp() < until;
         poll_fds(1).fd = RPGAPI_connection;
         poll_fds(1).events = POLLIN;
         poll_fds(1).revents = 0;
         if poll(poll_fds : 1 : 200) <= 0;
            leave;
         endif;
         if read(RPGAPI_connection : %addr(RPGAPI_input) :
                 %size(RPGAPI_input)) <= 0;
            leave;
         endif;
      enddo;
   endif;
   RPGAPI_linger = *off;
   close_port(RPGAPI_connection);
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
   dcl-s host varchar(1024);
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

      // parts is split into three times: %split only fills as many elements
      // as it returns, so clear what the split before left in the others
   clear parts;
   parts = %split(request.query_string : '&');
   for index = 1 to %elem(parts) by 1;
      if parts(index) <> *blanks;
            // split on the first '=' only, a value may contain more of them.
            // Names and values are decoded after splitting, so an encoded
            // & or = (%26, %3D) stays part of them
         position = %scan('=' : parts(index));
         if position = 0;
            request.query_params(index).name =
                                    RPGAPI_urlDecode(%trim(parts(index)) : *on);
         else;
            request.query_params(index).name = RPGAPI_urlDecode(
                        %trim(%subst(parts(index) : 1 : position - 1)) : *on);
            if position < %len(%trimr(parts(index)));
               request.query_params(index).value = RPGAPI_urlDecode(
                        %trim(%subst(parts(index) : position + 1)) : *on);
            endif;
         endif;
      else;
         index = %elem(parts) + 1;
      endif;
   endfor;

   start = stop + 1;
   stop = %scan(RPGAPI_DBL_CRLF : raw_request);
      // a request can have no headers at all (HTTP/1.0): then the blank line
      // starts at the CR LF that ends the request line
   clear raw_headers;
   if stop > start;
      raw_headers = %subst(raw_request : start : stop - start);
   endif;
   clear parts;
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

      // the host the client asked for, as Express's req.hostname: the Host
      // header without its port. An IPv6 address is in brackets: [::1]:3000
   host = RPGAPI_getHeader(request : 'Host');
   if %len(host) > 0 and %subst(host : 1 : 1) = '[';
      position = %scan(']' : host);
   else;
      position = %scan(':' : host);
      if position > 0;
         position -= 1;
      endif;
   endif;
   if position > 0;
      request.hostname = %subst(host : 1 : position);
   else;
      request.hostname = host;
   endif;

      // the body is everything after the blank line, exactly as sent
   start = stop + %len(RPGAPI_DBL_CRLF);
   if start <= %len(raw_request);
      request.body = %subst(raw_request : start);
   endif;

   return request;
end-proc;
        


   // decodes %XX escapes in a URL part, and + as a space when plus_is_space
   // (query strings; not paths). The escapes are UTF-8 bytes: the text goes
   // back to UTF-8, is decoded there, and comes back to the job's CCSID. An
   // escape that is not two hex digits, or bytes that are not UTF-8, are left
   // as they were sent
dcl-proc RPGAPI_urlDecode;
   dcl-pi *n varchar(1024);
      value varchar(1024) const;
      plus_is_space ind const;
   end-pi;
   dcl-s utf8 varchar(3072);
   dcl-s decoded varchar(3072);
   dcl-s index int(10:0);
   dcl-s high int(10:0);
   dcl-s low int(10:0);
   dcl-ds one_byte;
      character char(1);
      number uns(3:0) overlay(character);
   end-ds;

   if %scan('%' : value) = 0 and
      (not plus_is_space or %scan('+' : value) = 0);
      return value;
   endif;

   monitor;
      utf8 = RPGAPI_convert(value : RPGAPI_JOB_CCSID : RPGAPI_UTF8);
      index = 1;
      dow index <= %len(utf8);
         character = %subst(utf8 : index : 1);
            // ASCII %, followed by two hex digits
         if number = 37 and index + 2 <= %len(utf8);
            high = RPGAPI_hexValue(%subst(utf8 : index + 1 : 1));
            low = RPGAPI_hexValue(%subst(utf8 : index + 2 : 1));
            if high >= 0 and low >= 0;
               number = high * 16 + low;
               decoded += character;
               index += 3;
               iter;
            endif;
         endif;
            // ASCII + as an ASCII space
         if plus_is_space and number = 43;
            number = 32;
         endif;
         decoded += character;
         index += 1;
      enddo;
      return RPGAPI_convert(decoded : RPGAPI_UTF8 : RPGAPI_JOB_CCSID);
   on-error;
      return value;
   endmon;
end-proc;


   // the value of an ASCII hex digit, -1 when it is not one
dcl-proc RPGAPI_hexValue;
   dcl-pi *n int(10:0);
      ascii char(1) const;
   end-pi;
   dcl-ds one_byte;
      character char(1);
      number uns(3:0) overlay(character);
   end-ds;

   character = ascii;
   select;
   when number >= 48 and number <= 57;
      return number - 48;
   when number >= 65 and number <= 70;
      return number - 55;
   when number >= 97 and number <= 102;
      return number - 87;
   other;
      return -1;
   endsl;
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
               // matched on the path as sent, handed over decoded
            found(param_count).value = RPGAPI_urlDecode(path_parts(index) : *off);
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
   RPGAPI_closeClient();
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

   RPGAPI_response_status = response.status;
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
         %upper(%trim(response.headers(index).name)) = 'TRANSFER-ENCODING' or
         %trim(response.headers(index).name) = '-';
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

   dow length > 0 and not RPGAPI_connection_failed;
      written = RPGAPI_connectionWrite(data : length);
      if written > 0;
         RPGAPI_bytes_sent += written;
         data += written;
         length -= written;
         iter;
      endif;

      if written = RPGAPI_WOULD_BLOCK;
         poll_fds(1).fd = RPGAPI_connection;
         poll_fds(1).events = POLLOUT;
         poll_fds(1).revents = 0;
         if poll(poll_fds : 1 : RPGAPI_WRITE_TIMEOUT * 1000) > 0;
            iter;
         endif;
         RPGAPI_log(RPGAPI_LOG_WARN : 'the client took no response data for ' +
                    %char(RPGAPI_WRITE_TIMEOUT) + 's after ' +
                    %char(RPGAPI_bytes_sent) + ' bytes: connection given up');
      else;
         RPGAPI_log(RPGAPI_LOG_WARN : 'the connection failed after ' +
                    %char(RPGAPI_bytes_sent) + ' bytes of the response');
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

      // an HTTP/1.0 client cannot take chunks: the body ends where the
      // connection does, which it always does after a response
   if %parms >= 2;
      RPGAPI_beginStream(response : length);
   elseif %trim(RPGAPI_request_protocol) = 'HTTP/1.0';
      RPGAPI_beginStream(response : RPGAPI_UNTIL_CLOSE);
   else;
      RPGAPI_beginStream(response : RPGAPI_CHUNKED);
   endif;
end-proc;


   // sends the status line and headers of a streamed response. framing is a
   // Content-Length, RPGAPI_CHUNKED, or RPGAPI_UNTIL_CLOSE when the body ends
   // with the connection or there is none (304)
dcl-proc RPGAPI_beginStream;
   dcl-pi *n;
      response likeds(RPGAPI_Response) const;
      framing int(10:0) const;
   end-pi;
   dcl-ds head_response likeds(RPGAPI_Response);
   dcl-s head varchar(96000);

   head_response = response;
   if head_response.status = 0;
      head_response.status = HTTP_OK;
   endif;

   select;
   when framing = RPGAPI_CHUNKED;
      RPGAPI_stream = RPGAPI_STREAM_CHUNKED;
   when framing = RPGAPI_UNTIL_CLOSE;
      RPGAPI_stream = RPGAPI_STREAM_UNTIL_CLOSE;
   other;
      RPGAPI_stream = RPGAPI_STREAM_LENGTH;
   endsl;

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
   RPGAPI_closeClient();
end-proc;


dcl-proc RPGAPI_sendFile export;
   dcl-pi *n ind;
      response likeds(RPGAPI_Response) const;
      path varchar(1024) const;
   end-pi;
   dcl-ds file_response likeds(RPGAPI_Response);
   dcl-ds info likeds(FileStat);
   dcl-s descriptor int(10:0);
   dcl-s size int(10:0);
   dcl-s buffer char(65536);
   dcl-s count int(10:0);
   dcl-s remaining int(10:0);
   dcl-s extension varchar(10);
   dcl-s dot int(10:0);
   dcl-s etag varchar(40);
   dcl-s last_modified varchar(40);
   dcl-s condition varchar(1024);
   dcl-s since int(10:0);
   dcl-s first int(10:0);
   dcl-s last int(10:0);
   dcl-s range_result int(10:0) inz(0);

      // no stepping out of the directory a procedure builds the path in
   if %scan('/../' : '/' + path + '/') > 0;
      RPGAPI_log(RPGAPI_LOG_DEBUG : 'sendFile refused ' + path +
                 ': it has a .. segment');
      return *off;
   endif;

   descriptor = open(%trim(path) : O_RDONLY);
   if descriptor < 0;
      RPGAPI_log(RPGAPI_LOG_DEBUG : 'sendFile cannot open ' + path);
      return *off;
   endif;
   if fstat(descriptor : info) < 0;
      close_port(descriptor);
      return *off;
   endif;
   size = info.size;

      // the validators: a weak ETag from the size and the time it changed,
      // as Express makes it, and that time as an HTTP date
   etag = 'W/"' + RPGAPI_hex(size) + '-' + RPGAPI_hex(info.modified) + '"';
   last_modified = RPGAPI_httpDate(info.modified);

   file_response = response;
   if file_response.status = 0;
      file_response.status = HTTP_OK;
   endif;
   if not RPGAPI_hasHeader(file_response : 'Content-Type');
      dot = %scanr('.' : path);
      if dot > 0 and dot < %len(path) and %len(path) - dot <= 8;
         extension = %lower(%subst(path : dot + 1));
      endif;
      RPGAPI_setHeader(file_response : 'Content-Type' :
                       RPGAPI_contentType(extension));
   endif;
   if not RPGAPI_hasHeader(file_response : 'Cache-Control');
      RPGAPI_setHeader(file_response : 'Cache-Control' : 'public, max-age=0');
   endif;
   RPGAPI_setHeader(file_response : 'Accept-Ranges' : 'bytes');
   RPGAPI_setHeader(file_response : 'Last-Modified' : last_modified);
   RPGAPI_setHeader(file_response : 'ETag' : etag);

      // conditions and ranges only apply to a plain GET of the file
   if file_response.status = HTTP_OK and
      %trim(RPGAPI_request_method) = HTTP_GET;

         // the client's copy is still current: If-None-Match wins over
         // If-Modified-Since
      condition = RPGAPI_requestHeader('If-None-Match');
      if condition <> '';
         if condition = '*' or
            %scan(RPGAPI_opaqueTag(etag) : condition) > 0;
            file_response.status = HTTP_NOT_MODIFIED;
         endif;
      else;
         since = RPGAPI_parseHttpDate(RPGAPI_requestHeader('If-Modified-Since'));
         if since >= 0 and info.modified <= since;
            file_response.status = HTTP_NOT_MODIFIED;
         endif;
      endif;

         // a part of the file, unless If-Range says the client's copy is
         // of an older version
      if file_response.status = HTTP_OK;
         condition = RPGAPI_requestHeader('If-Range');
         if condition = '' or
            condition = etag or
            (%scan('"' : condition) = 0 and
             RPGAPI_parseHttpDate(condition) >= info.modified);
            range_result = RPGAPI_parseRange(
                              RPGAPI_requestHeader('Range') : size :
                              first : last);
         endif;
      endif;
   endif;

   RPGAPI_log(RPGAPI_LOG_DEBUG : 'sendFile ' + path + ' (' + %char(size) +
              ' bytes): ' + %char(file_response.status) +
              %trim(RPGAPI_choose(range_result > 0 : ' range ' + %char(first) +
                    '-' + %char(last) : '')) +
              %trim(RPGAPI_choose(range_result < 0 : ' range outside it' : '')));
   select;
   when file_response.status = HTTP_NOT_MODIFIED;
      close_port(descriptor);
         // no body, and no Content-Length or Content-Type for it
      RPGAPI_removeHeader(file_response : 'Content-Type');
      RPGAPI_beginStream(file_response : RPGAPI_UNTIL_CLOSE);
      RPGAPI_endResponse();
      return *on;

   when range_result < 0;
      close_port(descriptor);
      file_response.status = HTTP_RANGE_NOT_SATISFIABLE;
      RPGAPI_setHeader(file_response : 'Content-Range' :
                       'bytes */' + %char(size));
      RPGAPI_beginStream(file_response : 0);
      RPGAPI_endResponse();
      return *on;

   when range_result > 0;
      file_response.status = HTTP_PARTIAL_CONTENT;
      RPGAPI_setHeader(file_response : 'Content-Range' :
                       'bytes ' + %char(first) + '-' + %char(last) +
                       '/' + %char(size));
      if lseek(descriptor : first : SEEK_SET) < 0;
         close_port(descriptor);
         return *off;
      endif;
      remaining = last - first + 1;

   other;
      remaining = size;
   endsl;

   RPGAPI_beginStream(file_response : remaining);
   dow remaining > 0;
      count = read(descriptor : %addr(buffer) : %min(remaining : %size(buffer)));
      if count <= 0;
         leave;
      endif;
      RPGAPI_writeBytes(%addr(buffer) : count);
      remaining -= count;
   enddo;
   close_port(descriptor);
   RPGAPI_endResponse();
   return *on;
end-proc;


   // parses Range: bytes=first-last, first- or -suffix against a file of
   // size bytes into first and last. 1: a range to send; -1: a range outside
   // the file (416); 0: send the whole file, when there is no Range, it is
   // not one this understands, or it asks for several ranges
dcl-proc RPGAPI_parseRange;
   dcl-pi *n int(10:0);
      range varchar(1024) const;
      size int(10:0) const;
      first int(10:0);
      last int(10:0);
   end-pi;
   dcl-s spec varchar(1024);
   dcl-s dash int(10:0);
   dcl-s from_text varchar(20);
   dcl-s to_text varchar(20);
   dcl-s from_value int(20:0);
   dcl-s to_value int(20:0);

   if %len(range) < 7 or %lower(%subst(range : 1 : 6)) <> 'bytes=' or
      %scan(',' : range) > 0;
      return 0;
   endif;
   spec = %trim(%subst(range : 7));
   dash = %scan('-' : spec);
   if dash = 0;
      return 0;
   endif;
   from_text = %trim(%subst(spec : 1 : dash - 1));
   if dash < %len(spec);
      to_text = %trim(%subst(spec : dash + 1));
   endif;
   if (from_text <> '' and %check('0123456789' : from_text) > 0) or
      (to_text <> '' and %check('0123456789' : to_text) > 0) or
      (from_text = '' and to_text = '') or
      %len(from_text) > 18 or %len(to_text) > 18;
      return 0;
   endif;

   if from_text = '';
         // -suffix: the last suffix bytes
      to_value = %int(to_text);
      if to_value = 0 or size = 0;
         return -1;
      endif;
      first = size - %min(to_value : size);
      last = size - 1;
      return 1;
   endif;

   from_value = %int(from_text);
   if to_text = '';
      to_value = size - 1;
   else;
      to_value = %int(to_text);
      if to_value < from_value;
         return 0;
      endif;
   endif;
   if from_value >= size;
      return -1;
   endif;
   first = from_value;
   last = %min(to_value : size - 1);
   return 1;
end-proc;


   // the value of a header of the request being handled, '' when there is
   // none. The name is matched in any case
dcl-proc RPGAPI_requestHeader;
   dcl-pi *n varchar(1024);
      name varchar(50) const;
   end-pi;
   dcl-s start int(10:0);
   dcl-s stop int(10:0);

   start = %scan(RPGAPI_CRLF + %upper(name) + ':' :
                 RPGAPI_request_headers_upper);
   if start = 0;
      return '';
   endif;
   start += %len(RPGAPI_CRLF) + %len(name) + 1;
   stop = %scan(RPGAPI_CRLF : RPGAPI_request_headers : start);
   if stop = 0;
      stop = %len(RPGAPI_request_headers) + 1;
   endif;
   return %trim(%subst(RPGAPI_request_headers : start : stop - start));
end-proc;


dcl-proc RPGAPI_hasHeader;
   dcl-pi *n ind;
      response likeds(RPGAPI_Response) const;
      name varchar(50) const;
   end-pi;
   dcl-s index int(10:0);

   for index = 1 to %elem(response.headers);
      if response.headers(index).name = *blanks;
         leave;
      endif;
      if %upper(%trim(response.headers(index).name)) = %upper(name);
         return *on;
      endif;
   endfor;
   return *off;
end-proc;


dcl-proc RPGAPI_removeHeader;
   dcl-pi *n;
      response likeds(RPGAPI_Response);
      name varchar(50) const;
   end-pi;
   dcl-s index int(10:0);

   for index = 1 to %elem(response.headers);
      if response.headers(index).name = *blanks;
         leave;
      endif;
      if %upper(%trim(response.headers(index).name)) = %upper(name);
            // blank the name out, keeping the headers after it
         response.headers(index).name = '-';
         response.headers(index).value = '';
      endif;
   endfor;
end-proc;


   // an ETag without its W/ weak marker, for If-None-Match, which compares
   // tags weakly
dcl-proc RPGAPI_opaqueTag;
   dcl-pi *n varchar(40);
      tag varchar(40) const;
   end-pi;

   if %len(tag) > 2 and %subst(tag : 1 : 2) = 'W/';
      return %subst(tag : 3);
   endif;
   return tag;
end-proc;


   // a number in upper case hex
dcl-proc RPGAPI_hex;
   dcl-pi *n varchar(16);
      value int(10:0) value;
   end-pi;
   dcl-s text varchar(16);
   dcl-s number int(20:0);
   dcl-c DIGITS '0123456789ABCDEF';

   number = value;
   if number < 0;
      number += 4294967296;
   endif;
   dou number = 0;
      text = %subst(DIGITS : %rem(number : 16) + 1 : 1) + text;
      number = %div(number : 16);
   enddo;
   return text;
end-proc;


   // seconds since 1970-01-01 UTC as an HTTP date:
   // Sun, 06 Nov 1994 08:49:37 GMT
dcl-proc RPGAPI_httpDate;
   dcl-pi *n varchar(40);
      seconds int(10:0) const;
   end-pi;
   dcl-s moment timestamp;
   dcl-s days int(10:0);
   dcl-c DAYS_OF_WEEK 'SunMonTueWedThuFriSat';
   dcl-c MONTHS 'JanFebMarAprMayJunJulAugSepOctNovDec';

   moment = z'1970-01-01-00.00.00.000000' + %seconds(seconds);
   days = %diff(%date(moment) : d'1970-01-01' : *days);
      // 1970-01-01 was a Thursday
   return %subst(DAYS_OF_WEEK : %rem(days + 4 : 7) * 3 + 1 : 3) + ', ' +
          %editc(%dec(%subdt(moment : *days) : 2 : 0) : 'X') + ' ' +
          %subst(MONTHS : (%subdt(moment : *months) - 1) * 3 + 1 : 3) + ' ' +
          %char(%subdt(moment : *years)) + ' ' +
          %editc(%dec(%subdt(moment : *hours) : 2 : 0) : 'X') + ':' +
          %editc(%dec(%subdt(moment : *minutes) : 2 : 0) : 'X') + ':' +
          %editc(%dec(%subdt(moment : *seconds) : 2 : 0) : 'X') + ' GMT';
end-proc;


   // an HTTP date (Sun, 06 Nov 1994 08:49:37 GMT) as seconds since
   // 1970-01-01 UTC, or -1 when it is not one
dcl-proc RPGAPI_parseHttpDate;
   dcl-pi *n int(10:0);
      text varchar(1024) const;
   end-pi;
   dcl-s value varchar(40);
   dcl-s month int(10:0);
   dcl-s moment timestamp;
   dcl-c MONTHS 'JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC';

   value = %upper(%trim(text));
   if %len(value) <> 29 or %subst(value : 26 : 4) <> ' GMT';
      return -1;
   endif;
   month = %scan(%subst(value : 9 : 3) : MONTHS);
   if month = 0 or %rem(month - 1 : 3) <> 0;
      return -1;
   endif;
   month = %div(month - 1 : 3) + 1;

   monitor;
      moment = %timestamp(%subst(value : 13 : 4) + '-' +
                          %editc(%dec(month : 2 : 0) : 'X') + '-' +
                          %subst(value : 6 : 2) + '-' +
                          %subst(value : 18 : 2) + '.' +
                          %subst(value : 21 : 2) + '.' +
                          %subst(value : 24 : 2) + '.000000');
      return %diff(moment : z'1970-01-01-00.00.00.000000' : *seconds);
   on-error;
      return -1;
   endmon;
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
   HTTP_messages(15).status = HTTP_PARTIAL_CONTENT;
   HTTP_messages(15).text = 'Partial Content';
   HTTP_messages(16).status = HTTP_NOT_MODIFIED;
   HTTP_messages(16).text = 'Not Modified';
   HTTP_messages(17).status = HTTP_RANGE_NOT_SATISFIABLE;
   HTTP_messages(17).text = 'Range Not Satisfiable';
   HTTP_messages(18).status = HTTP_REQUEST_TIMEOUT;
   HTTP_messages(18).text = 'Request Timeout';
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
   RPGAPI_log(RPGAPI_LOG_ERROR : error_text);

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