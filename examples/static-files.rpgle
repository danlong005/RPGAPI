**free
   // Serving files from the IFS. RPGAPI_serveStatic serves a whole directory:
   // /site/<path> sends /home/<you>/public/<path>, index.html for a
   // directory, with its Content-Type, Last-Modified and ETag, and answers
   // conditional requests (304) and ranges (206), so browsers cache the files
   // and downloads can resume. A route that picks the file itself uses
   // RPGAPI_sendFile, here to send one as a download.
   //
   // Build:
   //   CRTBNDRPG PGM(MYLIB/FILES) SRCSTMF('<clone>/examples/static-files.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // Run (after changing PUBLIC_DIR, and putting some files in it):
   //   SBMJOB CMD(CALL PGM(MYLIB/FILES)) JOB(FILES)
   // Try:
   //   curl -i http://your-ibm-i:8080/site/                                   -> index.html
   //   curl -i -H 'If-None-Match: <the ETag it sent>' http://your-ibm-i:8080/site/  -> 304
   //   curl -i -r 0-99 http://your-ibm-i:8080/site/big.zip                    -> 206
   //   curl -OJ http://your-ibm-i:8080/download/big.zip                       -> saved as big.zip

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-c PUBLIC_DIR '/home/you/public';

dcl-ds app likeds(RPGAPI_App);

clear app;
   // the directory has to exist, or the program ends with a message
RPGAPI_serveStatic(app : '/site' : PUBLIC_DIR);
RPGAPI_get(app : '/download/{name}' : %paddr(download));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


   // a file of PUBLIC_DIR as a download, whatever its type
dcl-proc download;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s name varchar(1024);

      // {name} is one path segment, and sendFile refuses '..', so the
      // request cannot reach outside PUBLIC_DIR
   name = RPGAPI_getParam(request : 'name');
   RPGAPI_setHeader(response : 'Content-Type' : 'application/octet-stream');
   RPGAPI_setHeader(response : 'Content-Disposition' : 'attachment; filename="' +
                    %scanrpl('"' : '' : name) + '"');
   if RPGAPI_sendFile(response : PUBLIC_DIR + '/' + name);
      return response;
   endif;

      // not sent: answer with a 404 instead
   clear response;
   response.status = HTTP_NOT_FOUND;
   response.body = 'no such file';
   return response;
end-proc;
