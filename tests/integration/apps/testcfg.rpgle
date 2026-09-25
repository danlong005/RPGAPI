**free

   // shared by the test apps: testcfg_h.rpgle goes at the top of each, and
   // this, the procedure, at the end. It applies the settings the runner leaves in the
   // data area TESTCFG in the program's own library, as
   // port;log level;max request size;max upload size;timeout;jobs;work dir;tls
   // Empty fields are left at RPGAPI's defaults. tls is APP:<id> or
   // KDB:<path>:<password>:<label>

dcl-proc testSettings;
   dcl-pi *n;
      app likeds(RPGAPI_App);
   end-pi;
   dcl-s fields varchar(500) dim(8);
   dcl-s tls varchar(500) dim(4);
   dcl-s index int(10:0);
   dcl-s text char(500);

   testConfigName = %trim(testProgram.library) + '/TESTCFG';
   in testConfig;
      // %split drops empty fields, so split by hand to keep positions
   text = testConfig;
   for index = 1 to %elem(fields);
      if %scan(';' : text) > 0;
         fields(index) = %trim(%subst(text : 1 : %scan(';' : text) - 1));
         text = %subst(text : %scan(';' : text) + 1);
      else;
         fields(index) = %trim(text);
         text = '';
      endif;
   endfor;

   if fields(1) <> '';
      app.port = %int(fields(1));
   endif;
   if fields(2) <> '';
      RPGAPI_setLogLevel(app : %int(fields(2)));
   endif;
   if fields(3) <> '';
      RPGAPI_setMaxRequestSize(app : %int(fields(3)));
   endif;
   if fields(4) <> '';
      RPGAPI_setMaxUploadSize(app : %int(fields(4)));
   endif;
   if fields(5) <> '';
      RPGAPI_setTimeouts(app : %int(fields(5)) : %int(fields(5)));
   endif;
   if fields(6) <> '';
      app.jobs = %int(fields(6));
   endif;
   testWorkDir = fields(7);
   if fields(8) <> '';
      tls = %split(fields(8) : ':');
      if tls(1) = 'APP';
         RPGAPI_setTlsApplication(app : tls(2));
      elseif tls(1) = 'KDB' and tls(4) <> '';
         RPGAPI_setTlsKeystore(app : tls(2) : tls(3) : tls(4));
      else;
         RPGAPI_setTlsKeystore(app : tls(2) : tls(3));
      endif;
   endif;
end-proc;
