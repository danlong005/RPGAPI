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
end-ds;

dcl-ds RPGAPI_Response qualified template;
   body varchar(32000);
   headers likeds(RPGAPI_header_ds) dim(100);
   status int(10:0);
end-ds;

dcl-ds RPGAPI_App qualified template;
   port int(10:0);
   socket_descriptor int(10:0);
   return_socket_descriptor int(10:0);
   routes likeds(RPGAPI_route_ds) dim(250);
   middlewares likeds(RPGAPI_route_ds) dim(100);
end-ds;

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

dcl-pr RPGAPI_getHeader varchar(1024);
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

   // the largest request body accepted, in bytes; 1MB unless set. Larger
   // requests are answered with 413. Call it before RPGAPI_start
dcl-pr RPGAPI_setMaxRequestSize;
   bytes int(10:0) const;
end-pr;

   // lets bodies larger than the request size limit through, up to bytes,
   // for procedures that read them with RPGAPI_readBody, readBodyBytes or
   // saveBody: they are read from the connection as the procedure asks for
   // them, not held in memory. 0 (the default) turns this off
dcl-pr RPGAPI_setMaxUploadSize;
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
