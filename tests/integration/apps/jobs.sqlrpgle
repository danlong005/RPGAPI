**free
ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI') dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include 'testcfg_h.rpgle'

   // several jobs: spread, stalled clients, library list, ending together
dcl-pr sleep uns(10:0) extproc('sleep');
   seconds uns(10:0) value;
end-pr;


dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/slow' : %paddr(SLOW));
RPGAPI_get(app : '/libl' : %paddr(LIBL));
testSettings(app);
RPGAPI_start(app);

*inlr = *on;
return;

   // takes 3 seconds, then says which job answered
dcl-proc SLOW;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   sleep(3);
   response.status = 200;
   response.body = 'job ' + testProgram.job_number;
   return response;
end-proc;

   // the job's library list
dcl-proc LIBL;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s list varchar(2000);

   exec sql select listagg(trim(system_schema_name), ' ')
              into :list
              from qsys2.library_list_info;
   response.status = 200;
   response.body = 'job ' + testProgram.job_number + ': ' + list;
   return response;
end-proc;

/include 'testcfg.rpgle'
