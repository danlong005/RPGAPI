**free

ctl-opt nomain option(*nodebugio:*srcstmt);

/copy RPGUNIT1,TESTCASE
/include '../qrpglesrc/rpgapi_h.rpgle'

dcl-c CRLF x'0d25';
dcl-c DBL_CRLF x'0d250d25';

// ============================================
// UTILITY FUNCTION TESTS
// ============================================

dcl-proc test_toUpper_lowercase export;
   dcl-s result varchar(32000);
   result = RPGAPI_toUpper('hello world');
   aEqual('HELLO WORLD' : result);
end-proc;

dcl-proc test_toUpper_mixedCase export;
   dcl-s result varchar(32000);
   result = RPGAPI_toUpper('HeLLo WoRLD');
   aEqual('HELLO WORLD' : result);
end-proc;

dcl-proc test_toUpper_alreadyUpper export;
   dcl-s result varchar(32000);
   result = RPGAPI_toUpper('ALREADY UPPER');
   aEqual('ALREADY UPPER' : result);
end-proc;

dcl-proc test_toUpper_empty export;
   dcl-s result varchar(32000);
   result = RPGAPI_toUpper('');
   aEqual('' : result);
end-proc;

dcl-proc test_split_comma export;
   dcl-s result char(1024) dim(50);
   result = RPGAPI_split('one,two,three' : ',');
   aEqual('one' : %trim(result(1)));
   aEqual('two' : %trim(result(2)));
   aEqual('three' : %trim(result(3)));
end-proc;

dcl-proc test_split_single export;
   dcl-s result char(1024) dim(50);
   result = RPGAPI_split('single' : ',');
   aEqual('single' : %trim(result(1)));
end-proc;

dcl-proc test_split_slash export;
   dcl-s result char(1024) dim(50);
   result = RPGAPI_split('a/b/c/d' : '/');
   aEqual('a' : %trim(result(1)));
   aEqual('b' : %trim(result(2)));
   aEqual('c' : %trim(result(3)));
   aEqual('d' : %trim(result(4)));
end-proc;

dcl-proc test_cleanString_CR export;
   dcl-s result varchar(32000);
   dcl-s dirty varchar(32000);
   dirty = 'hello' + RPGAPI_CR + 'world';
   result = RPGAPI_cleanString(dirty);
   aEqual('helloworld' : result);
end-proc;

dcl-proc test_cleanString_LF export;
   dcl-s result varchar(32000);
   dcl-s dirty varchar(32000);
   dirty = 'hello' + RPGAPI_LF + 'world';
   result = RPGAPI_cleanString(dirty);
   aEqual('helloworld' : result);
end-proc;

dcl-proc test_cleanString_CRLF export;
   dcl-s result varchar(32000);
   dcl-s dirty varchar(32000);
   dirty = 'hello' + CRLF + 'world';
   result = RPGAPI_cleanString(dirty);
   aEqual('helloworld' : result);
end-proc;

dcl-proc test_cleanString_alreadyClean export;
   dcl-s result varchar(32000);
   result = RPGAPI_cleanString('clean string');
   aEqual('clean string' : result);
end-proc;

dcl-proc test_getMessage_200 export;
   dcl-s result char(25);
   result = RPGAPI_getMessage(200);
   aEqual('OK' : %trim(result));
end-proc;

dcl-proc test_getMessage_201 export;
   dcl-s result char(25);
   result = RPGAPI_getMessage(201);
   aEqual('Created' : %trim(result));
end-proc;

dcl-proc test_getMessage_400 export;
   dcl-s result char(25);
   result = RPGAPI_getMessage(400);
   aEqual('Bad Request' : %trim(result));
end-proc;

dcl-proc test_getMessage_401 export;
   dcl-s result char(25);
   result = RPGAPI_getMessage(401);
   aEqual('Unauthorized' : %trim(result));
end-proc;

dcl-proc test_getMessage_404 export;
   dcl-s result char(25);
   result = RPGAPI_getMessage(404);
   aEqual('Not Found' : %trim(result));
end-proc;

dcl-proc test_getMessage_500 export;
   dcl-s result char(25);
   result = RPGAPI_getMessage(500);
   aEqual('Internal Server Error' : %trim(result));
end-proc;

// ============================================
// REQUEST PARSING TESTS
// ============================================

