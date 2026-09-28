# RPGAPI Documentation

### Application Data Structures
```
        //
        // the request data structure
        //
        dcl-ds RPGAPI_Request qualified template;
          body varchar(32000);
          headers likeds(RPGAPI_header_ds) dim(100);
          hostname char(250);
          method char(10);
          params likeds(RPGAPI_param_ds) dim(100);
          protocol char(8);
          query_params likeds(RPGAPI_param_ds) dim(100);
          query_string char(1024);
          route char(250);
          header_text varchar(32000);              // for RPGAPI_getHeader
          remote_ip varchar(45);                   // see Client address
          connection_ip varchar(45);
        end-ds;

        //
        // the response data structure
        //
        dcl-ds RPGAPI_Response qualified template;
          body varchar(32000);
          headers likeds(RPGAPI_header_ds) dim(100);
          status int(10:0);
        end-ds;

        //
        // the application data structure
        //
        dcl-ds RPGAPI_App qualified template;
          port int(10:0);                          // default is 3000
          socket_descriptor int(10:0);
          return_socket_descriptor int(10:0);
          routes likeds(RPGAPI_route_ds) dim(250);
          middlewares likeds(RPGAPI_route_ds) dim(100);
          jobs int(10:0);                          // see Settings
          log_level int(10:0);
          max_request_size int(10:0);
          max_upload_size int(10:0);
          read_timeout int(10:0);
          write_timeout int(10:0);
          tls_application_id varchar(100);
          tls_keystore varchar(1024);
          tls_password varchar(128);
          tls_label varchar(128);
          cors_origins varchar(2000);              // see CORS
          cors_credentials ind;
          cors_max_age int(10:0);
          cors_allow_headers varchar(1000);
          cors_expose_headers varchar(1000);
          keepalive_timeout int(10:0);             // see Keep-alive
          keepalive_requests int(10:0);
          not_found_handler pointer(*proc);        // see Not found and errors
          error_handler pointer(*proc);
          trusted_proxies varchar(1000);           // see Client address
          route_prefix varchar(1000);              // see Groups
          statics likeds(RPGAPI_static_ds) dim(20); // see Serving a directory
          security_headers ind;                     // see Security headers
          content_security_policy varchar(2000);
        end-ds;

        //
        // what went wrong, for an error handler
        //
        dcl-ds RPGAPI_Error qualified template;
          status int(10:0);
          message_id char(7);
          message_text varchar(400);
        end-ds;

        dcl-ds RPGAPI_header_ds qualified template;
          name char(50);
          value varchar(1024);
        end-ds;

        dcl-ds RPGAPI_param_ds qualified template;
          name char(50);
          value varchar(1024);
        end-ds;

        dcl-ds RPGAPI_route_ds qualified template;
          method char(10);
          url varchar(32000);
          procedure pointer(*proc);
        end-ds;
```

### Application
For a simple application to get you up and running checkout our [Quick Start](QuickStart.md) guide. This will get you up and running with a RPG web application in no time.

#### Callbacks
To create web application in RPGAPI you have to follow a simple pattern on your callbacks(procedures) that process the requests. 

```
dcl-proc index;
  dcl-pi *n likeds(RPGAPI_Response);
    request likeds(RPGAPI_Request) const;
  end-pi;
  dcl-ds response likeds(RPGAPI_Response) inz;

  ...your code...

  response.status = HTTP_OK;
  return response;
end-proc;
```
You will notice that the procedure takes a RPGAPI_Request(RPGAPI request) and returns a RPGAPI_Response(RPGAPI response). That's it! Inside of the method you can create whatever you need and load it into the response before you return it. We will dive more into this later.

Declare the response with `inz`, in the procedure. Without it, RPG fills the
data structure with blanks, which leaves `status` a meaningless number, and a
response declared outside the procedure keeps the headers of earlier requests.

#### Kicking off the application
Once you have registered some routes in the app data structure you can start the application so that your app can start handling request. You can start the application using the following api call

```
RPGAPI_start(app);
```

or add the port on the start command
```
RPGAPI_start(app: 3000);
```

or configure the port via the app
```
app.port = 3000;
RPGAPI_start(app);
```
_NOTE:_ The default port is 3000.

`RPGAPI_start` serves requests until its job ends, so start your program in a
job of its own (`SBMJOB CMD(CALL PGM(MYLIB/MYAPP))`) and end that job to stop
the server. The [Quick Start](QuickStart.md) shows the whole cycle.

#### Settings
Everything about how the server runs is in the app data structure. `clear app`
first: a setting left at 0 or blank gets its default when `RPGAPI_start` runs.
Set them with these procedures, which check the values, before
`RPGAPI_start`:

| Setting | Procedure | Default |
| --- | --- | --- |
| `port` | `app.port = 8080`, or `RPGAPI_start(app : 8080)` | 3000 |
| `jobs` | `app.jobs = 4`, or `RPGAPI_start(app : 8080 : 4)` | 1 |
| `log_level` | `RPGAPI_setLogLevel(app : RPGAPI_LOG_INFO)` | off |
| `max_request_size` | `RPGAPI_setMaxRequestSize(app : bytes)` | 1MB |
| `max_upload_size` | `RPGAPI_setMaxUploadSize(app : bytes)` | 0, off |
| `read_timeout`, `write_timeout` | `RPGAPI_setTimeouts(app : readSeconds : writeSeconds)` | 30, 30 |
| `tls_...` | `RPGAPI_setTlsApplication(app : id)` or `RPGAPI_setTlsKeystore(app : path : password : label)` | plain HTTP |
| `cors_...` | `RPGAPI_setCors(app : origins)`, and the other `cors_` fields; see CORS | no CORS |
| `keepalive_timeout`, `keepalive_requests` | `RPGAPI_setKeepAlive(app : seconds : maxRequests)`; see Keep-alive | 5 seconds, 100 requests |
| `trusted_proxies` | `RPGAPI_setTrustedProxies(app : addresses)`; see Client address | none |
| `security_headers`, `content_security_policy` | `RPGAPI_setSecurityHeaders(app : policy?)`; see Security headers | off |
| `compression`, `compression_threshold` | `RPGAPI_setCompression(app : minBytes?)`; see Compression | off; 1024 bytes |
| `views_directory`, `views_library` | `RPGAPI_setViews(app : directory : library?)`; see Views | the job's current directory; the app's library |
| `not_found_handler`, `error_handler` | `RPGAPI_setNotFound(app : %paddr(proc))`, `RPGAPI_setErrorHandler(app : %paddr(proc))`; see Not found and errors | plain 404 and 500 |

A setter given a value it does not accept ends your program with escape
message `CPF9898` saying why. Every job serving the app, including the extra
jobs below, runs your program and so gets the same settings.

#### Handling several requests at once
By default one job handles one request at a time. Pass the number of jobs to
serve with as a third parameter:
```
RPGAPI_start(app : 3000 : 4);
```
The job that calls `RPGAPI_start` opens the port and starts 3 more jobs, each
running the program this job was started with (the first program on the call
stack outside `QSYS`, e.g. `MYAPP` for `SBMJOB CMD(CALL MYAPP)`). Each of them
registers its routes and serves the same port, and every connection goes to
one of the jobs that is free. Keep in mind that:
- the program is started again without parameters, so it must not need any,
  and whatever it does before `RPGAPI_start` it does in every job
- the jobs have the same name and library list as the one you started
- to stop the server, end the job you started, or call `RPGAPI_shutdown()`
  (see Stopping the server). The others end with it, each once it has
  finished the request it is on, and the job you started waits for them
- a job that ends while the server runs (it failed, or someone ended it) is
  replaced by the job you started, once that job is between requests, and
  logged at WARN. At most 5 are replaced a minute, so a job that keeps failing
  does not keep the server busy starting it

#### Stopping the server
`ENDJOB` ends a job controlled by default (`OPTION(*CNTRLD) DELAY(30)`), and
so does `ENDSBS *CNTRLD`. RPGAPI then takes no new requests and lets the ones
in progress finish before the job ends, within the delay. An idle kept-open
connection is closed. `ENDJOB OPTION(*IMMED)` stops at once, cutting off
requests in progress.

```
ENDJOB JOB(MYAPP)                        // finish the requests in progress
ENDJOB JOB(MYAPP) OPTION(*IMMED)         // stop now
```

