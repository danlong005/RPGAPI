**free 

/if not defined(RPGAPI_H)
/define RPGAPI_H

/include 'http_h.rpgle'

dcl-c RPGAPI_CR x'0d';
dcl-c RPGAPI_LF x'25';
dcl-c RPGAPI_CRLF x'0d25';
dcl-c RPGAPI_DBL_CRLF x'0d250d25';
dcl-c RPGAPI_GLOBAL_MIDDLEWARE '*';

dcl-ds RPGAPI_header_ds qualified template;
   name char(50);
   value varchar(1024);
end-ds;

dcl-ds RPGAPI_param_ds qualified template;
   name char(50);
   value varchar(1024);
end-ds;

dcl-ds RPGAPI_route_ds qualified template;
   method char(10);
   url varchar(32000);
   procedure pointer(*proc);
end-ds;

dcl-ds RPGAPI_Request qualified template;
   body varchar(32000);
   headers likeds(RPGAPI_header_ds) dim(100);
   hostname char(250);
   method char(10);
   params likeds(RPGAPI_param_ds) dim(100);
   protocol char(8);
   query_params likeds(RPGAPI_param_ds) dim(100);
   query_string char(1024);
   route char(250);
      // the header lines as sent (converted), each after a CR LF: where
      // RPGAPI_getHeader finds values longer than headers(n).value holds
   header_text varchar(32000);
end-ds;

dcl-ds RPGAPI_Response qualified template;
   body varchar(32000);
   headers likeds(RPGAPI_header_ds) dim(100);
   status int(10:0);
end-ds;

   // a part of a multipart/form-data body, from RPGAPI_nextPart
dcl-ds RPGAPI_Part qualified template;
   name varchar(256);
      // blank for a form field; the name of the file the client sent
   filename varchar(1024);
   content_type varchar(256);
end-ds;

   // the application: clear it before use. Settings left at 0 or blank get
   // their defaults when RPGAPI_start runs; the RPGAPI_set... procedures set
   // them with checks
dcl-ds RPGAPI_App qualified template;
   port int(10:0);
   socket_descriptor int(10:0);
   return_socket_descriptor int(10:0);
   routes likeds(RPGAPI_route_ds) dim(250);
   middlewares likeds(RPGAPI_route_ds) dim(100);
      // jobs serving the port: 1
   jobs int(10:0);
      // RPGAPI_LOG_...: RPGAPI_LOG_OFF
   log_level int(10:0);
      // largest body read into memory, bytes: 1MB
   max_request_size int(10:0);
      // largest body streamed from the connection, bytes: 0, not allowed
   max_upload_size int(10:0);
      // seconds a client has to send its request, or to take response data: 30
   read_timeout int(10:0);
   write_timeout int(10:0);
      // HTTPS: a DCM application ID, or a certificate store file with its
      // password and certificate label. Blank: plain HTTP
   tls_application_id varchar(100);
   tls_keystore varchar(1024);
   tls_password varchar(128);
   tls_label varchar(128);
      // CORS: origins allowed to call the app from a browser, separated by
      // spaces or commas, or '*' for any. Blank: no CORS headers
   cors_origins varchar(2000);
      // whether browsers may send cookies and credentials along
   cors_credentials ind;
      // seconds a browser may cache a preflight answer: not sent
   cors_max_age int(10:0);
      // request headers allowed: blank, the ones the browser asks for
   cors_allow_headers varchar(1000);
      // response headers scripts may read beyond the simple ones
   cors_expose_headers varchar(1000);
end-ds;

   // log levels, for RPGAPI_setLogLevel: each also logs the levels above it.
   // Messages go to the job log of the job serving the request
dcl-c RPGAPI_LOG_OFF 0;
dcl-c RPGAPI_LOG_ERROR 1;
dcl-c RPGAPI_LOG_WARN 2;
dcl-c RPGAPI_LOG_INFO 3;
dcl-c RPGAPI_LOG_DEBUG 4;

dcl-s RPGAPI_callback_ptr pointer(*proc);
dcl-pr RPGAPI_callBack extproc(RPGAPI_callback_ptr) likeds(RPGAPI_Response);
   request likeds(RPGAPI_Request) const;
end-pr;

dcl-s RPGAPI_mwCallback_ptr pointer(*proc);
dcl-pr RPGAPI_mwCallback ind extproc(RPGAPI_mwCallback_ptr);
   request likeds(RPGAPI_Request) const;
   response likeds(RPGAPI_Response);
