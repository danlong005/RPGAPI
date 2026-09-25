**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // request bodies: limits, chunked, 100-continue, uploads, saveBody, multipart
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_post(app : '/body' : %paddr(BODY));
RPGAPI_post(app : '/text' : %paddr(TEXT));
RPGAPI_post(app : '/bytes' : %paddr(BYTES));
RPGAPI_post(app : '/save' : %paddr(SAVE));
RPGAPI_post(app : '/reject' : %paddr(REJECT));
RPGAPI_post(app : '/ignore' : %paddr(IGNORE));
RPGAPI_post(app : '/form' : %paddr(FORM));
RPGAPI_post(app : '/third' : %paddr(THIRD));
RPGAPI_post(app : '/partbytes' : %paddr(PARTBYTES));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

   // request.body: its length, and its first and last 5 characters
dcl-proc BODY;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s length int(10:0);

   length = %len(request.body);
   response.status = 200;
   response.body = 'body=' + %char(length) + ' bodyLength=' +
                   %char(RPGAPI_bodyLength(request));
   if length >= 5;
      response.body += ' head=' + %subst(request.body : 1 : 5) +
                       ' tail=' + %subst(request.body : length - 4);
   endif;
   return response;
end-proc;

   // the body read with RPGAPI_readBody: pieces, characters, and how many are u-umlaut
dcl-proc TEXT;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s piece varchar(32000);
   dcl-s pieces int(10:0) inz(0);
   dcl-s characters int(10:0) inz(0);
   dcl-s umlauts int(10:0) inz(0);

   piece = RPGAPI_readBody(request);
   dow piece <> '';
      pieces += 1;
      characters += %len(piece);
      umlauts += %len(piece) - %len(%scanrpl('ü' : '' : piece));
      piece = RPGAPI_readBody(request);
   enddo;
   response.status = 200;
   response.body = 'pieces=' + %char(pieces) + ' chars=' + %char(characters) +
                   ' umlauts=' + %char(umlauts);
   return response;
end-proc;

   // the body read with RPGAPI_readBodyBytes: bytes, and a checksum that
   // weighs each byte by its position
dcl-proc BYTES;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s buffer char(4096);
   dcl-s count int(10:0);
   dcl-s total int(20:0) inz(0);
   dcl-s checksum int(20:0) inz(0);
   dcl-s index int(10:0);
   dcl-s length_before int(10:0);
   dcl-ds one_byte;
      character char(1);
      number uns(3:0) overlay(character);
   end-ds;

   length_before = RPGAPI_bodyLength(request);
   count = RPGAPI_readBodyBytes(request : %addr(buffer) : %size(buffer));
   dow count > 0;
      for index = 1 to count;
         character = %subst(buffer : index : 1);
         checksum += number * (%rem(total : 7) + 1);
         total += 1;
      endfor;
      count = RPGAPI_readBodyBytes(request : %addr(buffer) : %size(buffer));
   enddo;
   response.status = 200;
   response.body = 'bytes=' + %char(total) + ' checksum=' + %char(checksum) +
                   ' bodyLength=' + %char(length_before) + '/' +
                   %char(RPGAPI_bodyLength(request));
   return response;
end-proc;

dcl-proc SAVE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   if RPGAPI_saveBody(request : testWorkDir + '/uploads/up.bin');
      response.status = HTTP_CREATED;
      response.body = 'saved ' + %char(RPGAPI_bodyLength(request));
   else;
      response.status = HTTP_INTERNAL_SERVER;
   endif;
   return response;
end-proc;

   // refuses without reading the body
dcl-proc REJECT;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_FORBIDDEN;
   response.body = 'not you';
   return response;
end-proc;

   // answers without reading the body
dcl-proc IGNORE;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = 200;
   response.body = 'ignored';
   return response;
end-proc;

   // every part: fields with their text, files saved with their size
dcl-proc FORM;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds part likeds(RPGAPI_Part);
   dcl-s value varchar(32000);
   dcl-s piece varchar(32000);
   dcl-s count int(10:0) inz(0);
   dcl-s size int(10:0);

   response.status = 200;
   dow RPGAPI_nextPart(request : part);
      count += 1;
      response.body += '[' + part.name + '|' + part.filename + '|' +
                       part.content_type + '|';
      if part.filename = '';
         value = '';
         piece = RPGAPI_readPart(request);
         dow piece <> '';
            if %len(value) + %len(piece) <= 200;
               value += piece;
            endif;
            piece = RPGAPI_readPart(request);
         enddo;
         response.body += 'value=' + %scanrpl(x'0d25' : '<CRLF>' : value) + ']';
      else;
         size = RPGAPI_savePart(request : testWorkDir + '/uploads/part' +
                                %char(count) + '.bin');
         response.body += 'saved=' + %char(size) + ']';
      endif;
   enddo;
   response.body = 'parts=' + %char(count) + ' ' + response.body;
   return response;
end-proc;

   // only the third part, skipping the others
dcl-proc THIRD;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds part likeds(RPGAPI_Part);
   dcl-s index int(10:0);

   response.status = 200;
   for index = 1 to 3;
      if not RPGAPI_nextPart(request : part);
         response.body = 'only ' + %char(index - 1) + ' parts';
         return response;
      endif;
   endfor;
   response.body = 'third=' + part.name + ' value=' + RPGAPI_readPart(request);
   return response;
end-proc;

   // each file part read with RPGAPI_readPartBytes: bytes and checksum
dcl-proc PARTBYTES;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds part likeds(RPGAPI_Part);
   dcl-s buffer char(4096);
   dcl-s count int(10:0);
   dcl-s total int(20:0);
   dcl-s checksum int(20:0);
   dcl-s index int(10:0);
   dcl-ds one_byte;
      character char(1);
      number uns(3:0) overlay(character);
   end-ds;

   response.status = 200;
   dow RPGAPI_nextPart(request : part);
      if part.filename <> '';
         total = 0;
         checksum = 0;
         count = RPGAPI_readPartBytes(request : %addr(buffer) : %size(buffer));
         dow count > 0;
            for index = 1 to count;
               character = %subst(buffer : index : 1);
               checksum += number * (%rem(total : 7) + 1);
               total += 1;
            endfor;
            count = RPGAPI_readPartBytes(request : %addr(buffer) : %size(buffer));
         enddo;
         response.body += '[' + part.name + ' bytes=' + %char(total) +
                          ' checksum=' + %char(checksum) + ']';
      endif;
   enddo;
   return response;
end-proc;

/include 'testcfg.rpgle'
