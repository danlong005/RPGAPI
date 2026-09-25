**free

ctl-opt option(*nodebugio:*srcstmt) nomain;
/include 'rpgapi_h.rpgle'
/include 'socket_h.rpgle'

   // HTTP text is UTF-8 on the wire and the job's CCSID in the program
dcl-c RPGAPI_UTF8 1208;
dcl-c RPGAPI_JOB_CCSID 0;

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
   end-pi;
   dcl-s index int(10:0) inz;
   dcl-s index2 int(10:0) inz;
   dcl-s route_found ind inz;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds request likeds(RPGAPI_Request) inz;
   dcl-s middleware_completed ind;

   if config.port = 0 and %parms < 2;
      config.port = 3000;
   elseif %parms = 2;
      config.port = port;
   endif;

   RPGAPI_setup(config);

   dow 1 = 1;
      monitor;
         clear request;
         request = RPGAPI_acceptRequest(config);

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



dcl-proc RPGAPI_acceptRequest export;
   dcl-pi *n likeds(RPGAPI_Request);
      config likeds(RPGAPI_App);
   end-pi;
   dcl-ds socket_address likeds(socketaddr);
      // RPGAPI_parse takes at most 32000 bytes, so that is all that is read
   dcl-s data char(32000);
   dcl-s return_code int(10:0) inz(0);
   dcl-s received int(10:0) inz(0);
   dcl-s header_end int(10:0) inz(0);
   dcl-s expected int(10:0) inz(0);
   dcl-ds request likeds(RPGAPI_Request);
   dcl-s text varchar(32000);

   clear socket_address;
   socket_address.sin_family = AF_INET;
   socket_address.sin_port = config.port;
   socket_address.sin_addr = INADDR_ANY;
   config.return_socket_descriptor = accept( config.socket_descriptor :
                                  %addr(socket_address) :
                                  socketaddrlena );

      // a request can arrive in several pieces: read until the blank line
      // after the headers, then until Content-Length bytes of body are in.
      // Stop early if the client closes the connection or the buffer is full
   dow received < %size(data);
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

      // nothing arrived: the client closed or the read failed
   if received <= 0;
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
   dcl-s data char(32766);
   dcl-s body varchar(32000);
   dcl-s return_code int(10:0) inz(0);
   dcl-s index int(10:0) inz;
   dcl-s head varchar(96000);
   dcl-s utf8_body varchar(96000);

   data = 'HTTP/1.1 ' + %char(response.status) + ' ' +
                  %trim(RPGAPI_getMessage(response.status)) + RPGAPI_CRLF;
   data = %trim(data) + 'Connection: close' + RPGAPI_CRLF;

   for index = 1 to %elem(response.headers) by 1;
      if response.headers(index).name <> *blanks;
            // the connection is always closed after the response, and the
            // Connection header saying so is sent above
         if %upper(%trim(response.headers(index).name)) = 'CONNECTION';
            iter;
         endif;

         data = %trim(data) +
                              %trim(response.headers(index).name) + ': ' +
                              %trim(response.headers(index).value) + 
                              RPGAPI_CRLF;
      else;
         index = %elem(response.headers) + 1;
      endif;
   endfor;

         // Content-Length is the size of the body alone, in UTF-8 bytes,
         // which is more than its length in EBCDIC for any character outside ASCII.
         // The CRLF that ends this header plus one more CRLF make the blank
         // line before the body
   body = %trim(response.body);
   utf8_body = RPGAPI_convert(body : RPGAPI_JOB_CCSID : RPGAPI_UTF8);
   data = %trim(data) + 'Content-Length: ' + %char(%len(utf8_body)) +
                    RPGAPI_DBL_CRLF;
   head = RPGAPI_convert(%trimr(data) : RPGAPI_JOB_CCSID : RPGAPI_UTF8);

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

   return_code = listen( config.socket_descriptor : 1 );
   if return_code < 0;
      RPGAPI_socketFailed(config : 'listen');
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