To stop the server from the app itself, such as from an admin route or at a
cutoff time, call `RPGAPI_shutdown()` in a route or middleware. It works as
the controlled `ENDJOB` does, in every job serving the app, whichever of them
took the request: each finishes the request it is on and takes no more. The
request that called it is answered first, with `Connection: close`. Then
`RPGAPI_start` returns, in the job you started once all of its jobs have
ended, and the job goes on with what follows it in your program.
```
dcl-proc stopServer;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;

   RPGAPI_shutdown();
   return RPGAPI_setResponse(request : HTTP_ACCEPTED);
end-proc;
```
Guard such a route, e.g. with middleware checking credentials (see
Authentication): anyone who can call it can stop the server.

#### HTTPS
Call one of these before `RPGAPI_start` to serve HTTPS instead of HTTP:
```
RPGAPI_setTlsApplication(app : 'MYCO_RPGAPI_ORDERS');   // DCM application ID
RPGAPI_setTlsKeystore(app : path : password : label);   // or a certificate store
RPGAPI_start(app : 8443);
```
Everything else works the same over HTTPS. The certificate has to be set up in
Digital Certificate Manager first; the README's HTTPS (TLS) section has the
steps and the error messages. Each job sets up TLS when it starts, and
`RPGAPI_start` ends with an escape message if it cannot. A client has 30
seconds to complete its TLS handshake; one that fails it is disconnected.

If the server cannot listen on the port, such as when another job is
already using it, `RPGAPI_start` ends with escape message `CPF9898` naming the
failed call and the reason, for example:
```
bind() failed for port 3000: Address already in use. (errno 3420).
```
Monitor for it if your program should handle this itself.

Requests are converted from UTF-8 to the job's CCSID before your procedures see
them, and responses from the job's CCSID to UTF-8, so `Content-Length` counts
UTF-8 bytes. Compile your application with `TGTCCSID(*JOB)`, as described in
the README under Character sets, so that its literals are in the job's CCSID
as well.

#### Keep-alive
A connection stays open after a response, so the client can send its next
request without connecting again, as browsers and HTTP client libraries do.
Responses say `Connection: keep-alive` and `Keep-Alive: timeout=5`.

- It is kept 5 seconds for the next request, for up to 100 requests;
  `RPGAPI_setKeepAlive(app : 15 : 1000)` changes that, and
  `RPGAPI_setKeepAlive(app : 0)` turns keep-alive off.
- Each job serves one connection at a time, so a job waiting on an idle kept
  connection closes it when a new connection is waiting: keep-alive does not
  keep other clients waiting. A connection is only closed like this once it
  has been quiet for 250ms after its response, so a client sending its next
  request right away is answered, not cut off. A new client therefore waits
  at most 250ms for an idle connection's job, and a busy connection keeps its
  job until its request limit. Clients open a new connection when they find
  theirs closed.
- The connection is closed instead after a request the client sent with
  `Connection: close` (or HTTP/1.0 without `Connection: keep-alive`), a
  refused request (413, 431, ...), a request body your procedure did not read
  to the end, and a streamed response to an HTTP/1.0 client.
- Requests a client sends one after the other without waiting (pipelining)
  are answered in order.

Each job handles one connection at a time, so a client has 30 seconds (the
read timeout, see Settings) to send its whole request. If it has not by then, or it closes the connection before the
headers are complete, the connection is closed without a response and the next
one is accepted.

Likewise, a client that takes none of a response for 30 seconds (the write
timeout), for example
one that stopped reading a large download, is given up on and its connection
closed. From then on `RPGAPI_write` and `RPGAPI_writeBytes` do nothing, so a
procedure writing rows still runs to its end and can close what it opened.


#### Routing
To create routes in your application we have given you several ways to create those. 

First up is the setRoute method. This can be used for all types of routes. POST, PATCH, PUT, DELETE, GET... etc You simply pass the application data structure, METHOD, url and a pointer to the procedure you want to call when this route is hit. 

```
RPGAPI_setRoute(app : METHOD : url : %paddr(procedure));
RPGAPI_setRoute(app : HTTP_PUT : '/api/users/{id}' : %paddr(USR_update));
```
The method is compared as it is sent, so give it in upper case. `HTTP_GET`,
`HTTP_POST`, `HTTP_PUT`, `HTTP_PATCH` and `HTTP_DELETE` are defined for you.

There are also the following methods that are more descriptive that you may want to use for creating your routes.

```
RPGAPI_get(app : url : %paddr(procedure));
RPGAPI_post(app : url : %paddr(procedure));
RPGAPI_put(app : url : %paddr(procedure));
RPGAPI_delete(app : url : %paddr(procedure));
RPGAPI_patch(app : url : %paddr(procedure));
```

We find that these make the code _MUCH_ more readable.

##### Defining Routes
For route params you can define routes in the following way
```
RPGAPI_get(app: '/v1/things/{id}': %paddr(procedure));
```
Now there will be a route param of id that will be available to you in the produre that is ran when this route is matched. 

You can gain access to that param using the following code. This will be a string value. Convert it as needed. 
```
RPGAPI_getParam(request: 'id');
```

A route has to match the whole path, one `/` segment at a time. `/api/users`
matches `/api/users` and `/api/users/`, but not `/api/users/1` or
`/x/api/users`. A `{name}` segment matches any one segment and captures it as a
param, and `*` matches any one segment without capturing it.

Routes are tried in the order they were added, and the first that matches
handles the request. Since a route matches the whole path, order only matters
when two routes match the same one, such as a fixed segment and a param in the
same place: add the fixed one first.
```
RPGAPI_get(app : '/api/v1/memberships/new' : %paddr(MBR_new));
RPGAPI_get(app : '/api/v1/memberships/{id}' : %paddr(MBR_show));
RPGAPI_get(app : '/api/v1/memberships' : %paddr(MBR_index));
```
A request that matches no route gets `404 Not Found` (see Not found and
errors). An app can have up to 250 routes and 100 middleware; adding one more
ends your program with escape message `CPF9898` saying so, instead of the
route never answering.

##### Groups
Routes that share the start of their path, such as an API version, can be
added as a group: `RPGAPI_setPrefix` puts a prefix in front of the path of
every route and middleware added after it, until the next `RPGAPI_setPrefix`.
`''` ends the group.

```
RPGAPI_setPrefix(app : '/api/v1');
RPGAPI_setMiddleware(app : '*' : %paddr(needKey));   // /api/v1 and below only
RPGAPI_get(app : '/notes' : %paddr(listNotes));       // GET /api/v1/notes
RPGAPI_get(app : '/notes/{id}' : %paddr(getNote));    // GET /api/v1/notes/{id}
RPGAPI_get(app : '/' : %paddr(apiInfo));              // GET /api/v1

RPGAPI_setPrefix(app : '/shops/{shop}');
RPGAPI_get(app : '/orders' : %paddr(shopOrders));     // RPGAPI_getParam(request : 'shop')

RPGAPI_setPrefix(app : '');
RPGAPI_get(app : '/status' : %paddr(status));         // GET /status, no key needed
```

In a group, middleware for `'*'` is for the group's paths only (the prefix
and everything below it), so a check such as an API key covers the group and
nothing else. A prefix can have `{params}`, and a missing `/` in front of the
prefix or a path, or a `/` at the end of the prefix, is added or dropped.
Groups do not nest: each `RPGAPI_setPrefix` replaces the last. The prefix is
kept in `app.route_prefix`.

##### HEAD and OPTIONS
- A `HEAD` request is answered by the `GET` route for its path (unless you add
  a `HEAD` route), with the same status and headers, including the
  `Content-Length` the body would have, but without the body. Your procedure
  runs as for `GET`, and sees `request.method = 'HEAD'`. Streamed responses
  and `RPGAPI_sendFile` send only their headers too.
- An `OPTIONS` request for a path that has routes, but no `OPTIONS` route of
  its own, is answered with `204` and an `Allow` header listing their methods,
  such as `GET, HEAD, POST, OPTIONS`. It goes through middleware first.
  `HTTP_HEAD` and `HTTP_OPTIONS` name the methods for `RPGAPI_setRoute`.

