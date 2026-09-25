**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // setRoute, patch, statuses, CR/LF and response headers, byte for byte
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setRoute(app : HTTP_PATCH : '/viaset' : %paddr(VIASET));   
RPGAPI_patch(app : '/items/{id}' : %paddr(PATCHED));              
RPGAPI_get(app : '/accepted' : %paddr(ACCEPTED));
RPGAPI_get(app : '/crlf' : %paddr(CRLF));
RPGAPI_get(app : '/headers' : %paddr(HEADERS));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

dcl-proc VIASET;                                                   
   dcl-pi *n likeds(RPGAPI_Response);                              
      request likeds(RPGAPI_Request) const;                        
   end-pi;                                                         
   dcl-ds response likeds(RPGAPI_Response) inz;                    
   response.status = 200;                                          
   response.body = 'via setRoute';                                 
   return response;                                                
end-proc;                                                          

dcl-proc PATCHED;                                                  
   dcl-pi *n likeds(RPGAPI_Response);                              
      request likeds(RPGAPI_Request) const;                        
   end-pi;                                                         
   dcl-ds response likeds(RPGAPI_Response) inz;                    
   response.status = 200;                                          
   response.body = 'patched ' + RPGAPI_getParam(request : 'id');   
   return response;                                                
end-proc;                                                          

dcl-proc ACCEPTED;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = HTTP_ACCEPTED;
   response.body = 'queued';
   return response;
end-proc;

   // 'a', then RPGAPI_CR, RPGAPI_LF, then 'b'
dcl-proc CRLF;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = 200;
   response.body = 'a' + RPGAPI_CR + RPGAPI_LF + 'b';
   return response;
end-proc;

dcl-proc HEADERS;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   response.status = HTTP_CREATED;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   RPGAPI_setHeader(response : 'Connection' : 'keep-alive');
   RPGAPI_setHeader(response : 'X-Test' : 'one two');
   response.body = '  Jürgen  ';
   return response;
end-proc;

/include 'testcfg.rpgle'
