**free
   // Serving files from an IFS directory: /files/<name> sends
   // /home/<you>/public/<name> with its Content-Type, Last-Modified and ETag,
   // and answers conditional requests (304) and ranges (206), so browsers
   // cache the files and downloads can resume. Anything else is 404.
   //
   // Build:
   //   CRTBNDRPG PGM(MYLIB/FILES) SRCSTMF('<clone>/examples/static-files.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // Run (after changing PUBLIC_DIR, and putting some files in it):
   //   SBMJOB CMD(CALL PGM(MYLIB/FILES)) JOB(FILES)
   // Try:
   //   curl -i http://your-ibm-i:8080/files/index.html
   //   curl -i -H 'If-None-Match: <the ETag it sent>' http://your-ibm-i:8080/files/index.html  -> 304
   //   curl -i -r 0-99 http://your-ibm-i:8080/files/big.zip                                   -> 206

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-c PUBLIC_DIR '/home/you/public/';

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/files/{name}' : %paddr(file));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


dcl-proc file;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

      // {name} is one path segment, and sendFile refuses '..', so the
      // request cannot reach outside PUBLIC_DIR
   RPGAPI_setHeader(response : 'Cache-Control' : 'public, max-age=3600');
   if RPGAPI_sendFile(response : PUBLIC_DIR + RPGAPI_getParam(request : 'name'));
      return response;
   endif;

      // not sent: answer with a 404 instead
   clear response;
   response.status = HTTP_NOT_FOUND;
   response.body = 'no such file';
   return response;
end-proc;