#### CORS
A page from another origin (scheme, host and port), such as a front end on
`https://app.example.com` calling the API on `https://api.example.com`, may only
use the API's responses when the API allows that origin. Name the origins:

```
RPGAPI_setCors(app : 'https://app.example.com https://admin.example.com');
app.cors_credentials = *on;          // let the browser send cookies along
app.cors_max_age = 600;              // cache preflight answers 10 minutes
app.cors_expose_headers = 'X-Total'; // headers scripts may read
RPGAPI_start(app);
```

| Field | Default | |
| --- | --- | --- |
| `cors_origins` | blank: no CORS | origins, separated by spaces or commas, or `*` for any |
| `cors_credentials` | `*off` | send `Access-Control-Allow-Credentials: true` |
| `cors_max_age` | 0: not sent | seconds a browser may cache a preflight answer |
| `cors_allow_headers` | blank: the ones asked for | request headers allowed in preflight answers |
| `cors_expose_headers` | blank | response headers scripts may read |

- A request from an allowed origin gets `Access-Control-Allow-Origin` with its
  origin (or `*` when any origin is allowed without credentials), with
  `Vary: Origin`, on every response, errors included. Other origins get no
  CORS headers, so the browser keeps the response from the page.
- A preflight (an `OPTIONS` request with `Origin` and
  `Access-Control-Request-Method`) is answered with `204` before any
  middleware runs, since browsers never send credentials with it: an auth
  middleware would refuse it. It lists the methods of the routes for the path
  in `Access-Control-Allow-Methods`.
- Headers you set yourself, such as `Access-Control-Allow-Origin`, are left
  as you set them.

### Middleware

#### Global Middleware 
For global middleware you can create do the following.

```
  RPGAPI_setMiddleware(app: RPGAPI_GLOBAL_MIDDLEWARE: %paddr(CHECK_AUTH));
```
or
```
  RPGAPI_setMiddleware(app: '*': %paddr(CHECK_AUTH));
```
if you don't want to type the constant name.


#### Route Middleware

To create middleware on your routes you can use the following method.

```
  RPGAPI_setMiddleware(app : '/api/v1/memberships' : %paddr(CHECK_AUTH));
```

Route middleware runs for its own path and every path below it, so the one
above also runs for `/api/v1/memberships/5`, but not for
`/api/v1/membershipsX` or `/x/api/v1/memberships`. `{name}` and `*` segments
work the same as in routes.

and the defintion of the middleware callback is as follows

```
  dcl-proc CHECK_AUTH;
    dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
    end-pi;

    return *on;
  end-proc;
```

If you want to continue the request after the middleware method has ran then 
return *on, else you can return *off and the request will be cancelled. You of 
course will need to set the response accordingly in the middleware.

Every middleware that matches runs once per request, in the order it was
added, before the route. It runs even when no route matches the request.


### Requests
Given that you followed the outline specs for your callback procedures the request datastructure will be passed into the method that is handing the current request. You can find everything out about the request by looking in the request data structure. 

#### Headers
These are the headers that came in on the request. You can access those headers using the following api method

```
header_value = RPGAPI_getHeader(request : 'Content-Type');
```
The name is matched in any case, `''` is returned for a header that was not
sent, and the whole value is returned however long it is, such as a long
bearer token or a large `Cookie` header. `request.headers` also lists the
first 50 headers, but with their values cut at 1,024 characters: use
`RPGAPI_getHeader` to read values.

`request.hostname` is the host the client asked for: the `Host` header without
its port, as Express's `req.hostname`. For `Host: api.example.com:8080` it is
`api.example.com`, for `Host: [::1]:3000` it is `[::1]`, and it is blank when
the request has no `Host` header.

#### Cookies
`RPGAPI_getCookie` returns a cookie the browser sent, from the `Cookie` header:

```
session_id = RPGAPI_getCookie(request : 'session');
```
The name is matched exactly (cookie names are case-sensitive), a value in
quotes comes back without them, and `%XX` escapes are decoded, as Express's
`req.cookies` does, so a value set with `RPGAPI_setCookie` comes back as it was
set. A cookie that was not sent gives `''`.

#### Authentication
Two procedures read the credentials a client sends in the `Authorization`
header:

```
   // Authorization: Bearer <token>: API keys, JWTs, OAuth access tokens
token = RPGAPI_getBearerToken(request);

   // Authorization: Basic ...: curl -u, a browser's login prompt
if RPGAPI_getBasicAuth(request : user : password);
   ...
endif;
```

`RPGAPI_getBearerToken` returns the token, or `''` when the request has none.
`RPGAPI_getBasicAuth` decodes the user and password and returns `*on`, or
`*off` when there are none (no header, another scheme, or a value that is not
base64 or has no `:`). The password may contain colons; both are read as UTF-8
and are up to 256 characters. The scheme is matched in any case.

Checking them is up to your app, usually in middleware, so a route never runs
without them. Answer `401`; for Basic, add a `WWW-Authenticate` header, so a
browser asks for a user and password:

```
dcl-proc needLogin;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;
   dcl-s user varchar(256);
   dcl-s password varchar(256);

   if RPGAPI_getBasicAuth(request : user : password) and
      validLogin(user : password);             // your check
      return *on;
   endif;
   response.status = HTTP_UNAUTHORIZED;
   RPGAPI_setHeader(response : 'WWW-Authenticate' : 'Basic realm="orders"');
   return *off;
end-proc;
```

Basic credentials are only encoded, not encrypted, and a bearer token lets
anyone who has it in: serve them over HTTPS (see HTTPS in the README). RPGAPI
does not write the `Authorization` header to the log.

##### Checking IBM i user profiles
`RPGAPI_checkUserProfile` checks a user and password against the system's user
profiles, so an API can use the IBM i sign-on its users already have:

```
if RPGAPI_getBasicAuth(request : user : password) and
   RPGAPI_checkUserProfile(user : password : message_id);
   ...                                        // signed on as user
endif;
```

It returns `*on` when the password is right, using the system's
`QSYGETPH` API; the handle it gets is released at once, so your job keeps
running as its own user. `message_id` tells you why not, for your log (not for
the client): `CPF22E2` for a wrong password, which the system also answers for
a user that does not exist, `CPF22E3` for a disabled profile, `CPF22E4` for an
expired password. Before asking the system, it refuses a user name starting
with `*` (such as `*CURRENT`) or longer than 10 characters, an empty password,
and `*NOPWD`, `*NOPWDCHK` and `*NOPWDSTS`, which would otherwise get a handle
without any password.

Know what it means before you use it:

- Every wrong password counts toward the system's limit on sign-on attempts
  (system value `QMAXSIGN`), exactly as at a sign-on screen. A client that
  guesses can disable a real user's profile, which then cannot sign on
  anywhere until it is re-enabled. Allow it only over HTTPS, only for the
  users who need it, and consider limiting attempts per client address
  (`request.remote_ip`).
- A client that has the password can use the API as that user: use it for
  users you would trust with it, and check what each may do in your app.
- Checking a password takes the system some time; for many requests from the
  same client, sign on once and give the client a token of your own.

#### Client address
`request.remote_ip` is the client's IP address, as Express's `req.ip`, for
logging, limits or allowing only some addresses. `request.connection_ip` is
the address the connection came from. Without a proxy in front of the app,
they are the same.

Behind a proxy, such as nginx, IBM HTTP Server or a load balancer, every
connection comes from the proxy, and the proxy passes the client's address in
the `X-Forwarded-For` header. List the proxies' addresses, so that RPGAPI uses
it:

```
RPGAPI_setTrustedProxies(app : '10.0.0.5 10.0.0.6');
```

Only a request whose connection comes from one of them gets `remote_ip` from
`X-Forwarded-For`; anyone else could send the header with any address. The
header lists every hop (`client, proxy1, proxy2`), and a client can put
addresses of its own in front, so RPGAPI reads it from the right, skipping
the trusted proxies: the first address that is not one of them is the client.
`'*'` trusts every connection and takes the leftmost address; use it only when
nothing can reach the app except through the proxy. Addresses are compared
exactly (no ranges such as `10.0.0.0/8`).

The INFO log line for each request shows `remote_ip`, as in
`GET /hello from 203.0.113.9 -> 200, 11 bytes, 3 ms`.

