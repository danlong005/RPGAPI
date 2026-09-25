**free

/if not defined(HTTP_H)       
/define HTTP_H                
                                    
dcl-c HTTP_GET 'GET';       
dcl-c HTTP_POST 'POST';     
dcl-c HTTP_PUT 'PUT';       
dcl-c HTTP_PATCH 'PATCH';   
dcl-c HTTP_DELETE 'DELETE'; 

dcl-c HTTP_OK 200;          
dcl-c HTTP_CREATED 201;    
dcl-c HTTP_ACCEPTED 202;
dcl-c HTTP_NO_CONTENT 204; 
dcl-c HTTP_PARTIAL_CONTENT 206;
dcl-c HTTP_MOVED_PERMANENTLY 301;
dcl-c HTTP_FOUND 302;
dcl-c HTTP_NOT_MODIFIED 304;
dcl-c HTTP_BAD_REQUEST 400; 
dcl-c HTTP_UNAUTHORIZED 401;
dcl-c HTTP_FORBIDDEN 403;
dcl-c HTTP_NOT_FOUND 404;   
dcl-c HTTP_REQUEST_TIMEOUT 408;
dcl-c HTTP_CONTENT_TOO_LARGE 413;
dcl-c HTTP_RANGE_NOT_SATISFIABLE 416;
dcl-c HTTP_HEADERS_TOO_LARGE 431;
dcl-c HTTP_INTERNAL_SERVER 500;
dcl-c HTTP_NOT_IMPLEMENTED 501;

   // inz: the entries not filled in by RPGAPI_initHttp have to be zeros;
   // blanks are not a valid zoned number, and looking up a status without
   // an entry failed on them
dcl-ds HTTP_messages qualified dim(100) inz;
   status zoned(3:0);
   text char(40);
end-ds;

/endif                        