**free
   // File uploads from a browser: GET / shows a form, and POST /upload saves
   // the chosen files to an IFS directory, part by part, without holding them
   // in memory. Uploads up to 100MB are allowed.
   //
   // Build:
   //   CRTBNDRPG PGM(MYLIB/UPLOAD) SRCSTMF('<clone>/examples/upload.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // Run (after changing UPLOAD_DIR to a directory the job can write to):
   //   SBMJOB CMD(CALL PGM(MYLIB/UPLOAD)) JOB(UPLOAD)
   // Try: open http://your-ibm-i:8080/ in a browser, or
   //   curl -F 'note=my files' -F 'file=@report.pdf' -F 'file=@photo.jpg' \
   //        http://your-ibm-i:8080/upload

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-c UPLOAD_DIR '/home/you/uploads/';

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setMaxUploadSize(app : 100000000);
RPGAPI_get(app : '/' : %paddr(form));
RPGAPI_post(app : '/upload' : %paddr(upload));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


dcl-proc form;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/html; charset=utf-8');
   response.body = '<!doctype html><title>Upload</title>' +
      '<form method="post" action="/upload" enctype="multipart/form-data">' +
      '<p><input name="note" placeholder="A note"></p>' +
      '<p><input type="file" name="file" multiple></p>' +
      '<p><button>Upload</button></p></form>';
   return response;
end-proc;


   // each file is saved under a name made here, never the client's own:
   // that could contain a path. The client's name goes in the answer
dcl-proc upload;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds part likeds(RPGAPI_Part);
   dcl-s saved_as varchar(200);
   dcl-s size int(10:0);
   dcl-s files int(10:0) inz(0);
   dcl-s note varchar(1000);

   response.body = '';
   dow RPGAPI_nextPart(request : part);
      if part.filename = '';
         if part.name = 'note';
            note = RPGAPI_readPart(request);
         endif;
         iter;
      endif;

      files += 1;
      saved_as = %char(%timestamp()) + '-' + %char(files);
      size = RPGAPI_savePart(request : UPLOAD_DIR + saved_as);
      if size < 0;
         clear response;
         response.status = HTTP_INTERNAL_SERVER;
         response.body = 'cannot write to ' + UPLOAD_DIR;
         return response;
      endif;
      response.body += 'saved ' + part.filename + ' (' + %char(size) +
                       ' bytes, ' + part.content_type + ') as ' + saved_as + x'25';
   enddo;

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'text/plain; charset=utf-8');
   response.body = %char(files) + ' file(s), note: ' + note + x'25' +
                   response.body;
   return response;
end-proc;