dcl-proc test_parse_simpleGet export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users HTTP/1.1' + CRLF +
                'Host: localhost' + DBL_CRLF;

   request = RPGAPI_parse(rawRequest);

   aEqual('GET' : %trim(request.method));
   aEqual('/api/users' : %trim(request.route));
   aEqual('HTTP/1.1' : %trim(request.protocol));
end-proc;

dcl-proc test_parse_withQueryString export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users?name=john&age=30 HTTP/1.1' + CRLF +
                'Host: localhost' + DBL_CRLF;

   request = RPGAPI_parse(rawRequest);

   aEqual('/api/users' : %trim(request.route));
   aEqual('name=john&age=30' : %trim(request.query_string));
   aEqual('name' : %trim(request.query_params(1).name));
   aEqual('john' : %trim(request.query_params(1).value));
   aEqual('age' : %trim(request.query_params(2).name));
   aEqual('30' : %trim(request.query_params(2).value));
end-proc;

dcl-proc test_parse_withHeaders export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users HTTP/1.1' + CRLF +
                'Host: localhost' + CRLF +
                'Content-Type: application/json' + CRLF +
                'Authorization: Bearer token123' + DBL_CRLF;

   request = RPGAPI_parse(rawRequest);

   aEqual('Host' : %trim(request.headers(1).name));
   aEqual('localhost' : %trim(request.headers(1).value));
   aEqual('Content-Type' : %trim(request.headers(2).name));
   aEqual('application/json' : %trim(request.headers(2).value));
end-proc;

dcl-proc test_parse_withBody export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'POST /api/users HTTP/1.1' + CRLF +
                'Host: localhost' + CRLF +
                'Content-Type: application/json' + DBL_CRLF +
                '{"name":"john","age":30}';

   request = RPGAPI_parse(rawRequest);

   aEqual('POST' : %trim(request.method));
   aEqual('{"name":"john","age":30}' : %trim(request.body));
end-proc;

dcl-proc test_parse_postRequest export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'POST /api/users HTTP/1.1' + CRLF +
                'Host: localhost' + DBL_CRLF;

   request = RPGAPI_parse(rawRequest);

   aEqual('POST' : %trim(request.method));
   aEqual('/api/users' : %trim(request.route));
end-proc;

// ============================================
// PARAMETER EXTRACTION TESTS
// ============================================

dcl-proc test_getQueryParam export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s result varchar(1024);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users?name=john&age=30 HTTP/1.1' + CRLF +
                'Host: localhost' + DBL_CRLF;
   request = RPGAPI_parse(rawRequest);

   result = RPGAPI_getQueryParam(request : 'name');
   aEqual('john' : result);

   result = RPGAPI_getQueryParam(request : 'age');
   aEqual('30' : result);
end-proc;

dcl-proc test_getQueryParam_caseInsensitive export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s result varchar(1024);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users?Name=john HTTP/1.1' + CRLF +
                'Host: localhost' + DBL_CRLF;
   request = RPGAPI_parse(rawRequest);

   result = RPGAPI_getQueryParam(request : 'NAME');
   aEqual('john' : result);

   result = RPGAPI_getQueryParam(request : 'name');
   aEqual('john' : result);
end-proc;

dcl-proc test_getQueryParam_notFound export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s result varchar(1024);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users?name=john HTTP/1.1' + CRLF +
                'Host: localhost' + DBL_CRLF;
   request = RPGAPI_parse(rawRequest);

   result = RPGAPI_getQueryParam(request : 'notfound');
   aEqual('' : result);
end-proc;

dcl-proc test_getHeader export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s result varchar(1024);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users HTTP/1.1' + CRLF +
                'Host: localhost' + CRLF +
                'Content-Type: application/json' + DBL_CRLF;
   request = RPGAPI_parse(rawRequest);

   result = RPGAPI_getHeader(request : 'Host');
   aEqual('localhost' : result);

   result = RPGAPI_getHeader(request : 'Content-Type');
   aEqual('application/json' : result);
end-proc;

dcl-proc test_getHeader_caseInsensitive export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s result varchar(1024);
   dcl-s rawRequest varchar(32000);

   rawRequest = 'GET /api/users HTTP/1.1' + CRLF +
                'Content-Type: application/json' + DBL_CRLF;
   request = RPGAPI_parse(rawRequest);

   result = RPGAPI_getHeader(request : 'CONTENT-TYPE');
   aEqual('application/json' : result);

   result = RPGAPI_getHeader(request : 'content-type');
   aEqual('application/json' : result);
