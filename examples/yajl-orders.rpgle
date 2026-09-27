**free
   // JSON with YAJL (Scott Klement's port, https://www.scottklement.com/yajl):
   // DATA-INTO with YAJLINTO reads a request body into a data structure,
   // YAJL's generator builds a response, and DATA-GEN with YAJLDTAGEN turns
   // a data structure into JSON. YAJL escapes the text, so quotes,
   // backslashes and characters outside ASCII are safe.
   //
   // Needs YAJL installed in library YAJL. RPGAPI itself does not use YAJL.
   //
   // Build with YAJL and the library holding the RPGAPI binding directory in
   // your library list (YAJL's binding directory finds its service programs
   // there), and run with YAJL in the job's library list:
   //   ADDLIBLE YAJL
   //   CRTBNDRPG PGM(MYLIB/YAJLORDERS) SRCSTMF('<clone>/examples/yajl-orders.rpgle')
   //             INCDIR('<clone>/qrpglesrc') TGTCCSID(*JOB)
   // Run, try, stop:
   //   SBMJOB CMD(CALL PGM(MYLIB/YAJLORDERS)) JOB(YAJLORDERS) INLLIBL(*CURRENT)
   //   curl -X POST http://your-ibm-i:8080/orders -H 'Content-Type: application/json'
   //        -d '{"customer": "Anna", "items": [{"sku": "A1", "qty": 2, "price": 9.95},
   //             {"sku": "B7", "qty": 1, "price": 0.5}]}'
   //     -> 201 {"id":1,"customer":"Anna","items":[{"sku":"A1","qty":2,
   //             "price":9.95,"amount":19.90},...],"total":20.40}
   //   curl http://your-ibm-i:8080/status
   //     -> {"service":"orders","orders":1,"started":"2026-09-27-10.00.00"}
   //   ENDJOB JOB(YAJLORDERS)

ctl-opt option(*nodebugio:*srcstmt) bnddir('RPGAPI' : 'YAJL/YAJL')
        dftactgrp(*no);

/include 'rpgapi_h.rpgle'
/include YAJL/QRPGLESRC,YAJL_H

   // the message of the last error, for the 400 answer
dcl-ds status_ds psds;
   error_text char(80) pos(91);
end-ds;

   // an order as the client sends it. num_items is filled in by DATA-INTO
   // (countprefix=num_): how many of items the JSON had
dcl-ds order_t qualified template;
   customer varchar(100);
   num_items int(10:0);
   dcl-ds items dim(20);
      sku varchar(20);
      qty int(10:0);
      price packed(9:2);
   end-ds;
end-ds;

dcl-s orders_taken int(10:0) inz(0);
dcl-s started timestamp;
dcl-ds app likeds(RPGAPI_App);

clear app;
started = %timestamp();
RPGAPI_post(app : '/orders' : %paddr(addOrder));
RPGAPI_get(app : '/status' : %paddr(status));
RPGAPI_start(app : 8080);

*inlr = *on;
return;


   // POST /orders: reads the order with DATA-INTO, answers with it priced
dcl-proc addOrder;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds order likeds(order_t) inz;
   dcl-s index int(10:0);
   dcl-s amount packed(11:2);
   dcl-s total packed(11:2);

   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');

      // case=any: "customer" or "Customer"; allowmissing: fields left out
      // stay blank or 0; allowextra: fields we do not know are ignored
   monitor;
      data-into order %data(request.body :
                           'case=any countprefix=num_ ' +
                           'allowmissing=yes allowextra=yes')
                      %parser('YAJL/YAJLINTO');
   on-error;
      response.status = HTTP_BAD_REQUEST;
      response.body = errorJson('the body is not a valid order: ' +
                                %trim(error_text));
      return response;
   endmon;
   if order.customer = '' or order.num_items = 0;
      response.status = HTTP_BAD_REQUEST;
      response.body = errorJson('an order needs a customer and items');
      return response;
   endif;

   orders_taken += 1;

      // the answer, built with YAJL's generator
   yajl_genOpen(*off);
   yajl_beginObj();
   yajl_addNum('id' : %char(orders_taken));
   yajl_addChar('customer' : order.customer);
   yajl_beginArray('items');
   for index = 1 to order.num_items;
      amount = order.items(index).qty * order.items(index).price;
      total += amount;
      yajl_beginObj();
      yajl_addChar('sku' : order.items(index).sku);
      yajl_addNum('qty' : %char(order.items(index).qty));
      yajl_addNum('price' : jsonNumber(order.items(index).price));
      yajl_addNum('amount' : jsonNumber(amount));
      yajl_endObj();
   endfor;
   yajl_endArray();
   yajl_addNum('total' : jsonNumber(total));
   yajl_endObj();

   response.status = HTTP_CREATED;
   response.body = generated();
   return response;
end-proc;


   // GET /status: a data structure turned into JSON with DATA-GEN
dcl-proc status;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-ds info qualified;
      service varchar(20) inz('orders');
      orders int(10:0);
      started varchar(26);
   end-ds;
   dcl-s json varchar(1000);

   info.orders = orders_taken;
   info.started = %subst(%char(started : *iso) : 1 : 19);
      // each subfield becomes a value named after it
   data-gen info %data(json : 'doc=string output=clear')
                 %gen('YAJL/YAJLDTAGEN');

   response.status = HTTP_OK;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = json;
   return response;
end-proc;


   // {"error": text}, escaped by YAJL
dcl-proc errorJson;
   dcl-pi *n varchar(1000);
      text varchar(500) const;
   end-pi;

   yajl_genOpen(*off);
   yajl_beginObj();
   yajl_addChar('error' : text);
   yajl_endObj();
   return generated();
end-proc;


   // the JSON YAJL generated, in the job's CCSID, and the generator closed
dcl-proc generated;
   dcl-pi *n varchar(32000);
   end-pi;
   dcl-s buffer char(32000);
   dcl-s length int(10:0);

   yajl_copyBuf(0 : %addr(buffer) : %size(buffer) : length);
   yajl_genClose();
   return %subst(buffer : 1 : length);
end-proc;


   // a decimal as a JSON number: %char gives .50 for 0.50, and JSON needs
   // the 0 before the point
dcl-proc jsonNumber;
   dcl-pi *n varchar(20);
      value packed(11:2) const;
   end-pi;
   dcl-s text varchar(20);

   text = %char(value);
   if %subst(text : 1 : 1) = '.';
      text = '0' + text;
   elseif %len(text) > 1 and %subst(text : 1 : 2) = '-.';
      text = '-0' + %subst(text : 2);
   endif;
   return text;
end-proc;
