**free 

/if not defined(RPGAPI_H)
/define RPGAPI_H

/include 'http_h.rpgle'

dcl-c RPGAPI_LF x'0d';
dcl-c RPGAPI_CR x'25';
dcl-c RPGAPI_CRLF x'0d25';
dcl-c RPGAPI_DBL_CRLF x'0d250d25';
dcl-c RPGAPI_GLOBAL_MIDDLEWARE '*';

dcl-s option_val int(10:0);

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

dcl-pr RPGAPI_setResponse likeds(RPGAPI_Response);
   request likeds(RPGAPI_Request);
   status zoned(3:0) const;
end-pr;

dcl-pr RPGAPI_cleanString varchar(32000);
   dirty_string varchar(32000) const;
end-pr;

dcl-pr RPGAPI_getMessage char(25);
   status zoned(3:0) const;
end-pr;

dcl-pr RPGAPI_translate ExtPgm('QDCXLATE');
   length packed(5:0) const;
   data varchar(32766) options(*varsize);
   table char(10) const;
end-pr;

dcl-pr RPGAPI_initHttp;
end-pr;

/endif
