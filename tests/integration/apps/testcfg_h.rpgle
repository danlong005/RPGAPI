**free

   // declarations for testcfg.rpgle, which has the procedure: include this at
   // the top of a test app, and testcfg.rpgle at its end

   // the program's status: its library, and the job it runs in
dcl-ds testProgram psds qualified;
   library char(10) pos(81);
   job_number char(6) pos(264);
end-ds;

   // the work directory the runner made, for files the tests send and save
dcl-s testWorkDir varchar(500);
   // CORS origins for the apps that use them
dcl-s testCorsOrigins varchar(500);

   // the settings, read from the data area by testSettings
dcl-s testConfigName char(21);
dcl-s testConfig char(500) dtaara(testConfigName);

dcl-pr testSettings;
   app likeds(RPGAPI_App);
end-pr;