#### Params
These are the route params that came in on the request. To define route params in your route see the section on routing. You can access the params using the following api method

```
id_value = RPGAPI_getParam(request : 'id');
```
Params and query values are URL decoded, as Express does: `%20` becomes a
space and `%C3%BC` a `ü` (escapes are read as UTF-8, then converted to the
job's CCSID). In query names and values `+` is a space too; in params it stays
a `+`. An escape that is not two hex digits, or bytes that are not UTF-8, are
left as they were sent. Routes are matched on the path as it was sent, so an
encoded `/` (`%2F`) stays inside its segment and arrives in the param.
`request.route` and `request.query_string` keep the text as it was sent.

#### Body
To access the body of the request you can use the following variable in the 
request data structure.

```
body_value = request.body;
```

`request.body` holds a body of up to 32,000 characters. Bodies can be larger:
up to 1MB by default, sent with a `Content-Length` or with
`Transfer-Encoding: chunked`. Any body, whatever its size, can be read in
pieces:

```
size = RPGAPI_bodyLength(request);          // bytes, as sent

piece = RPGAPI_readBody(request);           // text in the job's CCSID
dow piece <> '';
  ...
  piece = RPGAPI_readBody(request);
enddo;
```

For binary content (images, PDFs, ...) read the bytes as they were sent,
without conversion, into a buffer of your own:

```
count = RPGAPI_readBodyBytes(request : %addr(buffer) : %size(buffer));
dow count > 0;
  ...
  count = RPGAPI_readBodyBytes(request : %addr(buffer) : %size(buffer));
enddo;
```

Both read from the same position, so use one or the other for a request.

Change the limit, up to 16,000,000 bytes, before starting the app:

```
RPGAPI_setMaxRequestSize(app : 5000000);
RPGAPI_start(app);
```

#### Uploads larger than memory
Bodies over the request size limit can be allowed too, up to a second, larger
limit (at most 2GB):

```
RPGAPI_setMaxUploadSize(app : 500000000);   // 500MB; 0, the default, is off
RPGAPI_start(app);
```

Such a body is not read into memory before your procedure is called. It is
read from the connection as your procedure asks for it, with the same
`RPGAPI_readBody` and `RPGAPI_readBodyBytes`, so memory stays the same
whatever its size. To store it in a file:

```
if RPGAPI_saveBody(request : '/uploads/' + name);   // *off: cannot create it
   response.status = HTTP_CREATED;
endif;
```

- A client that sent `Expect: 100-continue` is only asked for the body when
  your procedure first reads it. A procedure that refuses without reading it
  (say with 403) is never sent it.
- `RPGAPI_bodyLength` is -1 while a chunked body's size is not known yet.
- When the body turns out larger than the upload limit, is not valid, or
  stops arriving for the read timeout, the read ends your procedure with an escape
  message and the request is answered with 413, 400 or 408. Monitor for it if
  your procedure has to clean up.
- A body your procedure does not read is dropped.

#### Forms with files (multipart/form-data)
Browsers send a form with a file input, and `curl -F`, as
`multipart/form-data`: a body of parts, one per field or file. Go through them
with `RPGAPI_nextPart`, which describes each part in an `RPGAPI_Part`:

```
dcl-ds part likeds(RPGAPI_Part);      // name, filename, content_type

dow RPGAPI_nextPart(request : part);
   if part.filename = '';
         // a form field: its text, in pieces for long values
      value = RPGAPI_readPart(request);
   else;
         // a file: save it, or read it with RPGAPI_readPartBytes
      size = RPGAPI_savePart(request : '/uploads/' + %char(%timestamp()));
   endif;
enddo;
```

- Parts are read from the body as you go, never all at once, so the size of
  the files is only bounded by the request and upload limits above. Allow
  larger uploads with `RPGAPI_setMaxUploadSize`.
- `RPGAPI_readPart` returns the next piece of the part as text in the job's
  CCSID and `''` at its end; `RPGAPI_readPartBytes` copies raw bytes, and
  `RPGAPI_savePart` writes the rest of the part to an IFS file and returns
  its size (-1 when the file cannot be created).
- Whatever you do not read of a part is skipped when you move to the next.
- `RPGAPI_nextPart` returns `*off` at the end, and for a body that is not
  `multipart/form-data`. A body that is not valid multipart ends your
  procedure with an escape message and a 400, like the other body errors.
- `part.filename` is what the client sent. Never use it as a path: build the
  file name yourself, as above.
- Use either the parts or `RPGAPI_readBody` / `RPGAPI_readBodyBytes` for a
  request, not both.

Requests that are refused before your procedures are called:
| Status | When |
| --- | --- |
| 413 Content Too Large | the body is larger than the limit. With `Expect: 100-continue` this is answered before the client sends it |
| 431 Request Header Fields Too Large | the request line and headers are over 32,000 bytes |
| 400 Bad Request | `Content-Length` is not a number, or a chunk is not valid |
| 501 Not Implemented | a `Transfer-Encoding` other than `chunked` |

A streamed upload that is too large, not valid or stops arriving is answered
with 413, 400 or 408 once your procedure reads it (see above). A procedure that
fails with an error it does not handle gets `500 Internal Server Error`.

#### QueryString/QueryParams
The query string can be accessed in two different ways.

First you can get they full query string by access the query_string variable 
in the request data structure

```
query_string_value = request.query_string;
```

or you can access the various values in the query string using the following
method

```
query_string_param = RPGAPI_getQueryParam(request : 'q');
```
Note: q would be the param name in the query string like `q=fish`

#### Forms
An HTML form sent with `method="post"` (and no `enctype`) arrives as an
`application/x-www-form-urlencoded` body, `name=J%C3%BCrgen+Long&tag=a&tag=b`.
`RPGAPI_getFormParam` reads a field from it, decoded as query params are:
`+` is a space and `%XX` escapes are UTF-8.

```
name = RPGAPI_getFormParam(request : 'name');          // Jürgen Long
second_tag = RPGAPI_getFormParam(request : 'tag' : 2); // b
```

The name is matched in any case, as for `RPGAPI_getQueryParam`. The optional
third parameter picks the nth field with the name, for checkboxes and
multiple selects; it is `''` past the last one. A field that was not sent, or
was sent empty, gives `''`, and so does any body with another `Content-Type`.
Values can be up to 32,000 characters, such as a long `<textarea>`, and the
whole body is searched, also past what `request.body` holds; a body larger
than the request size limit (1MB), which is streamed from the connection, is
not. Forms with files (`enctype="multipart/form-data"`) are read with
`RPGAPI_nextPart`; see Forms with files.

#### Protocol
The protocol that the request used can be accessed using the following variable 
on the request data structure.

```
protocol = request.protocol;
```

#### Method
The method that the request used can be accessed using the following variable 
on the request data structure.

```
method = request.method;
```

#### Route
The route that the request used can be accessed using the following variable 
on the request data structure.

```
route = request.route;
```

### Responses
The response object is something you will create in the callback methods. Inside the callback method you will define the response and return it from your callback. 
```
  dcl-ds response likeds(RPGAPI_Response) inz;

  return response;
```
After the response the connection is kept open for the client's next request
(see Keep-alive).

#### Headers
You can set response headers very easily. The following is an example. 

```
RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
```
Up to 100 headers can be set. `Connection`, `Content-Length` and
`Transfer-Encoding` are set by RPGAPI from how the body is sent; values you set
for them are left out. A line break in a header name or value becomes a blank,
so request data you put in a header (a file name, a redirect) cannot add
headers of its own.

#### Security headers
Browsers have protections they only turn on when a response asks for them:
not guessing a file's type, not letting other sites show the page in a frame,
not sending the page's address along with links, and more. Express apps get
them from `helmet`; RPGAPI adds the same ones to every response (routes,
404s, errors, static files, streamed responses) after one call:

```
RPGAPI_setSecurityHeaders(app);
```

| Header | Value |
| --- | --- |
| `Content-Security-Policy` | helmet's default, `RPGAPI_DEFAULT_CSP`: `default-src 'self'` and the rest |
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Cross-Origin-Resource-Policy` | `same-origin` |
| `Origin-Agent-Cluster` | `?1` |
| `Referrer-Policy` | `no-referrer` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains`, only with HTTPS |
| `X-Content-Type-Options` | `nosniff` |
| `X-DNS-Prefetch-Control` | `off` |
| `X-Download-Options` | `noopen` |
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-Permitted-Cross-Domain-Policies` | `none` |
| `X-XSS-Protection` | `0` |

The Content-Security-Policy only lets a page load scripts, styles and images
from its own site. That is right for an API and for most pages, but blocks a
page with inline `<script>` or scripts from another site: pass your own
policy, or `''` for none:

```
RPGAPI_setSecurityHeaders(app : 'default-src ''self''; script-src ''self'' https://cdn.example.com');
RPGAPI_setSecurityHeaders(app : '');
```

A header a procedure sets itself is sent instead of RPGAPI's, so one route
can have its own policy or `X-Frame-Options`. `Cross-Origin-Resource-Policy:
same-origin` does not stop other sites from calling the API through CORS
(see CORS), but it does stop them from embedding its responses as images or
scripts; a route that serves those to other sites sets
`Cross-Origin-Resource-Policy: cross-origin`. The settings are the app's
`security_headers` and `content_security_policy` fields.

#### Cookies
`RPGAPI_setCookie` adds a `Set-Cookie` header; call it once per cookie. Without
options the cookie is for the whole site (`Path=/`) and lasts until the browser
closes:

```
RPGAPI_setCookie(response : 'theme' : 'dark');
```
For the other attributes, pass an `RPGAPI_CookieOptions`:

```
dcl-ds options likeds(RPGAPI_CookieOptions) inz(*likeds);

options.max_age = 3600;          // seconds; Expires is sent too
options.http_only = *on;         // not readable from JavaScript
options.secure = *on;            // HTTPS only
options.same_site = 'Lax';       // Strict, Lax or None
RPGAPI_setCookie(response : 'session' : session_id : options);
```
| Field | Attribute | Default |
| --- | --- | --- |
| `path` | `Path` | `/` |
| `domain` | `Domain` | none: only the host that set it |
| `max_age` | `Max-Age` and `Expires` | 0: until the browser closes |
| `http_only` | `HttpOnly` | off |
| `secure` | `Secure` | off |
| `same_site` | `SameSite` (`Strict`, `Lax` or `None`) | none: the browser decides |

This sends `Set-Cookie: session=...; Max-Age=3600; Path=/; Expires=...;
HttpOnly; Secure; SameSite=Lax`. The value is sent `%XX` encoded as UTF-8, as
Express does, so it can hold spaces, `;` and characters outside ASCII;
`RPGAPI_getCookie` decodes it. Browsers need `secure` for `SameSite=None`.

`RPGAPI_clearCookie` tells the browser to delete a cookie (`Max-Age=0` and an
`Expires` in 1970). Pass the same `path` and `domain` it was set with:

```
RPGAPI_clearCookie(response : 'session');
```
A name that is not one a cookie can have (it has to be letters, digits or
``!#$%&'*+-.^_`|~``), a `path` or `domain` with a `;`, an unknown `same_site`,
or a cookie longer than the 1,024 characters a response header holds ends your
procedure with an escape message (CPF9898) that says which; the request is
answered with a 500, and the message is logged at
`RPGAPI_LOG_ERROR`.

