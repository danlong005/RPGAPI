**free

   // RPGAPI's own procedures, for the RPGAPI module and its unit tests. The
   // service program does not export them, so apps cannot call them: an app
   // includes only rpgapi_h.rpgle, which this needs first

/if not defined(RPGAPI_INT_H)
/define RPGAPI_INT_H

   // closes the connection and the listening socket
dcl-pr RPGAPI_stop;
   config likeds(RPGAPI_App) const;
end-pr;

   // the next request on the connection, read and parsed
dcl-pr RPGAPI_acceptRequest likeds(RPGAPI_Request);
   config likeds(RPGAPI_App);
end-pr;

   // a request's line and headers, as text in the job's CCSID
dcl-pr RPGAPI_parse likeds(RPGAPI_Request);
   raw_request varchar(32000) const;
end-pr;

   // whether a route is for this request; fills request.params
dcl-pr RPGAPI_routeMatches ind;
   route likeds(RPGAPI_route_ds);
   request likeds(RPGAPI_Request);
end-pr;

   // whether middleware is for this request's path (* for all); fills
   // request.params
dcl-pr RPGAPI_mwMatches ind;
   route likeds(RPGAPI_route_ds);
   request likeds(RPGAPI_Request);
end-pr;

   // sends a response that was not streamed, and finishes the request
dcl-pr RPGAPI_sendResponse;
   config likeds(RPGAPI_App) const;
   response likeds(RPGAPI_Response) const;
end-pr;

   // the status line and headers of a response
dcl-pr RPGAPI_buildHead varchar(32766);
   response likeds(RPGAPI_Response) const;
   body_length int(10:0) const;
end-pr;

   // opens the listening socket on the app's port
dcl-pr RPGAPI_setup;
   config likeds(RPGAPI_App);
end-pr;

   // text without CR and LF
dcl-pr RPGAPI_cleanString varchar(32000);
   dirty_string varchar(32000) const;
end-pr;

   // the reason phrase of an HTTP status, such as Not Found
dcl-pr RPGAPI_getMessage char(40);
   status zoned(3:0) const;
end-pr;

   // fills HTTP_messages
dcl-pr RPGAPI_initHttp;
end-pr;

   // for the views module (views.sqlrpgle), from the RPGAPI module
dcl-pr RPGAPI_log;
   level int(10:0) const;
   text varchar(1000) const;
end-pr;
dcl-pr RPGAPI_hasHeader ind;
   response likeds(RPGAPI_Response) const;
   name varchar(50) const;
end-pr;
dcl-pr RPGAPI_jobProgram varchar(64);
end-pr;
   // whether a streamed response has begun and not ended
dcl-pr RPGAPI_streaming ind;
end-pr;
   // the library of the RPGAPI service program
dcl-pr RPGAPI_ownLibrary char(10);
end-pr;

   // for compiled views, from the views module: another view, in place
dcl-pr RPGAPI_includeView;
   template varchar(1024) const;
   data pointer value;
end-pr;
   // for ERPG: compiles a template into a library ahead of time
dcl-pr RPGAPI_compileView char(21);
   path varchar(1024) const;
   library char(10) const;
   errors varchar(4000);
end-pr;

/endif