end-pr;

dcl-pr RPGAPI_start;
   config likeds(RPGAPI_App);
   port int(10:0) options(*nopass) const;
   workers int(10:0) options(*nopass) const;
end-pr;

dcl-pr RPGAPI_stop;
   config likeds(RPGAPI_App) const;
end-pr;

dcl-pr RPGAPI_acceptRequest likeds(RPGAPI_Request);
   config likeds(RPGAPI_App);
end-pr;

dcl-pr RPGAPI_parse likeds(RPGAPI_Request);
   raw_request varchar(32000) const;
end-pr;

dcl-pr RPGAPI_getParam varchar(1024);
   request likeds(RPGAPI_Request) const;
   param char(50) const;
end-pr;

dcl-pr RPGAPI_getQueryParam varchar(1024);
   request likeds(RPGAPI_Request) const;
   param char(50) const;
end-pr;

dcl-pr RPGAPI_getHeader varchar(32000);
   request likeds(RPGAPI_Request) const;
   header char(50) const;
end-pr;

dcl-pr RPGAPI_setHeader;
   response likeds(RPGAPI_Response);
   header_name char(50) const;
   header_value varchar(1024) const;
end-pr;

dcl-pr RPGAPI_routeMatches ind;
   route likeds(RPGAPI_route_ds);
   request likeds(RPGAPI_Request);
end-pr;

dcl-pr RPGAPI_mwMatches ind;
   route likeds(RPGAPI_route_ds);
   request likeds(RPGAPI_Request);
end-pr;

dcl-pr RPGAPI_sendResponse;
   config likeds(RPGAPI_App) const;
   response likeds(RPGAPI_Response) const;
end-pr;

dcl-pr RPGAPI_buildHead varchar(32766);
   response likeds(RPGAPI_Response) const;
   body_length int(10:0) const;
end-pr;

dcl-pr RPGAPI_setup;
   config likeds(RPGAPI_App);
end-pr;

dcl-pr RPGAPI_setRoute;
   config likeds(RPGAPI_App);
   method char(10) const;
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_setMiddleware;
   config likeds(RPGAPI_App);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_get;
   config likeds(RPGAPI_App);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_put;
   config likeds(RPGAPI_App);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_post;
   config likeds(RPGAPI_App);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_delete;
   config likeds(RPGAPI_App);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_patch;
   config likeds(RPGAPI_App);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

   // the largest request body read into memory, in bytes; 1MB unless set.
   // Larger requests are answered with 413, unless uploads that large are
   // allowed
dcl-pr RPGAPI_setMaxRequestSize;
   config likeds(RPGAPI_App);
   bytes int(10:0) const;
end-pr;

   // CORS: lets pages from these origins call the app from a browser.
   // origins are separated by spaces or commas, or '*' for any. The other
   // cors_ fields of the app fine-tune it
dcl-pr RPGAPI_setCors;
   config likeds(RPGAPI_App);
   origins varchar(2000) const;
end-pr;

   // how much to log: RPGAPI_LOG_OFF, _ERROR, _WARN, _INFO or _DEBUG
dcl-pr RPGAPI_setLogLevel;
   config likeds(RPGAPI_App);
   level int(10:0) const;
end-pr;

   // seconds a client has to send its whole request, and to take response
   // data before it is given up on (30 and 30)
dcl-pr RPGAPI_setTimeouts;
   config likeds(RPGAPI_App);
   read_seconds int(10:0) const;
   write_seconds int(10:0) const;
end-pr;

   // HTTPS: serve TLS with the certificate assigned in Digital Certificate
   // Manager to this application ID
dcl-pr RPGAPI_setTlsApplication;
   config likeds(RPGAPI_App);
   application_id varchar(100) const;
end-pr;

   // HTTPS: serve TLS with a certificate from a keystore file (such as the
   // *SYSTEM store, /QIBM/USERDATA/ICSS/CERT/SERVER/DEFAULT.KDB), its
   // password, and the label of the certificate (its default one when left
   // out)
dcl-pr RPGAPI_setTlsKeystore;
   config likeds(RPGAPI_App);
   path varchar(1024) const;
   password varchar(128) const;
   label varchar(128) const options(*nopass);
end-pr;

   // lets bodies larger than the request size limit through, up to bytes,
   // for procedures that read them with RPGAPI_readBody, readBodyBytes or
   // saveBody: they are read from the connection as the procedure asks for
   // them, not held in memory. 0 (the default) turns this off