#### Body
Setting the body of the response can be done like so.

```
response.body = 'Here is the body!';
```
The body is sent exactly as it is set, blanks included. When you set it from a
fixed-length (`char`) field, trim it, or its trailing blanks go out too:
`response.body = %trim(row.name);`. `response.body` holds up to 32,000
characters; for more, see Large responses and streaming.

#### Status
Once again setting the status is a simple thing to to do.

```
response.status = 200;
response.status = HTTP_CREATED;          // 201

// a redirect
response.status = HTTP_FOUND;            // 302
RPGAPI_setHeader(response : 'Location' : '/api/v1/memberships/5');
```

These statuses have constants, and are sent with their reason phrase. Any other
status is sent with an empty one, which clients accept.

For a response that is just a status, with no body or headers, as Express's
`res.sendStatus`:

```
return RPGAPI_setResponse(request : HTTP_NO_CONTENT);
```

| Constant | Status |
| --- | --- |
| `HTTP_OK` | 200 OK |
| `HTTP_CREATED` | 201 Created |
| `HTTP_ACCEPTED` | 202 Accepted |
| `HTTP_NO_CONTENT` | 204 No Content |
| `HTTP_PARTIAL_CONTENT` | 206 Partial Content |
| `HTTP_MOVED_PERMANENTLY` | 301 Moved Permanently |
| `HTTP_FOUND` | 302 Found |
| `HTTP_NOT_MODIFIED` | 304 Not Modified |
| `HTTP_BAD_REQUEST` | 400 Bad Request |
| `HTTP_UNAUTHORIZED` | 401 Unauthorized |
| `HTTP_FORBIDDEN` | 403 Forbidden |
| `HTTP_NOT_FOUND` | 404 Not Found |
| `HTTP_REQUEST_TIMEOUT` | 408 Request Timeout |
| `HTTP_CONTENT_TOO_LARGE` | 413 Content Too Large |
| `HTTP_RANGE_NOT_SATISFIABLE` | 416 Range Not Satisfiable |
| `HTTP_HEADERS_TOO_LARGE` | 431 Request Header Fields Too Large |
| `HTTP_INTERNAL_SERVER` | 500 Internal Server Error |
| `HTTP_NOT_IMPLEMENTED` | 501 Not Implemented |

#### Large responses and streaming
`response.body` holds up to 32,000 characters. For anything larger, or to send
rows as they are read, stream the response instead of returning it: begin it
with the status and headers of a response, write the body in as many pieces
as you like, then end it.

```
RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
RPGAPI_beginResponse(response);
RPGAPI_write('[');
// ... RPGAPI_write(...) for each row ...
RPGAPI_write(']');
RPGAPI_endResponse();
return response;            // not sent again: the response has gone out
```

- `RPGAPI_write(text)` converts text from the job's CCSID to UTF-8.
- `RPGAPI_writeBytes(%addr(buffer) : length)` sends bytes as they are, for
  binary content.
- Writes are collected and sent in pieces of 32KB, so writing a row at a time
  is fine.
- The body is sent with `Transfer-Encoding: chunked`. If you know its size in
  bytes up front, pass it and it is sent with a `Content-Length` instead:
  `RPGAPI_beginResponse(response : 11)`.
- A response you do not end is ended when your procedure returns. If your
  procedure fails after beginning it, the connection is closed, and the
  client can tell the response is incomplete.

#### Sending files
`RPGAPI_sendFile` sends an IFS file of any size as it is stored, with a
`Content-Length` and a `Content-Type` from its extension (`html`, `css`, `js`,
`json`, `txt`, `csv`, `xml`, `svg`, `png`, `jpg`, `gif`, `ico`, `pdf`, `zip`,
otherwise `application/octet-stream`). Headers you set on the response are
sent too, and a `Content-Type` you set is used instead.

```
if not RPGAPI_sendFile(response : '/www/files/' + RPGAPI_getParam(request : 'name'));
   response.status = HTTP_NOT_FOUND;
endif;
return response;
```

It returns `*off`, having sent nothing, when the file cannot be opened or the
path contains a `..` segment, so your procedure can answer instead. Text files
are sent as stored, so keep them in UTF-8 or ASCII.

Like Express, it also sends `Last-Modified`, an `ETag`, `Accept-Ranges: bytes`
and `Cache-Control: public, max-age=0` (unless you set a `Cache-Control`), and
for a GET it answers:
- `If-None-Match` / `If-Modified-Since` with **304 Not Modified** and no body
  when the client's copy is current
- `Range: bytes=...` (one range) with **206 Partial Content** and just those
  bytes, or **416 Range Not Satisfiable** when the range is outside the file.
  Several ranges get the whole file, and so does a range whose `If-Range`
  names an older version of the file

#### Serving a directory
`RPGAPI_serveStatic` serves the files of an IFS directory below a path, such as
a web page with its styles, scripts and images, the way `express.static` does:

```
RPGAPI_serveStatic(app : '/web' : '/www/myapp');
```

