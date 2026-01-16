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

dcl-ds RPGAPIRQST qualified template;
   body varchar(32000);
   headers likeds(RPGAPI_header_ds) dim(100);
   hostname char(250);
   method char(10);
   params likeds(RPGAPI_param_ds) dim(100);
   protocol char(250);
   query_params likeds(RPGAPI_param_ds) dim(100);
   query_string char(1024);
   route char(250);
end-ds;

dcl-ds RPGAPIRSP qualified template;
   body varchar(32000);
   headers likeds(RPGAPI_header_ds) dim(100);
   status int(10:0);
end-ds;

dcl-ds RPGAPIAPP qualified template;
   port int(10:0);
   socket_descriptor int(10:0);
   return_socket_descriptor int(10:0);
   routes likeds(RPGAPI_route_ds) dim(250);
   middlewares likeds(RPGAPI_route_ds) dim(100);
end-ds;


       


dcl-s RPGAPI_callback_ptr pointer(*proc);
dcl-pr RPGAPI_callBack extproc(RPGAPI_callBack_ptr) likeds(RPGAPIRSP);
   request likeds(RPGAPIRQST) const;
end-pr;

dcl-s RPGAPI_mwCallback_ptr pointer(*proc);
dcl-pr RPGAPI_mwCallback ind extproc(RPGAPI_mwCallback_ptr);
   request likeds(RPGAPIRQST) const;
   response likeds(RPGAPIRSP);
end-pr;

dcl-pr RPGAPI_start;
   config likeds(RPGAPIAPP);
   port int(10:0) options(*nopass) const;
end-pr;

dcl-pr RPGAPI_stop;
   config likeds(RPGAPIAPP) const;
end-pr;

dcl-pr RPGAPI_acceptRequest likeds(RPGAPIRQST);
   config likeds(RPGAPIAPP);
end-pr;

dcl-pr RPGAPI_parse likeds(RPGAPIRQST);
   raw_request varchar(32000) const;
end-pr;

dcl-pr RPGAPI_getParam varchar(1024);
   request likeds(RPGAPIRQST) const;
   param char(50) const;
end-pr;

dcl-pr RPGAPI_getQueryParam varchar(1024);
   request likeds(RPGAPIRQST) const;
   param char(50) const;
end-pr;

dcl-pr RPGAPI_getHeader varchar(1024);
   request likeds(RPGAPIRQST) const;
   header char(50) const;
end-pr;

dcl-pr RPGAPI_setHeader;
   response likeds(RPGAPIRSP);
   header_name char(50) const;
   header_value varchar(1024) const;
end-pr;

dcl-pr RPGAPI_routeMatches ind;
   route likeds(RPGAPI_route_ds);
   request likeds(RPGAPIRQST);
end-pr;

dcl-pr RPGAPI_mwMatches ind;
   route likeds(RPGAPI_route_ds);
   request likeds(RPGAPIRQST);
end-pr;

dcl-pr RPGAPI_sendResponse;
   config likeds(RPGAPIAPP) const;
   response likeds(RPGAPIRSP) const;
end-pr;

dcl-pr RPGAPI_setup;
   config likeds(RPGAPIAPP);
end-pr;

dcl-pr RPGAPI_setRoute;
   config likeds(RPGAPIAPP);
   method char(10) const;
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_setMiddleware;
   config likeds(RPGAPIAPP);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_get;
   config likeds(RPGAPIAPP);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_put;
   config likeds(RPGAPIAPP);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_post;
   config likeds(RPGAPIAPP);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_delete;
   config likeds(RPGAPIAPP);
   url varchar(32000) const;
   procedure pointer(*proc) const;
end-pr;

dcl-pr RPGAPI_setResponse likeds(RPGAPIRSP);
   request likeds(RPGAPIRQST);
   status zoned(3:0) const;
end-pr;

dcl-pr RPGAPI_toUpper varchar(32000);
   line varchar(32000) const;
end-pr;

dcl-pr RPGAPI_split char(1024) dim(50);
   line varchar(32000) const;
   delimiter char(1) const;
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

/endif
