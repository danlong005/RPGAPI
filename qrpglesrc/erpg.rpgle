**free
ctl-opt option(*nodebugio:*srcstmt) dftactgrp(*no) actgrp(*new) main(ERPG);

   // ERPG compiles a view ahead of time, as RPGAPI_render does the first time
   // a template is asked for:
   //   CALL ERPG PARM('/app/views/customers.erpg' 'MYLIB')
   // compiles it into a program in MYLIB (named RV and 8 hex digits, after
   // the template's name and content). RPGAPI_render finds it there and
   // uses it as long as the template is the same, so a server without the
   // ILE RPG compiler can run views compiled on another system. It is also
   // a quick way to check a template: a template that does not compile ends
   // ERPG with CPF9898 and the errors, at their template lines.

/include 'rpgapi_h.rpgle'
/include 'rpgapi_int_h.rpgle'

dcl-pr send_program_message extpgm('QMHSNDPM');
   message_id char(7) const;
   message_file char(20) const;
   message_data char(512) const;
   message_data_length int(10:0) const;
   message_type char(10) const;
   call_stack_entry char(10) const;
   call_stack_counter int(10:0) const;
   message_key char(4);
   error_code char(8);
end-pr;


dcl-proc ERPG;
   dcl-pi *n;
      parameter char(1024);
      library char(10);
   end-pi;
   dcl-s path varchar(1024);
   dcl-s program char(21);
   dcl-s errors varchar(4000);

   if %parms() < 2 or library = '';
      finish('*ESCAPE' : 'ERPG needs the path of a .erpg template and the ' +
             'library to compile it into, such as CALL ERPG PARM(''' +
             '/app/views/orders.erpg'' ''MYLIB'')');
   endif;
   path = templatePath(parameter);
   program = RPGAPI_compileView(path : %upper(library) : errors);
   if program = '';
      finish('*ESCAPE' : %subst(errors : 1 : %min(%len(errors) : 500)));
   endif;
   finish('*COMP' : 'ERPG compiled ' + path + ' into ' + %trim(program));
end-proc;


   // the template's path from the parameter. CALL passes a literal of more
   // than 32 characters at its own length, so what follows it is not blanks:
   // the path ends at the first .erpg followed by a blank or x'00'
dcl-proc templatePath;
   dcl-pi *n varchar(1024);
      parameter char(1024);
   end-pi;
   dcl-s at int(10:0) inz(0);
   dcl-s after char(1);

   dow *on;
      at = %scan('.erpg' : parameter : at + 1);
      if at = 0;
         finish('*ESCAPE' : 'ERPG needs the path of a template ending in ' +
                '.erpg, such as /app/views/orders.erpg');
      endif;
      if at + 5 > %len(parameter);
         leave;
      endif;
      after = %subst(parameter : at + 5 : 1);
      if after = ' ' or after = x'00';
         leave;
      endif;
   enddo;
   return %trim(%subst(parameter : 1 : at + 4));
end-proc;


   // ends ERPG with a message to its caller: *COMP, or *ESCAPE (CPF9898)
dcl-proc finish;
   dcl-pi *n;
      type char(10) const;
      text varchar(512) const;
   end-pi;
   dcl-s key char(4);
      // bytes provided 0: a failure to send is signalled as an exception
   dcl-s error_code char(8) inz(*allx'00');

   if type = '*COMP';
      send_program_message('CPF9897' : 'QCPFMSG   *LIBL' : text : %len(text) :
                           '*COMP' : '*PGMBDY' : 1 : key : error_code);
      return;
   endif;
   send_program_message('CPF9898' : 'QCPFMSG   *LIBL' : text : %len(text) :
                        '*ESCAPE' : '*PGMBDY' : 1 : key : error_code);
end-proc;