`GET /web/css/app.css` then sends `/www/myapp/css/app.css`, through
`RPGAPI_sendFile`, so with the same content types, caching headers, `304`s
and ranges. `/web/` sends `/www/myapp/index.html`, and a directory asked for
without its `/` at the end (`/web`, `/web/docs`) is redirected to it, so the
relative links in its `index.html` work. A directory without an `index.html`
is not listed.

- Only `GET` and `HEAD` are served, after the middleware (so a login check
  covers the files too) and before the routes. A path with no file behind it
  goes on to the routes, and then to the 404.
- The path is decoded one segment at a time (`%20`, UTF-8 names), and a path
  that could leave the directory is not served: a `.` or `..` segment, or one
  that decodes to one with `/`, `\` or a NUL (`%2e%2e`, `..%2f`). Files and
  directories whose name starts with `.` (such as `.env`) are not served
  either.
- The directory has to exist: `RPGAPI_serveStatic` ends your program with
  `CPF9898` when it does not. It follows `RPGAPI_setPrefix`, and an app can
  serve up to 20 directories (`app.statics`).
- The files are sent as stored, so keep text files in UTF-8 or ASCII, and the
  job needs authority to read them. A symbolic link in the directory is
  followed, wherever it points.

#### Compression
`RPGAPI_setCompression` gzips responses for the clients that accept it, as
Express's `compression` middleware does. JSON and text usually shrink to a
fifth or less, which matters for large responses on slow connections:
```
RPGAPI_setCompression(app);            // bodies of 1024 bytes and more
RPGAPI_setCompression(app : 10000);    // or from another size
```
A response is gzipped when:
- the request's `Accept-Encoding` allows gzip (`gzip`, `x-gzip` or `*`, and
  not with `q=0`). Browsers, curl with `--compressed`, and most HTTP clients
  send one
- its `Content-Type` is text: `text/...`, JSON, JavaScript, XML, SVG, or a
  type ending in `+json` or `+xml`. Images, PDFs and zip files are already
  compressed and are sent as they are, as is a response with no
  `Content-Type`
- its body is at least that size. A streamed response of unknown length is
  always gzipped
- your procedure did not set a `Content-Encoding` of its own or
  `Cache-Control: no-transform`, and it is not a 204 or 304

It then has `Content-Encoding: gzip`, and every response with a text type
has `Vary: Accept-Encoding` so that caches keep a copy for each kind of
client (unless your procedure sets its own `Vary`). Nothing changes in your
procedures:
- a body in `response.body` is gzipped in one piece, with its gzipped length
  as `Content-Length`
- a streamed response is gzipped as it is written and sent in chunks, also
  when `RPGAPI_beginResponse` was given its length (HTTP/1.0 clients get it
  up to the connection's close). The pieces come out as zlib fills them, not
  after each `RPGAPI_write`
- `RPGAPI_sendFile` and `RPGAPI_serveStatic` gzip text files, without
  `Accept-Ranges` and without answering a `Range`: the whole file is sent.
  `304`s work as before

RPGAPI uses the zlib that comes with IBM i, service program `QSYS/QZIPZLIB`
(the one behind IBM's zip APIs), so there is nothing to install. The service
program is bound to it when it is built.

### Working with JSON
RPGAPI hands your procedure the request body as text and sends back the text
you put in `response.body`: building and reading JSON is up to your program.
Do not build JSON by joining strings with your data in them: a quote, a
backslash or a line break in a value breaks the document (or lets a client
change it). Let one of these do it; each escapes values properly and handles
characters outside ASCII. Set `Content-Type: application/json` on the
response either way.

**SQL's JSON functions** are part of Db2 for i, so there is nothing to
install, and they are the shortest way when the data comes from tables:

```
   // one row as an object
exec sql select json_object('id' value id,
                            'first_name' value trim(fname),
                            'last_name' value trim(lname))
           into :json
           from members where id = :id;

   // all rows as an array ('[]' when there are none)
exec sql select coalesce(json_arrayagg(
                  json_object('id' value id, 'title' value title)
                  order by id), '[]')
           into :json
           from notes;

   // fields of the request body; a missing one is null
body = request.body;
exec sql select title, text into :title :title_ind, :text :text_ind
           from json_table(:body, 'lax $'
                columns(title varchar(100) path 'lax $.title',
                        text varchar(2000) path 'lax $.text'));

   // one value, and whether the body is JSON at all
exec sql values json_value(:body, 'lax $.customer') into :customer;
exec sql values case when :body is json then 1 else 0 end into :valid;
```

`JSON_OBJECT` and `JSON_ARRAY` nest, and `ABSENT ON NULL` leaves out null
values. See [notes-api.sqlrpgle](examples/notes-api.sqlrpgle) (a whole JSON
API over a table) and [memberships.sqlrpgle](examples/memberships.sqlrpgle).

**`DATA-INTO` and `DATA-GEN` with YAJL** map JSON onto RPG data structures,
nested ones and arrays included. They need
[YAJL](https://www.scottklement.com/yajl/), which many IBM i shops have
installed; RPGAPI does not need it. The subfield names are the JSON names:

```
dcl-ds order qualified;
   customer varchar(100);
   num_items int(10:0);             // how many items came (countprefix)
   dcl-ds items dim(20);
      sku varchar(20);
      qty int(10:0);
   end-ds;
end-ds;

data-into order %data(request.body :
                      'case=any countprefix=num_ allowmissing=yes allowextra=yes')
                %parser('YAJL/YAJLINTO');

data-gen status %data(json : 'doc=string output=clear')
                %gen('YAJL/YAJLDTAGEN');
```

Put `DATA-INTO` in a `monitor` block and answer 400 when it fails: the client
sent something that is not JSON, or not the shape you expect.

**YAJL's generator** builds a document piece by piece, for output whose shape
depends on the data:

```
yajl_genOpen(*off);                      // *on: indented, for reading
yajl_beginObj();
yajl_addChar('customer' : order.customer);
yajl_beginArray('items');
for index = 1 to order.num_items;
   yajl_beginObj();
   yajl_addChar('sku' : order.items(index).sku);
   yajl_addNum('qty' : %char(order.items(index).qty));
   yajl_endObj();
endfor;
yajl_endArray();
yajl_endObj();
yajl_copyBuf(0 : %addr(buffer) : %size(buffer) : length);  // 0: the job's CCSID
yajl_genClose();
response.body = %subst(buffer : 1 : length);
```

`yajl_addNum` takes the number as text, and `%char` of a decimal below 1 gives
`.50`, which is not valid JSON: add the leading 0. See
[yajl-orders.rpgle](examples/yajl-orders.rpgle), which uses all three YAJL
ways; YAJL has to be in the library list to build and run it.

`request.body` holds bodies of up to 32,000 characters. For larger JSON, read
the body with `RPGAPI_readBody`, or save it with `RPGAPI_saveBody` and parse
the file (`DATA-INTO` with `doc=file`, or YAJL's `yajl_stmf_load_tree`). For
large responses,
see Large responses and streaming.

### Views (HTML templates)
A view is a page written as HTML with RPG inside tags, the way Express apps
use EJS templates. A route passes it values and lists and returns
`RPGAPI_render`, and the page it makes is streamed to the browser:
```
dcl-proc listCustomers;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds vars likeds(RPGAPI_Vars) inz;

   RPGAPI_setVar(vars : 'title' : 'Customers');
   RPGAPI_setList(vars : 'customers' :
      'select name, city, balance from customers where state = ?' :
      RPGAPI_getQueryParam(request : 'state'));
   return RPGAPI_render('customers.erpg' : vars);
end-proc;
```
The view, `customers.erpg`:
```
<%! dcl-ds customer_t qualified template;
       name varchar(50);
       city varchar(50);
       balance packed(11:2);
     end-ds;
     dcl-ds customers likeds(customer_t) dim(*var : 500);
     dcl-ds customer likeds(customer_t); -%>
<% customers = RPGAPI_getList('customers'); -%>
<h1><%= RPGAPI_getVar('title') %></h1>
<ul>
<% for-each customer in customers; -%>
  <li><%= customer.name %>, <%= customer.city %>: <%= customer.balance %></li>
