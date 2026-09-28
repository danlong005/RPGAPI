**free
   // A guestbook from a view, without SQL: the notes are kept in an RPG array.
   // To show them, the route fills the page's data structure (newest first)
   // and renders views/guestbook.erpg with its address; the view bases the
   // same data structure (views/guestbook_t.rpgleinc, included by both) on it,
   // loops over the notes, shows whatever visitors typed escaped (so no one
   // can add HTML or scripts to the page), and includes views/pagetop.erpg
   // for the top of the page. A form with a field missing is answered 400,
   // with the page and what is wrong.
   //
   // Build:
   //   CRTBNDRPG PGM(MYLIB/GUESTBOOK) SRCSTMF('<clone>/examples/guestbook.rpgle')
   //             INCDIR('<clone>/qrpglesrc' '<clone>/examples/views') TGTCCSID(*JOB)
   // with VIEWS below set to <clone>/examples/views. The views are compiled
   // into MYLIB the first time the page is asked for.
   // Run:
   //   SBMJOB CMD(CALL PGM(MYLIB/GUESTBOOK)) JOB(GUESTBOOK)
   // Try, in a browser:
   //   http://your-ibm-i:8080/guestbook
   // The notes are in the job's memory: they are gone when it ends, and with
   // several jobs each would have its own. A real app keeps them in a table.

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
   // note_t, and guestbook_t, the view's data
/include 'guestbook_t.rpgleinc'

dcl-c VIEWS '/home/myuser/RPGAPI/examples/views';

   // the notes, oldest first; the oldest go when it is full
dcl-ds notes likeds(note_t) dim(100);
dcl-s note_count int(10:0) inz(0);

dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_setViews(app : VIEWS);
RPGAPI_get(app : '/guestbook' : %paddr(showGuestbook));
RPGAPI_post(app : '/guestbook' : %paddr(signGuestbook));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


dcl-proc showGuestbook;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;

   return guestbookPage(HTTP_OK : '');
end-proc;


   // a note from the form, then back to the page (a redirect, so that
   // reloading the page does not send the form again)
dcl-proc signGuestbook;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s name varchar(50);
   dcl-s message varchar(500);

   name = %trim(RPGAPI_getFormParam(request : 'name'));
   message = %trim(RPGAPI_getFormParam(request : 'message'));
   if name = '' or message = '';
      return guestbookPage(HTTP_BAD_REQUEST :
                           'Please give your name and a message.');
   endif;

   if note_count = %elem(notes);
      notes = %subarr(notes : 2);
      note_count -= 1;
   endif;
   note_count += 1;
   notes(note_count).name = name;
   notes(note_count).message = message;
   notes(note_count).posted = %timestamp();

   response.status = 303;
   RPGAPI_setHeader(response : 'Location' : '/guestbook');
   return response;
end-proc;


   // the page, with status, and a problem to show ('' for none)
dcl-proc guestbookPage;
   dcl-pi *n likeds(RPGAPI_Response);
      status int(10:0) const;
      problem varchar(100) const;
   end-pi;
   dcl-ds model likeds(guestbook_t) inz;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s index int(10:0);

   model.title = 'Guestbook';
   model.problem = problem;
   for index = note_count downto 1;
      model.count += 1;
      model.notes(model.count) = notes(index);
   endfor;
   response.status = status;
   return RPGAPI_render('guestbook.erpg' : %addr(model) : response);
end-proc;
