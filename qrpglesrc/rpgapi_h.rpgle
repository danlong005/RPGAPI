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

   // a part of a multipart/form-data body, from RPGAPI_nextPart
dcl-ds RPGAPI_Part qualified template;
   name varchar(256);
      // blank for a form field; the name of the file the client sent
   filename varchar(1024);
   content_type varchar(256);
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

   // HTTPS: serve TLS with the certificate assigned in Digital Certificate
   // Manager to this application ID. Call before RPGAPI_start
dcl-pr RPGAPI_setTlsApplication;
   application_id varchar(100) const;
end-pr;

   // HTTPS: serve TLS with a certificate from a keystore file (such as the
   // *SYSTEM store, /QIBM/USERDATA/ICSS/CERT/SERVER/DEFAULT.KDB), its
   // password, and the label of the certificate (its default one when left
   // out). Call before RPGAPI_start
dcl-pr RPGAPI_setTlsKeystore;
   path varchar(1024) const;
   password varchar(128) const;
   label varchar(128) const options(*nopass);
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