<% endfor; -%>
</ul>
```

RPG cannot run code it reads while it runs, so RPGAPI compiles each view into
a program the first time it is asked for, and again whenever the template
changes: edit a view and refresh the page. That first request takes a few
seconds; the rest just call the program.

#### Tags
| Tag | |
| --- | --- |
| `<% code %>` | RPG statements: `for-each`, `if`, `dow`, `exec sql`, calls. Each ends with `;` as usual |
| `<%= expr %>` | A value, HTML-escaped: `&`, `<`, `>`, `"` and `'` become entities, so a value from a user or a table cannot add tags or scripts to the page. Numbers and dates are formatted with `%char` |
| `<%- expr %>` | A value as it is, for HTML you built and trust |
| `<%# text %>` | A comment, left out of the page |
| `<%! decls %>` | Declarations: `dcl-s`, `dcl-ds`, `dcl-c`. They go first in the view's program wherever they are in the template |
| `<%%` | A literal `<%` |
| `-%>` | Ends any tag and leaves out the line break after it, so a line holding only a tag leaves no blank line in the page |

Everything else is text, written as it is.

#### Values and lists
The route puts what the view needs into an `RPGAPI_Vars`, by name. Declare it
with `inz` in the procedure; it lasts until the request ends.

| In the route | In the view |
| --- | --- |
| `RPGAPI_setVar(vars : 'title' : text)` | `RPGAPI_getVar('title')`, as text: numbers with `%dec`, dates with `%date` |
| `RPGAPI_setList(vars : 'rows' : sql : value1? ... value5?)` | `array = RPGAPI_getList('rows');` |
| `RPGAPI_addRow(vars : 'rows')`, then `RPGAPI_setField(vars : 'rows' : 'name' : text)` | the same |
| `RPGAPI_listCount(vars : 'rows')` | `RPGAPI_rows('rows')` |

A list is rows of named fields:
- `RPGAPI_setList` runs an SQL query and makes a row of each row it returns,
  with a field for each column, named after the column (`select cust_name as
  name` names it). Values for `?` markers in the statement come after it, up
  to five, so what a user typed never becomes part of the SQL. A statement
  that fails ends the route with escape message `CPF9898` naming the SQL
  state, which is answered with a 500.
- `RPGAPI_addRow` and `RPGAPI_setField` build one in RPG, a row at a time, for
  data that does not come from one query.

In the view, `array = RPGAPI_getList('rows');` fills an array of a data
structure you declare, with `dim(*var : max)`: fields go into the subfields of
the same name (in any case), converted to their types, so `balance` is a
number and `since` a date. Afterwards `%elem(array)` is the number of rows,
and `for-each` goes through them. Fields without a subfield are ignored,
subfields without a field (and nulls) keep their default, and a list longer
than `max` is cut to it. Keep the statement on a line of its own.

#### Views in views, SQL, and responses
- `<% RPGAPI_include('pagetop.erpg'); -%>` writes another view in place, with
  the same values: shared headers and footers.
- A view can run its own SQL too, `exec sql` and all; it is then compiled with
  `CRTSQLRPGI`. Close the cursors it opens.
- `RPGAPI_render(template : vars : response)` sends the view with the status
  and headers of `response`, such as a cookie, or a `Content-Type` other than
  `text/html; charset=utf-8`. With compression on, views are gzipped like any
  text.

#### Where views are, and where they are compiled
```
RPGAPI_setViews(app : '/home/me/myapp/views');            // templates
RPGAPI_setViews(app : '/home/me/myapp/views' : 'MYVIEWS'); // and a library
```
A template path that does not start with `/` is relative to that directory
(the job's current directory without it). The programs go into the library
named, or the library of the app's program, and are named `RV` and 8 hex
digits, after the template's file name and content. The job needs the ILE RPG
compiler (5770WDS) and authority to create programs there. Old versions are
not deleted; any `RV...` program can be, and is compiled again when needed.

For a server without the compiler, compile the views where there is one, and
bring the library along: a view is found by its name and content, so the same
template uses the same program.
```
CALL PGM(MYLIB/ERPG) PARM('/home/me/myapp/views/customers.erpg' 'MYVIEWS')
```
`ERPG`, which `make all` builds, compiles one view into a library, and is
also a quick way to check a template.

#### When a view is wrong
A view that does not compile, or a template with a tag that is never closed,
is answered with a 500 page listing the errors at their template lines, such
as `customers.erpg:7: RNF7030 The name or indicator NMAE is not defined.`,
and logged at ERROR. Every line of the generated program carries a comment
naming its template line (the source is in `/tmp/RPGAPI_RV....rpgle`). A view
that fails while it runs ends the page there, as a streamed response does.

**Good to know**
- Templates are UTF-8, with or without a byte order mark; Windows line breaks
  are fine. Their text goes through the job's CCSID, as everything written
  with `RPGAPI_write` does.
- A view's program has its own variables, so it cannot see the route's: pass
  what it needs with `RPGAPI_setVar` and `RPGAPI_setList`.
- `RPGAPI_writeHtml(text)` and `RPGAPI_escapeHtml(text)`, which `<%= %>` uses,
  work in any streamed response.
- Not in this version: layouts, EJS's `<%_ _%>`, and passing a view the
  request itself.

[examples/html-page.rpgle](examples/html-page.rpgle) is a complete app: a
library's tables from the SQL catalog, in a view that includes another.

### Health checks
Load balancers and monitoring tools poll a URL to see whether an API is up,
and take a server out of rotation when it does not answer `200`. A health
check is a route of your own, since only your app knows what it needs to
work, such as its database:

```
RPGAPI_get(app : '/health' : %paddr(health));

dcl-proc health;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;
   dcl-s one int(10:0);

   exec sql values 1 into :one;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   if sqlcode = 0;
      response.status = HTTP_OK;
      response.body = '{"status":"up"}';
   else;
      response.status = 503;               // Service Unavailable: "down"
      response.body = '{"status":"down","sqlcode":' + %char(sqlcode) + '}';
   endif;
   return response;
end-proc;
```

Keep it quick, and keep it out of the way of authentication: put middleware
that checks credentials on the paths that need it (such as `/api`) rather
than on `*`, or let it pass `/health`. With several jobs, each request goes
to whichever job takes it, so a check answered is one job answering; the
INFO log shows every request, and WARN a worker job that ended and was
replaced.

### Not found and errors
Without handlers, a request no route matches is answered with a plain `404`,
and a request that fails with a plain `500` (or `400`, `408`, `413`, `431` or
`501` for a request RPGAPI refused). An API usually wants its own answer, such
as a JSON error body. Two procedures set that up, like a catch-all route and
an error-handling middleware in Express:

```
RPGAPI_setNotFound(app : %paddr(notFound));
RPGAPI_setErrorHandler(app : %paddr(failed));
```

**The not-found handler** is a route procedure (request in, response out). It
runs when no route matches, after the middleware, so middleware that refuses a
request (such as an API key check) still answers first. A status left at 0 is
sent as `404`. An `OPTIONS` request for a path that has routes is still
answered by RPGAPI with the methods it allows.

```
dcl-proc notFound;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = HTTP_NOT_FOUND;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = '{"error":"no route for ' + %trim(request.route) + '"}';
   return response;
end-proc;
```

**The error handler** gets the request and an `RPGAPI_Error`, and returns the
response to send. It is called when:

- a route, a middleware or the not-found handler ends with an escape message
  (a failed operation, such as a division by zero, `MCH1211`, or a message
  your code sent). `status` is `500`, and `message_id` and `message_text` are
  the escape message;
- a request body fails while your procedure reads it (too large, a timeout,
  bad chunked or multipart data). `status` is `413`, `408` or `400`, and the
  message is RPGAPI's `CPF9898`, such as `The request body ...`;
- a request is refused before any procedure runs (a body over the limits,
  headers too large, a bad request line). `status` is `413`, `431`, `400` or
  `501`, `message_id` is blank and `message_text` is the status's reason
  phrase, such as `Content Too Large`. The request's fields may be blank.

```
dcl-proc failed;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
      error likeds(RPGAPI_Error) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = error.status;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = '{"error":"' + %char(error.status) + '","id":"' +
                   %trim(error.message_id) + '"}';
   return response;
end-proc;
```

A status left at 0 is sent as `error.status`. The failure is still logged
(at `RPGAPI_LOG_ERROR`, "answered by the error handler"), so send the message
text to clients only if they should see it. The handler is not called once a
streamed response has begun: the client has its status already, so the
connection is closed as before. If the error handler fails too, both failures
are logged and the client gets the plain status.

### Logging
RPGAPI can log what it does to the job log of the job serving each request,
to find out what happened when someone reports a problem. It is off unless
you set a level:

```
RPGAPI_setLogLevel(app : RPGAPI_LOG_INFO);
RPGAPI_start(app);
```

| Level | Logs |
| --- | --- |
| `RPGAPI_LOG_OFF` | nothing (the default) |
| `RPGAPI_LOG_ERROR` | procedures that fail, with the exception they ended with (such as `MCH1211 Attempt made to divide by zero`); files that cannot be saved; TLS or port setup that fails |
| `RPGAPI_LOG_WARN` | the above, and requests refused and why (413, 431, 400, 501), request bodies that are too large, not valid or stop arriving, clients that time out or stop taking a response, TLS handshakes that fail |
| `RPGAPI_LOG_INFO` | the above, the settings the server started with, and one line per request: method, path, status, bytes sent and milliseconds |
| `RPGAPI_LOG_DEBUG` | the above, and each connection, the request line and headers, which middleware ran and which route matched, how the body was read, the parts of a multipart body, and what `RPGAPI_sendFile` decided |

Each message is an informational message (`CPF9897`) that starts with
`RPGAPI` and its level, and the messages of one request carry its number in
the job, so they can be picked out of a busy job log:

```
RPGAPI INFO: serving port 8080 in 1 job(s), plain HTTP, request limit 1048576 bytes, ...
RPGAPI DEBUG #4: request GET /boom HTTP/1.1
RPGAPI DEBUG #4: route GET /boom matched
RPGAPI ERROR #4: GET /boom failed: MCH1211 Attempt made to divide by zero for fixed point operation.; answered 500
RPGAPI INFO #4: GET /boom -> 500, 76 bytes, 10 ms
```

Read them with `DSPJOBLOG` for the server's job (`WRKACTJOB`, option 5 then
10), or with SQL, which suits a job log with many messages:

```sql
SELECT message_timestamp, message_text
  FROM TABLE(QSYS2.JOBLOG_INFO('123456/MYUSER/MYAPP'))
  WHERE message_text LIKE 'RPGAPI %';
```

- With several jobs, each logs to its own job log; they all have the name of
  the job you started.
- The values of `Authorization`, `Proxy-Authorization` and `Cookie` headers
  are not logged. Other headers and the request line are, at DEBUG.
- DEBUG and INFO add messages to the job log for every request: a job log that
  fills up wraps or spills to a spooled file depending on the job's
  `LOG` and job message queue settings (`QJOBMSGQMX`, `QJOBMSGQFL`). Use
  them while looking into a problem, and WARN or ERROR otherwise.

### Procedure reference
These are the procedures the service program exports, which are the ones
`rpgapi_h.rpgle` declares. RPGAPI's internal procedures are in
`rpgapi_int_h.rpgle`, for RPGAPI itself and its unit tests; apps do not
include it.

| Procedure | Purpose |
| --- | --- |
| `RPGAPI_start(app : port? : jobs?)` | Serve requests; see Kicking off the application |
| `RPGAPI_shutdown()` | Stop the server once the requests in progress are answered; see Stopping the server |
| `RPGAPI_setCors(app : origins)` | Allow browsers on these origins to call the app; see CORS |
| `RPGAPI_setSecurityHeaders(app : policy?)` | Browser protection headers on every response; see Security headers |
| `RPGAPI_setCompression(app : minBytes?)` | gzip text and JSON responses for clients that accept it; see Compression |
| `RPGAPI_setTrustedProxies(app : addresses)` | Proxies whose `X-Forwarded-For` gives the client's address; see Client address |
| `RPGAPI_setNotFound(app : %paddr(proc))` | Answer requests no route matches; see Not found and errors |
| `RPGAPI_setErrorHandler(app : %paddr(proc))` | Answer requests that fail; see Not found and errors |
| `RPGAPI_setKeepAlive(app : seconds : maxRequests?)` | How long connections stay open between requests, 0 for not at all |
| `RPGAPI_setLogLevel(app : level)` | How much to log; see Logging |
| `RPGAPI_setTimeouts(app : readSeconds : writeSeconds)` | How long clients have to send a request and take a response |
| `RPGAPI_setTlsApplication(app : application_id)` | Serve HTTPS with the certificate of a DCM application ID |
| `RPGAPI_setTlsKeystore(app : path : password : label?)` | Serve HTTPS with a certificate from a certificate store file |
| `RPGAPI_get` / `post` / `put` / `patch` / `delete(app : url : %paddr(proc))` | Add a route for that method |
| `RPGAPI_setRoute(app : method : url : %paddr(proc))` | Add a route for any method |
| `RPGAPI_setMiddleware(app : url : %paddr(proc))` | Add middleware for a path and everything below it, or `*` for all |
| `RPGAPI_setPrefix(app : prefix)` | Put a prefix in front of the routes and middleware added next; see Groups |
| `RPGAPI_getParam(request : name)` | A route param |
| `RPGAPI_getQueryParam(request : name)` | A query string value |
| `RPGAPI_getFormParam(request : name : occurrence?)` | A field of an HTML form body; see Forms |
| `RPGAPI_getHeader(request : name)` | A request header |
| `RPGAPI_getBearerToken(request)` | The token of `Authorization: Bearer`; see Authentication |
| `RPGAPI_getBasicAuth(request : user : password)` | The user and password of `Authorization: Basic`; see Authentication |
| `RPGAPI_checkUserProfile(user : password : message_id?)` | Whether the password is right for an IBM i user profile; see Checking IBM i user profiles |
| `RPGAPI_setHeader(response : name : value)` | Add a response header |
| `RPGAPI_setResponse(request : status)` | A response with just a status; see Status |
| `RPGAPI_getCookie(request : name)` | A cookie the client sent |
| `RPGAPI_setCookie(response : name : value : options?)` | Set a cookie; see Cookies under Responses |
| `RPGAPI_clearCookie(response : name : options?)` | Delete a cookie |
| `RPGAPI_setMaxRequestSize(app : bytes)` | The largest body read into memory (1MB) |
| `RPGAPI_setMaxUploadSize(app : bytes)` | The largest body streamed from the connection (0, off) |
| `RPGAPI_bodyLength(request)` | The body's size in bytes, -1 while unknown |
| `RPGAPI_readBody(request)` | The next piece of the body as text |
| `RPGAPI_readBodyBytes(request : buffer : size)` | The next piece of the body as bytes |
| `RPGAPI_saveBody(request : path)` | Write the body to an IFS file |
| `RPGAPI_nextPart(request : part)` | Move to the next part of a multipart/form-data body |
| `RPGAPI_readPart(request)` | The next piece of the current part as text |
| `RPGAPI_readPartBytes(request : buffer : size)` | The next piece of the current part as bytes |
| `RPGAPI_savePart(request : path)` | Write the rest of the current part to an IFS file |
| `RPGAPI_beginResponse(response : length?)` | Send the status and headers of a streamed response |
| `RPGAPI_write(text)` | Add text to a streamed response |
| `RPGAPI_render(template : vars? : response?)` | Send a view: a template of HTML with RPG in it; see Views |
| `RPGAPI_setVar(vars : name : value)` | A value for a view |
| `RPGAPI_setList(vars : name : sql : values?)` | A list for a view, from an SQL query |
| `RPGAPI_addRow(vars : name)`, `RPGAPI_setField(vars : name : field : value)` | A list for a view, row by row |
| `RPGAPI_listCount(vars : name)` | The rows of a list |
| `RPGAPI_setViews(app : directory : library?)` | Where views are, and where they are compiled; see Views |
| `RPGAPI_writeHtml(text)` | Add text to a streamed response, HTML-escaped |
| `RPGAPI_escapeHtml(text)` | Text with `& < > " '` as HTML entities |
| `RPGAPI_writeBytes(buffer : length)` | Add bytes to a streamed response |
| `RPGAPI_endResponse()` | Finish a streamed response |
| `RPGAPI_sendFile(response : path)` | Send an IFS file |
| `RPGAPI_serveStatic(app : url : directory)` | Serve the files of an IFS directory below a path; see Serving a directory |