dcl-pr RPGAPI_setMaxUploadSize;
   config likeds(RPGAPI_App);
   bytes int(10:0) const;
end-pr;

   // the size of the request body in bytes, as it was sent. -1 while it is
   // not known yet: a chunked body that is still being read
dcl-pr RPGAPI_bodyLength int(10:0);
   request likeds(RPGAPI_Request) const;
end-pr;

   // the next piece of the request body as text in the job's CCSID, '' at the
   // end. Works for any body; request.body only holds one that fits in it
dcl-pr RPGAPI_readBody varchar(32000);
   request likeds(RPGAPI_Request) const;
end-pr;

   // streaming a response, for bodies of any size: begin it with the status
   // and headers of response (its body is not used), write the body in as
   // many pieces as needed, then end it. Without length the body is sent
   // chunked; with it, as Content-Length. The response the procedure then
   // returns is not sent, and a response not ended is ended for it
dcl-pr RPGAPI_beginResponse;
   response likeds(RPGAPI_Response) const;
   length int(10:0) const options(*nopass);
end-pr;

   // text in the job's CCSID, sent as UTF-8
dcl-pr RPGAPI_write;
   text varchar(32000) const;
end-pr;

   // bytes sent as they are, for binary content
dcl-pr RPGAPI_writeBytes;
   buffer pointer value;
   length int(10:0) const;
end-pr;

dcl-pr RPGAPI_endResponse;
end-pr;

   // sends an IFS file as it is stored, with the status and headers of
   // response, a Content-Length, and a Content-Type from the file's extension
   // unless response has one. Adds Last-Modified, ETag, Accept-Ranges and
   // Cache-Control, answers conditional requests with 304 and a Range with
   // 206 (416 when it is outside the file). *off when the file cannot be
   // opened or the path contains '..': nothing is sent, so the procedure can
   // answer itself
dcl-pr RPGAPI_sendFile ind;
   response likeds(RPGAPI_Response) const;
   path varchar(1024) const;
end-pr;

   // writes the request body, unconverted, to an IFS file, replacing it.
   // *off when the file cannot be created
dcl-pr RPGAPI_saveBody ind;
   request likeds(RPGAPI_Request) const;
   path varchar(1024) const;
end-pr;

   // multipart/form-data (forms with files): moves to the next part of the
   // body and describes it in part, skipping what was not read of the one
   // before. *off when there are no more parts, or the body is not
   // multipart/form-data. A body that is not valid ends the procedure with
   // an escape message, and the request is answered with 400
dcl-pr RPGAPI_nextPart ind;
   request likeds(RPGAPI_Request) const;
   part likeds(RPGAPI_Part);
end-pr;

   // the next piece of the current part as text in the job's CCSID, '' at
   // its end
dcl-pr RPGAPI_readPart varchar(32000);
   request likeds(RPGAPI_Request) const;
end-pr;

   // copies up to size bytes of the current part, unconverted, to buffer.
   // Returns how many, 0 at its end
dcl-pr RPGAPI_readPartBytes int(10:0);
   request likeds(RPGAPI_Request) const;
   buffer pointer value;
   size int(10:0) const;
end-pr;

   // writes the rest of the current part, unconverted, to an IFS file,
   // replacing it. Returns the bytes written, -1 when the file cannot be
   // created
dcl-pr RPGAPI_savePart int(10:0);
   request likeds(RPGAPI_Request) const;
   path varchar(1024) const;
end-pr;

   // copies up to size bytes of the request body, unconverted, to buffer.
   // Returns how many, 0 at the end. For binary bodies
dcl-pr RPGAPI_readBodyBytes int(10:0);
   request likeds(RPGAPI_Request) const;
   buffer pointer value;
   size int(10:0) const;
end-pr;

dcl-pr RPGAPI_setResponse likeds(RPGAPI_Response);
   request likeds(RPGAPI_Request);
   status zoned(3:0) const;
end-pr;

dcl-pr RPGAPI_cleanString varchar(32000);
   dirty_string varchar(32000) const;
end-pr;

dcl-pr RPGAPI_getMessage char(40);
   status zoned(3:0) const;
end-pr;

dcl-pr RPGAPI_translate ExtPgm('QDCXLATE');
   length packed(5:0) const;
   data char(32766) options(*varsize);
   table char(10) const;
end-pr;

dcl-pr RPGAPI_initHttp;
end-pr;

/endif
