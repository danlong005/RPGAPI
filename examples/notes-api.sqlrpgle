**free
   // A JSON API over an SQL table: create, read, update and delete notes.
   // SQL builds and reads the JSON (JSON_OBJECT, JSON_ARRAYAGG, JSON_TABLE),
   // so the RPG only moves strings. The table is created in QTEMP when the
   // server starts, so the example needs no setup; use a real library for
   // anything that should last, with a primary key on id (QTEMP tables
   // cannot have constraints). QTEMP is per job, so this example runs in
   // one job.
   //
   // Build:
   //   CRTSQLRPGI OBJ(MYLIB/NOTES) SRCSTMF('<clone>/examples/notes-api.sqlrpgle')
   //              CVTCCSID(*JOB) COMPILEOPT('INCDIR(''<clone>/qrpglesrc'') TGTCCSID(*JOB)')
   // Run:
   //   SBMJOB CMD(CALL PGM(MYLIB/NOTES)) JOB(NOTES)
   // Try:
   //   curl -X POST -H 'Content-Type: application/json' \
   //        -d '{"title":"Groceries","text":"Milk, bread"}' http://your-ibm-i:8080/notes
   //   curl http://your-ibm-i:8080/notes
   //   curl http://your-ibm-i:8080/notes/1
   //   curl -X PUT -d '{"title":"Groceries","text":"Milk, bread, eggs"}' http://your-ibm-i:8080/notes/1
   //   curl -X DELETE http://your-ibm-i:8080/notes/1

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'

dcl-ds app likeds(RPGAPI_App);

exec sql set option commit = *none;
exec sql create or replace table qtemp.notes (
            id integer generated always as identity,
            title varchar(100) not null,
            text varchar(2000) not null default '',
            created timestamp not null default current timestamp);

clear app;
RPGAPI_get(app : '/notes' : %paddr(listNotes));
RPGAPI_get(app : '/notes/{id}' : %paddr(getNote));
RPGAPI_post(app : '/notes' : %paddr(addNote));
RPGAPI_put(app : '/notes/{id}' : %paddr(changeNote));
RPGAPI_delete(app : '/notes/{id}' : %paddr(removeNote));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


   // GET /notes: all notes as a JSON array
dcl-proc listNotes;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s json varchar(32000);

   exec sql select coalesce(json_arrayagg(
                     json_object('id' value id, 'title' value title,
                                 'text' value text,
                                 'created' value varchar(created))
                     order by id), '[]')
              into :json
              from qtemp.notes;
   return jsonResponse(HTTP_OK : json);
end-proc;


   // GET /notes/{id}
dcl-proc getNote;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s json varchar(32000);
   dcl-s id int(10:0);

   if not noteId(request : id);
      return jsonResponse(HTTP_BAD_REQUEST : '{"error":"id is not a number"}');
   endif;
   exec sql select json_object('id' value id, 'title' value title,
                               'text' value text,
                               'created' value varchar(created))
              into :json
              from qtemp.notes
              where id = :id;
   if sqlcode = 100;
      return jsonResponse(HTTP_NOT_FOUND : '{"error":"no such note"}');
   endif;
   return jsonResponse(HTTP_OK : json);
end-proc;


   // POST /notes with {"title": ..., "text": ...}
dcl-proc addNote;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s body varchar(32000);
   dcl-s title varchar(100);
   dcl-s text varchar(2000);
   dcl-s id int(10:0);

   body = request.body;
   if not readNote(body : title : text);
      return jsonResponse(HTTP_BAD_REQUEST :
                          '{"error":"send JSON with a title"}');
   endif;
   exec sql select id into :id from final table (
               insert into qtemp.notes (title, text) values (:title, :text));
   return jsonResponse(HTTP_CREATED : '{"id":' + %char(id) + '}');
end-proc;


   // PUT /notes/{id} with {"title": ..., "text": ...}
dcl-proc changeNote;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-s body varchar(32000);
   dcl-s title varchar(100);
   dcl-s text varchar(2000);
   dcl-s id int(10:0);

   if not noteId(request : id);
      return jsonResponse(HTTP_BAD_REQUEST : '{"error":"id is not a number"}');
   endif;
   body = request.body;
   if not readNote(body : title : text);
      return jsonResponse(HTTP_BAD_REQUEST :
                          '{"error":"send JSON with a title"}');
   endif;
   exec sql update qtemp.notes set title = :title, text = :text
              where id = :id;
   if sqlcode = 100;
      return jsonResponse(HTTP_NOT_FOUND : '{"error":"no such note"}');
   endif;
   return jsonResponse(HTTP_OK : '{"id":' + %char(id) + '}');
end-proc;


   // DELETE /notes/{id}
dcl-proc removeNote;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s id int(10:0);

   if not noteId(request : id);
      return jsonResponse(HTTP_BAD_REQUEST : '{"error":"id is not a number"}');
   endif;
   exec sql delete from qtemp.notes where id = :id;
   if sqlcode = 100;
      return jsonResponse(HTTP_NOT_FOUND : '{"error":"no such note"}');
   endif;
   response.status = HTTP_NO_CONTENT;
   return response;
end-proc;


   // the {id} param as a number; *off when it is not one
dcl-proc noteId;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      id int(10:0);
   end-pi;

   monitor;
      id = %int(RPGAPI_getParam(request : 'id'));
   on-error;
      return *off;
   endmon;
   return *on;
end-proc;


   // the title and text of a note sent as JSON; *off without a title
dcl-proc readNote;
   dcl-pi *n ind;
      body varchar(32000);
      title varchar(100);
      text varchar(2000);
   end-pi;
   dcl-s title_ind int(5:0);
   dcl-s text_ind int(5:0);

   title = '';
   text = '';
   exec sql select title, text into :title :title_ind, :text :text_ind
              from json_table(:body, 'lax $'
                   columns(title varchar(100) path 'lax $.title',
                           text varchar(2000) path 'lax $.text'));
   if sqlcode <> 0 or title_ind < 0 or title = '';
      return *off;
   endif;
   if text_ind < 0;
      text = '';
   endif;
   return *on;
end-proc;


dcl-proc jsonResponse;
   dcl-pi *n likeds(RPGAPI_Response);
      status int(10:0) const;
      json varchar(32000) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = status;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = json;
   return response;
end-proc;