end-proc;

// ============================================
// RESPONSE TESTS
// ============================================

dcl-proc test_setResponse_200 export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-ds response likeds(RPGAPIRSP);

   clear request;
   response = RPGAPI_setResponse(request : 200);
   iEqual(200 : response.status);
end-proc;

dcl-proc test_setResponse_404 export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-ds response likeds(RPGAPIRSP);

   clear request;
   response = RPGAPI_setResponse(request : 404);
   iEqual(404 : response.status);
end-proc;

dcl-proc test_setResponse_500 export;
   dcl-ds request likeds(RPGAPIRQST);
   dcl-ds response likeds(RPGAPIRSP);

   clear request;
   response = RPGAPI_setResponse(request : 500);
   iEqual(500 : response.status);
end-proc;

dcl-proc test_setHeader export;
   dcl-ds response likeds(RPGAPIRSP);

   clear response;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');

   aEqual('Content-Type' : %trim(response.headers(1).name));
   aEqual('application/json' : %trim(response.headers(1).value));
end-proc;

dcl-proc test_setHeader_multiple export;
   dcl-ds response likeds(RPGAPIRSP);

   clear response;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   RPGAPI_setHeader(response : 'X-Custom-Header' : 'custom-value');
   RPGAPI_setHeader(response : 'Cache-Control' : 'no-cache');

   aEqual('Content-Type' : %trim(response.headers(1).name));
   aEqual('X-Custom-Header' : %trim(response.headers(2).name));
   aEqual('Cache-Control' : %trim(response.headers(3).name));
end-proc;

// ============================================
// ROUTE REGISTRATION TESTS
// ============================================

dcl-proc test_setRoute export;
   dcl-ds config likeds(RPGAPIAPP);

   clear config;
   RPGAPI_setRoute(config : 'GET' : '/api/users' : %paddr(dummyHandler));

   aEqual('GET' : %trim(config.routes(1).method));
   aEqual('/api/users' : %trim(config.routes(1).url));
end-proc;

dcl-proc test_get_route export;
   dcl-ds config likeds(RPGAPIAPP);

   clear config;
   RPGAPI_get(config : '/api/users' : %paddr(dummyHandler));

   aEqual('GET' : %trim(config.routes(1).method));
   aEqual('/api/users' : %trim(config.routes(1).url));
end-proc;

dcl-proc test_post_route export;
   dcl-ds config likeds(RPGAPIAPP);

   clear config;
   RPGAPI_post(config : '/api/users' : %paddr(dummyHandler));

   aEqual('POST' : %trim(config.routes(1).method));
   aEqual('/api/users' : %trim(config.routes(1).url));
end-proc;

dcl-proc test_put_route export;
   dcl-ds config likeds(RPGAPIAPP);

   clear config;
   RPGAPI_put(config : '/api/users/{id}' : %paddr(dummyHandler));

   aEqual('PUT' : %trim(config.routes(1).method));
   aEqual('/api/users/{id}' : %trim(config.routes(1).url));
end-proc;

dcl-proc test_delete_route export;
   dcl-ds config likeds(RPGAPIAPP);

   clear config;
   RPGAPI_delete(config : '/api/users/{id}' : %paddr(dummyHandler));

   aEqual('DELETE' : %trim(config.routes(1).method));
   aEqual('/api/users/{id}' : %trim(config.routes(1).url));
end-proc;

dcl-proc test_multiple_routes export;
   dcl-ds config likeds(RPGAPIAPP);

   clear config;
   RPGAPI_get(config : '/api/users' : %paddr(dummyHandler));
   RPGAPI_post(config : '/api/users' : %paddr(dummyHandler));
   RPGAPI_get(config : '/api/users/{id}' : %paddr(dummyHandler));
   RPGAPI_delete(config : '/api/users/{id}' : %paddr(dummyHandler));

   aEqual('GET' : %trim(config.routes(1).method));
   aEqual('/api/users' : %trim(config.routes(1).url));
   aEqual('POST' : %trim(config.routes(2).method));
   aEqual('GET' : %trim(config.routes(3).method));
   aEqual('/api/users/{id}' : %trim(config.routes(3).url));
   aEqual('DELETE' : %trim(config.routes(4).method));
end-proc;

// ============================================
// ROUTE MATCHING TESTS
// ============================================

dcl-proc test_routeMatches_exact export;
   dcl-ds config likeds(RPGAPIAPP);
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s matches ind;

   clear config;
   clear request;

   config.routes(1).method = 'GET';
   config.routes(1).url = '/api/users';

   request.method = 'GET';
   request.route = '/api/users';

   matches = RPGAPI_routeMatches(config.routes(1) : request);
   assert(matches : 'Route should match exactly');
end-proc;

dcl-proc test_routeMatches_withParam export;
   dcl-ds config likeds(RPGAPIAPP);
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s matches ind;
   dcl-s paramValue varchar(1024);

   clear config;
   clear request;

   config.routes(1).method = 'GET';
   config.routes(1).url = '/api/users/{id}';

   request.method = 'GET';
   request.route = '/api/users/123';

   matches = RPGAPI_routeMatches(config.routes(1) : request);
   assert(matches : 'Route with param should match');

   paramValue = RPGAPI_getParam(request : 'id');
   aEqual('123' : paramValue);
end-proc;

dcl-proc test_routeMatches_multipleParams export;
   dcl-ds config likeds(RPGAPIAPP);
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s matches ind;
   dcl-s paramValue varchar(1024);

   clear config;
   clear request;

   config.routes(1).method = 'GET';
   config.routes(1).url = '/api/users/{userId}/orders/{orderId}';

   request.method = 'GET';
   request.route = '/api/users/456/orders/789';

   matches = RPGAPI_routeMatches(config.routes(1) : request);
   assert(matches : 'Route with multiple params should match');

   paramValue = RPGAPI_getParam(request : 'userId');
   aEqual('456' : paramValue);

   paramValue = RPGAPI_getParam(request : 'orderId');
   aEqual('789' : paramValue);
end-proc;

dcl-proc test_routeMatches_noMatch export;
   dcl-ds config likeds(RPGAPIAPP);
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s matches ind;

   clear config;
   clear request;

   config.routes(1).method = 'GET';
   config.routes(1).url = '/api/users';

   request.method = 'GET';
   request.route = '/api/products';

   matches = RPGAPI_routeMatches(config.routes(1) : request);
   assert(not matches : 'Route should not match');
end-proc;

dcl-proc test_routeMatches_wrongMethod export;
   dcl-ds config likeds(RPGAPIAPP);
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s matches ind;

   clear config;
   clear request;

   config.routes(1).method = 'GET';
   config.routes(1).url = '/api/users';

   request.method = 'POST';
   request.route = '/api/users';

   matches = RPGAPI_routeMatches(config.routes(1) : request);
   assert(not matches : 'Route should not match with wrong method');
end-proc;

// ============================================
// MIDDLEWARE TESTS
// ============================================

dcl-proc test_setMiddleware export;
   dcl-ds config likeds(RPGAPIAPP);

   clear config;
   RPGAPI_setMiddleware(config : '/api/*' : %paddr(dummyMiddleware));

   aEqual('/api/*' : %trim(config.middlewares(1).url));
end-proc;

dcl-proc test_mwMatches_global export;
   dcl-ds config likeds(RPGAPIAPP);
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s matches ind;

   clear config;
   clear request;

   config.middlewares(1).url = '*';

   request.method = 'GET';
   request.route = '/any/route/here';

   matches = RPGAPI_mwMatches(config.middlewares(1) : request);
   assert(matches : 'Global middleware should match all routes');
end-proc;

dcl-proc test_mwMatches_specific export;
   dcl-ds config likeds(RPGAPIAPP);
   dcl-ds request likeds(RPGAPIRQST);
   dcl-s matches ind;

   clear config;
   clear request;

   config.middlewares(1).url = '/api/users';

   request.method = 'GET';
   request.route = '/api/users';

   matches = RPGAPI_mwMatches(config.middlewares(1) : request);
   assert(matches : 'Specific middleware should match route');
end-proc;

// ============================================
// DUMMY HANDLERS FOR TESTING
// ============================================

dcl-proc dummyHandler;
   dcl-pi *n likeds(RPGAPIRSP);
      request likeds(RPGAPIRQST) const;
   end-pi;
   dcl-ds response likeds(RPGAPIRSP);

   clear response;
   response.status = 200;
   response.body = 'OK';
   return response;
end-proc;

dcl-proc dummyMiddleware;
   dcl-pi *n ind;
      request likeds(RPGAPIRQST) const;
      response likeds(RPGAPIRSP);
   end-pi;

   return *on;
end-proc;
