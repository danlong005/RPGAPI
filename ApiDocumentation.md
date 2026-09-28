# RPGAPI API reference

RPGAPI is a web framework for ILE RPG in the spirit of Express. This page
describes every procedure, data structure and constant that `rpgapi_h.rpgle`
declares, grouped the way Express groups its API: the application, the
request, the response, and views. The guides at the end explain how the
pieces work together (several jobs, HTTPS, CORS, uploads, JSON, logging, and
so on).

New to RPGAPI? Start with the [Quick Start](QuickStart.md), and see
[examples](examples/README.md) for complete apps.

In the signatures, a parameter ending in `?` can be left out.

The same reference is a web page with a sidebar in
[docs/index.html](docs/index.html), for GitHub Pages or to open locally;
`python3 docs/build.py` builds it from this file.

## Contents

**[Getting started](#getting-started)**:
[a route procedure](#a-route-procedure) ·
[a middleware procedure](#a-middleware-procedure) ·
[starting the app](#starting-the-app)

**[Application](#application)**: [RPGAPI_App](#rpgapi_app)
- Running: [RPGAPI_start](#rpgapi_start) ·
  [RPGAPI_shutdown](#rpgapi_shutdown)
- Routes: [RPGAPI_get, post, put, patch, delete](#rpgapi_get-rpgapi_post-rpgapi_put-rpgapi_patch-rpgapi_delete) ·
  [RPGAPI_setRoute](#rpgapi_setroute) ·
  [RPGAPI_setPrefix](#rpgapi_setprefix) ·
  [RPGAPI_setMiddleware](#rpgapi_setmiddleware) ·
  [RPGAPI_serveStatic](#rpgapi_servestatic) ·
  [RPGAPI_setNotFound](#rpgapi_setnotfound) ·
  [RPGAPI_setErrorHandler](#rpgapi_seterrorhandler)
- Settings: [RPGAPI_setLogLevel](#rpgapi_setloglevel) ·
  [RPGAPI_setMaxRequestSize](#rpgapi_setmaxrequestsize) ·
  [RPGAPI_setMaxUploadSize](#rpgapi_setmaxuploadsize) ·
  [RPGAPI_setTimeouts](#rpgapi_settimeouts) ·
  [RPGAPI_setKeepAlive](#rpgapi_setkeepalive) ·
  [RPGAPI_setCors](#rpgapi_setcors) ·
  [RPGAPI_setSecurityHeaders](#rpgapi_setsecurityheaders) ·
  [RPGAPI_setCompression](#rpgapi_setcompression) ·
  [RPGAPI_setTrustedProxies](#rpgapi_settrustedproxies) ·
  [RPGAPI_setTlsApplication](#rpgapi_settlsapplication) ·
  [RPGAPI_setTlsKeystore](#rpgapi_settlskeystore) ·
  [RPGAPI_setViews](#rpgapi_setviews) ·
  [RPGAPI_setLayout](#rpgapi_setlayout)

**[Request](#request)**: [RPGAPI_Request](#rpgapi_request)
- Values: [RPGAPI_getParam](#rpgapi_getparam) ·
  [RPGAPI_getQueryParam](#rpgapi_getqueryparam) ·
  [RPGAPI_getHeader](#rpgapi_getheader) ·
  [RPGAPI_getCookie](#rpgapi_getcookie) ·
  [RPGAPI_getFormParam](#rpgapi_getformparam)
- Credentials: [RPGAPI_getBearerToken](#rpgapi_getbearertoken) ·
  [RPGAPI_getBasicAuth](#rpgapi_getbasicauth) ·
  [RPGAPI_checkUserProfile](#rpgapi_checkuserprofile)
- Body: [RPGAPI_bodyLength](#rpgapi_bodylength) ·
  [RPGAPI_readBody](#rpgapi_readbody) ·
  [RPGAPI_readBodyBytes](#rpgapi_readbodybytes) ·
  [RPGAPI_saveBody](#rpgapi_savebody)
- Forms with files: [RPGAPI_Part](#rpgapi_part) ·
  [RPGAPI_nextPart](#rpgapi_nextpart) ·
  [RPGAPI_readPart](#rpgapi_readpart) ·
  [RPGAPI_readPartBytes](#rpgapi_readpartbytes) ·
  [RPGAPI_savePart](#rpgapi_savepart)

**[Response](#response)**: [RPGAPI_Response](#rpgapi_response)
- Headers and status: [RPGAPI_setHeader](#rpgapi_setheader) ·
  [RPGAPI_setResponse](#rpgapi_setresponse) ·
  [RPGAPI_setCookie](#rpgapi_setcookie) ·
  [RPGAPI_CookieOptions](#rpgapi_cookieoptions) ·
  [RPGAPI_clearCookie](#rpgapi_clearcookie)
- Streaming: [RPGAPI_beginResponse](#rpgapi_beginresponse) ·
  [RPGAPI_write](#rpgapi_write) ·
  [RPGAPI_writeBytes](#rpgapi_writebytes) ·
  [RPGAPI_writeHtml](#rpgapi_writehtml) ·
  [RPGAPI_escapeHtml](#rpgapi_escapehtml) ·
  [RPGAPI_endResponse](#rpgapi_endresponse)
- Files and pages: [RPGAPI_sendFile](#rpgapi_sendfile) ·
  [RPGAPI_render](#rpgapi_render)

**[Views](#views)**: [how views work](#how-views-work) ·
[tags](#tags) · [RPGAPI_data](#rpgapi_data) ·
[RPGAPI_include](#rpgapi_include) ·
[layouts](#layouts) · [RPGAPI_body](#rpgapi_body) ·
[where views are compiled](#where-views-are-compiled) ·
[ERPG](#erpg) · [when a view is wrong](#when-a-view-is-wrong)

**[Constants and other data structures](#constants-and-other-data-structures)**:
[status codes](#status-codes) · [methods](#methods) ·
[log levels](#log-levels) · [RPGAPI_Error](#rpgapi_error) ·
[other constants](#other-constants) ·
[internal data structures](#internal-data-structures)

**[Guides](#guides)**:
[routing rules](#routing-rules) ·
[several jobs](#several-jobs) ·
[stopping the server](#stopping-the-server) ·
[HTTPS](#https) ·
[keep-alive and timeouts](#keep-alive-and-timeouts) ·
[CORS](#cors) ·
[security headers](#security-headers) ·
[compression](#compression) ·
[client address](#client-address) ·
[request bodies and uploads](#request-bodies-and-uploads) ·
[authentication](#authentication) ·
[streaming responses](#streaming-responses) ·
[files and directories](#files-and-directories) ·
[working with JSON](#working-with-json) ·
[health checks](#health-checks) ·
[not found and errors](#not-found-and-errors) ·
[logging](#logging) ·
[character sets](#character-sets)

---

## Getting started

### A route procedure
A route is a procedure that takes the request and returns the response:

```rpgle
dcl-proc index;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   // ...your code...

   response.status = HTTP_OK;
   response.body = 'Hello';
   return response;
end-proc;
```

Declare the response with `inz`, in the procedure. Without it, RPG fills the
data structure with blanks, which leaves `status` a meaningless number, and a
response declared outside the procedure keeps the headers of earlier
requests.

### A middleware procedure
Middleware runs before the route and can end the request itself. It gets the
request and the response, and returns `*on` to go on to the route, or `*off`
to answer with the response it set:

```rpgle
dcl-proc checkAuth;
   dcl-pi *n ind;
      request likeds(RPGAPI_Request) const;
      response likeds(RPGAPI_Response);
   end-pi;

   if RPGAPI_getBearerToken(request) = '';
      response.status = HTTP_UNAUTHORIZED;
      return *off;
   endif;
   return *on;
end-proc;
```

### Starting the app
Declare the app, `clear` it, register routes and settings, and start it:

```rpgle
dcl-ds app likeds(RPGAPI_App);

clear app;
RPGAPI_get(app : '/' : %paddr(index));
RPGAPI_start(app : 3000);

*inlr = *on;
return;
```

`RPGAPI_start` serves requests until its job ends, so run the program in a job
of its own (`SBMJOB CMD(CALL PGM(MYLIB/MYAPP))`) and end that job to stop the
server. Compile with `TGTCCSID(*JOB)` (see [character sets](#character-sets)).

---

## Application

### RPGAPI_App
The app: its routes, middleware and settings. Declare one, `clear` it, and
pass it to the procedures below. A setting left at 0 or blank gets its
default when `RPGAPI_start` runs. Set them with the procedures, which check
the values, before `RPGAPI_start`.

| Field | Set with | Default |
| --- | --- | --- |
| `port` | `app.port = 8080`, or [RPGAPI_start](#rpgapi_start)`(app : 8080)` | 3000 |
| `jobs` | `app.jobs = 4`, or `RPGAPI_start(app : 8080 : 4)` | 1 |
| `log_level` | [RPGAPI_setLogLevel](#rpgapi_setloglevel) | off |
| `max_request_size` | [RPGAPI_setMaxRequestSize](#rpgapi_setmaxrequestsize) | 1MB |
| `max_upload_size` | [RPGAPI_setMaxUploadSize](#rpgapi_setmaxuploadsize) | 0, off |
| `read_timeout`, `write_timeout` | [RPGAPI_setTimeouts](#rpgapi_settimeouts) | 30, 30 seconds |
| `tls_application_id`, `tls_keystore`, `tls_password`, `tls_label` | [RPGAPI_setTlsApplication](#rpgapi_settlsapplication), [RPGAPI_setTlsKeystore](#rpgapi_settlskeystore) | plain HTTP |
| `cors_origins`, `cors_credentials`, `cors_max_age`, `cors_allow_headers`, `cors_expose_headers` | [RPGAPI_setCors](#rpgapi_setcors) and the fields | no CORS |
| `keepalive_timeout`, `keepalive_requests` | [RPGAPI_setKeepAlive](#rpgapi_setkeepalive) | 5 seconds, 100 requests |
| `not_found_handler`, `error_handler` | [RPGAPI_setNotFound](#rpgapi_setnotfound), [RPGAPI_setErrorHandler](#rpgapi_seterrorhandler) | plain 404 and 500 |
| `trusted_proxies` | [RPGAPI_setTrustedProxies](#rpgapi_settrustedproxies) | none |
| `route_prefix` | [RPGAPI_setPrefix](#rpgapi_setprefix) | none |
| `statics` | [RPGAPI_serveStatic](#rpgapi_servestatic) (up to 20) | none |
| `security_headers`, `content_security_policy` | [RPGAPI_setSecurityHeaders](#rpgapi_setsecurityheaders) | off |
| `compression`, `compression_threshold` | [RPGAPI_setCompression](#rpgapi_setcompression) | off; 1024 bytes |
| `views_directory`, `views_library` | [RPGAPI_setViews](#rpgapi_setviews) | the job's current directory; the app's library |
| `views_layout` | [RPGAPI_setLayout](#rpgapi_setlayout) | none |
| `routes`, `middlewares` | the route procedures and [RPGAPI_setMiddleware](#rpgapi_setmiddleware) | up to 250 routes, 100 middleware |
| `socket_descriptor`, `return_socket_descriptor` | RPGAPI | |

A setter given a value it does not accept ends your program with escape
message `CPF9898` saying why. Every job serving the app (see
[several jobs](#several-jobs)) runs your program, and so gets the same
settings.

<details><summary>The declaration</summary>

```rpgle
dcl-ds RPGAPI_App qualified template;
   port int(10:0);
   socket_descriptor int(10:0);
   return_socket_descriptor int(10:0);
   routes likeds(RPGAPI_route_ds) dim(250);
   middlewares likeds(RPGAPI_route_ds) dim(100);
   jobs int(10:0);
   log_level int(10:0);
   max_request_size int(10:0);
   max_upload_size int(10:0);
   read_timeout int(10:0);
   write_timeout int(10:0);
   tls_application_id varchar(100);
   tls_keystore varchar(1024);
   tls_password varchar(128);
   tls_label varchar(128);
   cors_origins varchar(2000);
   cors_credentials ind;
   cors_max_age int(10:0);
   cors_allow_headers varchar(1000);
   cors_expose_headers varchar(1000);
   keepalive_timeout int(10:0);
   keepalive_requests int(10:0);
   not_found_handler pointer(*proc);
   error_handler pointer(*proc);
   trusted_proxies varchar(1000);
   route_prefix varchar(1000);
   statics likeds(RPGAPI_static_ds) dim(20);
   security_headers ind;
   content_security_policy varchar(2000);
   compression ind;
   compression_threshold int(10:0);
   views_directory varchar(1024);
   views_library char(10);
   views_layout varchar(1024);
end-ds;
```
</details>

### RPGAPI_start
```rpgle
RPGAPI_start(app : port? : jobs?)
```
Opens the port and serves requests until the job ends or
[RPGAPI_shutdown](#rpgapi_shutdown) is called.

| Parameter | Type | |
| --- | --- | --- |
| `app` | `RPGAPI_App` | the app |
| `port` | `int(10:0)` | the port; `app.port`, or 3000, when left out |
| `jobs` | `int(10:0)` | how many jobs serve the port; `app.jobs`, or 1. See [several jobs](#several-jobs) |

```rpgle
RPGAPI_start(app);                 // app.port, or 3000
RPGAPI_start(app : 8080);
RPGAPI_start(app : 8080 : 4);      // 4 jobs
```

When the server cannot listen on the port, such as when another job is
already using it, `RPGAPI_start` ends with escape message `CPF9898` naming the
failed call and the reason, for example
`bind() failed for port 3000: Address already in use. (errno 3420).` Monitor
for it if your program should handle this itself. With HTTPS, it also ends
with an escape message when TLS cannot be set up. When the server stops,
`RPGAPI_start` returns and your program goes on after it.

### RPGAPI_shutdown
```rpgle
RPGAPI_shutdown()
```
Stops the server from the app itself, such as from an admin route or at a
cutoff time. Call it in a route or middleware. It works as a controlled
`ENDJOB` does, in every job serving the app, whichever took the request: each
finishes the request it is on and takes no more. The request that called it
is answered first, with `Connection: close`. Then `RPGAPI_start` returns, in
the job you started once all of its jobs have ended.

```rpgle
dcl-proc stopServer;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;

   RPGAPI_shutdown();
   return RPGAPI_setResponse(request : HTTP_ACCEPTED);
end-proc;
```

Guard such a route, for example with middleware that checks credentials:
anyone who can call it can stop the server. See also
[stopping the server](#stopping-the-server).

### RPGAPI_get, RPGAPI_post, RPGAPI_put, RPGAPI_patch, RPGAPI_delete
```rpgle
RPGAPI_get(app : url : %paddr(procedure))
RPGAPI_post(app : url : %paddr(procedure))
RPGAPI_put(app : url : %paddr(procedure))
RPGAPI_patch(app : url : %paddr(procedure))
RPGAPI_delete(app : url : %paddr(procedure))
```
Adds a route for that method: requests for the path are handed to the
[route procedure](#a-route-procedure).

| Parameter | Type | |
| --- | --- | --- |
| `app` | `RPGAPI_App` | the app |
| `url` | `varchar(32000)` | the path, with `{name}` segments for params and `*` for any segment |
| `procedure` | `pointer(*proc)` | the route procedure |

```rpgle
RPGAPI_get(app : '/api/v1/memberships/{id}' : %paddr(MBR_show));
RPGAPI_post(app : '/api/v1/memberships' : %paddr(MBR_create));
```
A `{name}` segment is read with [RPGAPI_getParam](#rpgapi_getparam). A `GET`
route also answers `HEAD`. How paths match, and in which order routes are
tried: [routing rules](#routing-rules).

### RPGAPI_setRoute
```rpgle
RPGAPI_setRoute(app : method : url : %paddr(procedure))
```
Adds a route for any method, such as one the procedures above do not cover.
`method` (`char(10)`) is compared as it is sent, so give it in upper case; see
[methods](#methods) for the constants.

```rpgle
RPGAPI_setRoute(app : HTTP_PUT : '/api/users/{id}' : %paddr(USR_update));
RPGAPI_setRoute(app : HTTP_OPTIONS : '/api/users' : %paddr(USR_options));
```

### RPGAPI_setPrefix
```rpgle
RPGAPI_setPrefix(app : prefix)
```
Puts `prefix` (`varchar(1000)`) in front of the path of every route and
middleware added after it, until the next `RPGAPI_setPrefix`: a group of
routes, such as an API version. `''` ends the group.

```rpgle
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
kept in `app.route_prefix`, and [RPGAPI_serveStatic](#rpgapi_servestatic)
follows it too.

### RPGAPI_setMiddleware
```rpgle
RPGAPI_setMiddleware(app : url : %paddr(procedure))
```
Adds [middleware](#a-middleware-procedure) for a path and every path below it,
or for all requests with `'*'` (`RPGAPI_GLOBAL_MIDDLEWARE`).

```rpgle
RPGAPI_setMiddleware(app : '*' : %paddr(logRequest));                 // every request
RPGAPI_setMiddleware(app : '/api/v1/memberships' : %paddr(checkAuth));
```
The second runs for `/api/v1/memberships` and `/api/v1/memberships/5`, but not
for `/api/v1/membershipsX` or `/x/api/v1/memberships`. `{name}` and `*`
segments work as in routes.

Every middleware that matches runs once per request, in the order it was
added, before the route, and also when no route matches. One that returns
`*off` ends the request with the response it set. An app can have up to 100.

### RPGAPI_serveStatic
```rpgle
RPGAPI_serveStatic(app : url : directory)
```
Serves the files of an IFS directory (`varchar(1024)`) below a path
(`varchar(1000)`), such as a web page with its styles, scripts and images, the
way `express.static` does.

```rpgle
RPGAPI_serveStatic(app : '/web' : '/www/myapp');
```
`GET /web/css/app.css` then sends `/www/myapp/css/app.css`, and `/web/` sends
`/www/myapp/index.html`. The directory has to exist: `RPGAPI_serveStatic` ends
your program with `CPF9898` when it does not. An app can serve up to 20
directories. What is served and how:
[files and directories](#files-and-directories).

### RPGAPI_setNotFound
```rpgle
RPGAPI_setNotFound(app : %paddr(procedure))
```
Answers requests no route matches with a [route procedure](#a-route-procedure)
of yours, such as a JSON error, instead of a plain `404`. A status left at 0 is
sent as 404. See [not found and errors](#not-found-and-errors).

### RPGAPI_setErrorHandler
```rpgle
RPGAPI_setErrorHandler(app : %paddr(procedure))
```
Answers requests that fail, or that RPGAPI refused, with a procedure of yours
instead of a plain `500` (or 400, 408, 413, 431, 501). The procedure gets the
request and an [RPGAPI_Error](#rpgapi_error), and returns the response:

```rpgle
dcl-proc failed;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
      error likeds(RPGAPI_Error) const;
   end-pi;
   dcl-ds response likeds(RPGAPI_Response) inz;

   response.status = error.status;
   RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
   response.body = '{"error":"' + %char(error.status) + '"}';
   return response;
end-proc;
```
When it is called: [not found and errors](#not-found-and-errors).

### RPGAPI_setLogLevel
```rpgle
RPGAPI_setLogLevel(app : level)
```
How much RPGAPI logs to the job log: one of the [log levels](#log-levels)
(`int(10:0)`). Off by default. See [logging](#logging).

```rpgle
RPGAPI_setLogLevel(app : RPGAPI_LOG_INFO);   // a line per request
```

### RPGAPI_setMaxRequestSize
```rpgle
RPGAPI_setMaxRequestSize(app : bytes)
```
The largest request body read into memory before your procedure is called:
1MB by default, up to 16,000,000 bytes. A larger body is refused with 413,
unless [RPGAPI_setMaxUploadSize](#rpgapi_setmaxuploadsize) allows it.

```rpgle
RPGAPI_setMaxRequestSize(app : 5000000);
```

### RPGAPI_setMaxUploadSize
```rpgle
RPGAPI_setMaxUploadSize(app : bytes)
```
Allows bodies over the request size limit, up to this larger one (at most
2GB); 0, the default, is off. Such a body is not read into memory: your
procedure reads it from the connection, or saves it with
[RPGAPI_saveBody](#rpgapi_savebody). See
[request bodies and uploads](#request-bodies-and-uploads).

```rpgle
RPGAPI_setMaxUploadSize(app : 500000000);   // 500MB
```

### RPGAPI_setTimeouts
```rpgle
RPGAPI_setTimeouts(app : readSeconds : writeSeconds)
```
How long a client has to send its whole request (the read timeout), and how
long it may take none of a response (the write timeout). Both are 30 seconds
by default, and have to be at least 1. See
[keep-alive and timeouts](#keep-alive-and-timeouts).

```rpgle
RPGAPI_setTimeouts(app : 20 : 60);
```

### RPGAPI_setKeepAlive
```rpgle
RPGAPI_setKeepAlive(app : seconds : maxRequests?)
```
How long a connection stays open after a response for the client's next
request (5 seconds by default), and how many requests one connection may send
(100). `0` seconds turns keep-alive off.

```rpgle
RPGAPI_setKeepAlive(app : 15 : 1000);
RPGAPI_setKeepAlive(app : 0);          // close after each response
```
See [keep-alive and timeouts](#keep-alive-and-timeouts).

### RPGAPI_setCors
```rpgle
RPGAPI_setCors(app : origins)
```
Allows pages on other origins to call the app: origins (`varchar(2000)`)
separated by spaces or commas, or `'*'` for any. The other `cors_` fields of
[RPGAPI_App](#rpgapi_app) fine-tune it.

```rpgle
RPGAPI_setCors(app : 'https://app.example.com https://admin.example.com');
app.cors_credentials = *on;          // let the browser send cookies along
app.cors_max_age = 600;              // cache preflight answers 10 minutes
app.cors_expose_headers = 'X-Total'; // headers scripts may read
```
See [CORS](#cors).

### RPGAPI_setSecurityHeaders
```rpgle
RPGAPI_setSecurityHeaders(app : policy?)
```
Adds the browser protection headers Express apps get from `helmet` to every
response. `policy` (`varchar(2000)`) is the `Content-Security-Policy`:
`RPGAPI_DEFAULT_CSP` when left out, `''` for none.

```rpgle
RPGAPI_setSecurityHeaders(app);
RPGAPI_setSecurityHeaders(app : 'default-src ''self''; script-src ''self'' https://cdn.example.com');
```
The headers, and how a route overrides them:
[security headers](#security-headers).

### RPGAPI_setCompression
```rpgle
RPGAPI_setCompression(app : minBytes?)
```
Gzips text and JSON responses for clients that accept it, as Express's
`compression` middleware does: bodies of `minBytes` (1024 when left out) and
more, and every streamed response of unknown length.

```rpgle
RPGAPI_setCompression(app);
RPGAPI_setCompression(app : 10000);
```
Which responses are gzipped, and how: [compression](#compression).

### RPGAPI_setTrustedProxies
```rpgle
RPGAPI_setTrustedProxies(app : addresses)
```
The proxies in front of the app (`varchar(1000)`, separated by spaces or
commas, or `'*'`), whose `X-Forwarded-For` header gives
`request.remote_ip` the client's address.

```rpgle
RPGAPI_setTrustedProxies(app : '10.0.0.5 10.0.0.6');
```
See [client address](#client-address).

### RPGAPI_setTlsApplication
```rpgle
RPGAPI_setTlsApplication(app : applicationId)
```
Serves HTTPS with the certificate assigned to a DCM application ID
(`varchar(100)`). See [HTTPS](#https).

```rpgle
RPGAPI_setTlsApplication(app : 'MYCO_RPGAPI_ORDERS');
RPGAPI_start(app : 8443);
```

### RPGAPI_setTlsKeystore
```rpgle
RPGAPI_setTlsKeystore(app : path : password : label?)
```
Serves HTTPS with a certificate from a certificate store file (`path`,
`varchar(1024)`), opened with `password` (`varchar(128)`); `label`
(`varchar(128)`) picks the certificate, the store's default when left out.
See [HTTPS](#https).

### RPGAPI_setViews
```rpgle
RPGAPI_setViews(app : directory : library?)
```
Where [views](#views) are: the directory (`varchar(1024)`) template paths and
copybooks are relative to (the job's current directory when not set), and
the library (`char(10)`) their compiled programs go into (the library of the
app's program when left out).

```rpgle
RPGAPI_setViews(app : '/home/me/myapp/views');
RPGAPI_setViews(app : '/home/me/myapp/views' : 'MYVIEWS');
```

### RPGAPI_setLayout
```rpgle
RPGAPI_setLayout(app : template)
```
The [layout](#layouts) every view rendered with
[RPGAPI_render](#rpgapi_render) is written into: a template (`varchar(1024)`)
that writes the page around the view, such as its head, navigation and
footer. `''` for none, the default. A view picks another, or none, with
`<%@ layout('...') %>`.

```rpgle
RPGAPI_setLayout(app : 'layout.erpg');
```

---

## Request

### RPGAPI_Request
What the client sent, handed to every route and middleware.

| Field | |
| --- | --- |
| `method` | `GET`, `POST`, ... (`HEAD` for a HEAD request answered by a GET route) |
| `route` | the path, as it was sent (still URL-encoded) |
| `query_string` | the query string, as it was sent; read values with [RPGAPI_getQueryParam](#rpgapi_getqueryparam) |
| `query_params` | the query values, decoded |
| `params` | the route's `{name}` params, decoded; read them with [RPGAPI_getParam](#rpgapi_getparam) |
| `protocol` | `HTTP/1.1` or `HTTP/1.0` |
| `hostname` | the host the client asked for: the `Host` header without its port, as Express's `req.hostname` (`api.example.com` for `Host: api.example.com:8080`, `[::1]` for `Host: [::1]:3000`, blank without a `Host` header) |
| `headers` | the first 50 headers, with values cut at 1,024 characters: read values with [RPGAPI_getHeader](#rpgapi_getheader) |
| `header_text` | the headers as sent, for `RPGAPI_getHeader` |
| `body` | the body, up to 32,000 characters, converted to the job's CCSID; larger bodies are read with [RPGAPI_readBody](#rpgapi_readbody) |
| `remote_ip` | the client's IP address, as Express's `req.ip`; see [client address](#client-address) |
| `connection_ip` | the address the connection came from (a proxy's, behind one) |

<details><summary>The declaration</summary>

```rpgle
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
   header_text varchar(32000);
   remote_ip varchar(45);
   connection_ip varchar(45);
end-ds;
```
</details>

### RPGAPI_getParam
```rpgle
value = RPGAPI_getParam(request : name)       // varchar(1024)
```
A route param, from a `{name}` segment of the route's path, as text: convert
it as needed.

```rpgle
RPGAPI_get(app : '/v1/things/{id}' : %paddr(showThing));
...
id = %int(RPGAPI_getParam(request : 'id'));
```
Params are URL-decoded, as Express does: `%20` becomes a space and `%C3%BC` a
`ü` (escapes are read as UTF-8, then converted to the job's CCSID). A `+`
stays a `+`. An escape that is not two hex digits, or bytes that are not
UTF-8, are left as they were sent. Routes are matched on the path as it was
sent, so an encoded `/` (`%2F`) stays inside its segment and arrives in the
param.

### RPGAPI_getQueryParam
```rpgle
value = RPGAPI_getQueryParam(request : name)  // varchar(1024)
```
A value from the query string, such as `q` in `?q=fish`, decoded as params
are, with `+` as a space too. The name is matched in any case. The whole
query string, as sent, is `request.query_string`.

```rpgle
search = RPGAPI_getQueryParam(request : 'q');
```

### RPGAPI_getHeader
```rpgle
value = RPGAPI_getHeader(request : name)      // varchar(32000)
```
A request header. The name is matched in any case, `''` is returned for a
header that was not sent, and the whole value is returned however long it
is, such as a long bearer token or a large `Cookie` header.

```rpgle
type = RPGAPI_getHeader(request : 'Content-Type');
```

### RPGAPI_getCookie
```rpgle
value = RPGAPI_getCookie(request : name)      // varchar(4096)
```
A cookie the browser sent, from the `Cookie` header. The name is matched
exactly (cookie names are case-sensitive), a value in quotes comes back
without them, and `%XX` escapes are decoded, as Express's `req.cookies` does,
so a value set with [RPGAPI_setCookie](#rpgapi_setcookie) comes back as it
was set. A cookie that was not sent gives `''`.

```rpgle
session_id = RPGAPI_getCookie(request : 'session');
```

### RPGAPI_getFormParam
```rpgle
value = RPGAPI_getFormParam(request : name : occurrence?)   // varchar(32000)
```
A field of an HTML form body: a form sent with `method="post"` (and no
`enctype`) arrives as `application/x-www-form-urlencoded`, such as
`name=J%C3%BCrgen+Long&tag=a&tag=b`. Fields are decoded as query values are.

```rpgle
name = RPGAPI_getFormParam(request : 'name');          // Jürgen Long
second_tag = RPGAPI_getFormParam(request : 'tag' : 2); // b
```
- The name is matched in any case. `occurrence` picks the nth field of that
  name, for checkboxes and multiple selects; past the last one it is `''`.
- A field that was not sent, or was sent empty, gives `''`, and so does any
  body with another `Content-Type`.
- Values can be up to 32,000 characters, such as a long `<textarea>`, and the
  whole body is searched, also past what `request.body` holds; a body larger
  than the request size limit, which is streamed from the connection, is not.
- Forms with files (`enctype="multipart/form-data"`) are read with
  [RPGAPI_nextPart](#rpgapi_nextpart).

### RPGAPI_getBearerToken
```rpgle
token = RPGAPI_getBearerToken(request)        // varchar(16000)
```
The token of an `Authorization: Bearer <token>` header (API keys, JWTs, OAuth
access tokens), or `''` when the request has none. The scheme is matched in
any case. Checking it is up to your app; see
[authentication](#authentication).

### RPGAPI_getBasicAuth
```rpgle
found = RPGAPI_getBasicAuth(request : user : password)   // ind
```
Decodes the user and password of an `Authorization: Basic ...` header (curl
`-u`, a browser's login prompt) into `user` and `password` (`varchar(256)`
each), and returns `*on`; `*off` when there are none (no header, another
scheme, or a value that is not base64 or has no `:`). The password may contain
colons; both are read as UTF-8. See [authentication](#authentication).

```rpgle
if RPGAPI_getBasicAuth(request : user : password);
   ...
endif;
```

### RPGAPI_checkUserProfile
```rpgle
valid = RPGAPI_checkUserProfile(user : password : messageId?)   // ind
```
Whether the password is right for an IBM i user profile, with the system's
`QSYGETPH` API, so an API can use the sign-on its users already have. The
handle it gets is released at once, so your job keeps running as its own
user.

```rpgle
if RPGAPI_getBasicAuth(request : user : password) and
   RPGAPI_checkUserProfile(user : password : message_id);
   ...                                        // signed on as user
endif;
```
`messageId` (`char(7)`) tells you why not, for your log (not for the client):
`CPF22E2` for a wrong password, which the system also answers for a user that
does not exist, `CPF22E3` for a disabled profile, `CPF22E4` for an expired
password. Before asking the system, it refuses a user name starting with `*`
(such as `*CURRENT`) or longer than 10 characters, an empty password, and
`*NOPWD`, `*NOPWDCHK` and `*NOPWDSTS`, which would otherwise get a handle
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

### RPGAPI_bodyLength
```rpgle
size = RPGAPI_bodyLength(request)             // int(10:0)
```
The body's size in bytes, as sent; -1 while the size of a chunked body being
streamed is not known yet.

### RPGAPI_readBody
```rpgle
piece = RPGAPI_readBody(request)              // varchar(32000)
```
The next piece of the body as text in the job's CCSID, `''` at its end. Any
body, whatever its size, can be read this way; `request.body` only holds the
first 32,000 characters.

```rpgle
piece = RPGAPI_readBody(request);
dow piece <> '';
   ...
   piece = RPGAPI_readBody(request);
enddo;
```
It reads from the same position as [RPGAPI_readBodyBytes](#rpgapi_readbodybytes),
so use one or the other for a request. See
[request bodies and uploads](#request-bodies-and-uploads) for bodies that are
streamed from the connection.

### RPGAPI_readBodyBytes
```rpgle
count = RPGAPI_readBodyBytes(request : %addr(buffer) : %size(buffer))   // int(10:0)
```
Copies up to `size` bytes of the body, as they were sent, without conversion,
into `buffer`, for binary content such as images and PDFs. Returns how many,
0 at the end.

```rpgle
count = RPGAPI_readBodyBytes(request : %addr(buffer) : %size(buffer));
dow count > 0;
   ...
   count = RPGAPI_readBodyBytes(request : %addr(buffer) : %size(buffer));
enddo;
```

### RPGAPI_saveBody
```rpgle
saved = RPGAPI_saveBody(request : path)       // ind
```
Writes the body, unconverted, to an IFS file (`varchar(1024)`), replacing it.
`*off` when the file cannot be created. With
[RPGAPI_setMaxUploadSize](#rpgapi_setmaxuploadsize), the body goes from the
connection to the file without being held in memory.

```rpgle
if RPGAPI_saveBody(request : '/uploads/' + name);
   response.status = HTTP_CREATED;
endif;
```

### RPGAPI_Part
A part of a `multipart/form-data` body, filled in by
[RPGAPI_nextPart](#rpgapi_nextpart).

| Field | |
| --- | --- |
| `name` (`varchar(256)`) | the form field's name |
| `filename` (`varchar(1024)`) | the file's name as the client sent it, `''` for a field that is not a file. Never use it as a path |
| `content_type` (`varchar(256)`) | the part's `Content-Type`, such as `image/png` |

### RPGAPI_nextPart
```rpgle
more = RPGAPI_nextPart(request : part)        // ind
```
Moves to the next part of a `multipart/form-data` body (a form with a file
input, `curl -F`) and describes it in `part`, an
[RPGAPI_Part](#rpgapi_part). Returns `*off` at the end, and for a body that is
not `multipart/form-data`.

```rpgle
dcl-ds part likeds(RPGAPI_Part);

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
  the files is only bounded by the request and upload limits. Allow larger
  uploads with [RPGAPI_setMaxUploadSize](#rpgapi_setmaxuploadsize).
- Whatever you do not read of a part is skipped when you move to the next.
- A body that is not valid multipart ends your procedure with an escape
  message and a 400, like the other body errors.
- Use either the parts or `RPGAPI_readBody` / `RPGAPI_readBodyBytes` for a
  request, not both.

### RPGAPI_readPart
```rpgle
piece = RPGAPI_readPart(request)              // varchar(32000)
```
The next piece of the current part as text in the job's CCSID, `''` at its
end.

### RPGAPI_readPartBytes
```rpgle
count = RPGAPI_readPartBytes(request : %addr(buffer) : %size(buffer))   // int(10:0)
```
Copies up to `size` bytes of the current part, unconverted, to `buffer`.
Returns how many, 0 at its end.

### RPGAPI_savePart
```rpgle
size = RPGAPI_savePart(request : path)        // int(10:0)
```
Writes the rest of the current part, unconverted, to an IFS file, replacing
it. Returns the bytes written, -1 when the file cannot be created. Build the
path yourself: never from `part.filename`.

---

## Response

### RPGAPI_Response
What a route returns: the status, the headers and the body. Declare it with
`inz` in the procedure (see [a route procedure](#a-route-procedure)). After
the response, the connection is kept open for the client's next request (see
[keep-alive and timeouts](#keep-alive-and-timeouts)).

| Field | |
| --- | --- |
| `status` | the status code, such as `HTTP_OK` (see [status codes](#status-codes)) |
| `headers` | up to 100 headers; set them with [RPGAPI_setHeader](#rpgapi_setheader) |
| `body` | the body, up to 32,000 characters, sent as UTF-8. For more, stream the response (see [RPGAPI_beginResponse](#rpgapi_beginresponse)) |

```rpgle
response.status = HTTP_CREATED;
response.body = '{"id":5}';
RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
return response;
```
The body is sent exactly as it is set, blanks included. When you set it from
a fixed-length (`char`) field, trim it, or its trailing blanks go out too:
`response.body = %trim(row.name);`.

<details><summary>The declaration</summary>

```rpgle
dcl-ds RPGAPI_Response qualified template;
   body varchar(32000);
   headers likeds(RPGAPI_header_ds) dim(100);
   status int(10:0);
end-ds;
```
</details>

### RPGAPI_setHeader
```rpgle
RPGAPI_setHeader(response : name : value)
```
Adds a response header: `name` (`char(50)`), `value` (`varchar(1024)`).

```rpgle
RPGAPI_setHeader(response : 'Content-Type' : 'application/json');

response.status = HTTP_FOUND;                          // a redirect
RPGAPI_setHeader(response : 'Location' : '/api/v1/memberships/5');
```
Up to 100 headers can be set. `Connection`, `Content-Length` and
`Transfer-Encoding` are set by RPGAPI from how the body is sent; values you
set for them are left out. A line break in a header name or value becomes a
blank, so request data you put in a header (a file name, a redirect) cannot
add headers of its own.

### RPGAPI_setResponse
```rpgle
return RPGAPI_setResponse(request : status)   // RPGAPI_Response
```
A response that is just a status, with no body or headers, as Express's
`res.sendStatus`.

```rpgle
return RPGAPI_setResponse(request : HTTP_NO_CONTENT);
```

### RPGAPI_setCookie
```rpgle
RPGAPI_setCookie(response : name : value : options?)
```
Adds a `Set-Cookie` header; call it once per cookie. Without
[options](#rpgapi_cookieoptions) the cookie is for the whole site (`Path=/`)
and lasts until the browser closes.

```rpgle
RPGAPI_setCookie(response : 'theme' : 'dark');

dcl-ds options likeds(RPGAPI_CookieOptions) inz(*likeds);
options.max_age = 3600;          // seconds; Expires is sent too
options.http_only = *on;         // not readable from JavaScript
options.secure = *on;            // HTTPS only
options.same_site = 'Lax';       // Strict, Lax or None
RPGAPI_setCookie(response : 'session' : session_id : options);
```
This sends `Set-Cookie: session=...; Max-Age=3600; Path=/; Expires=...;
HttpOnly; Secure; SameSite=Lax`. The value is sent `%XX` encoded as UTF-8, as
Express does, so it can hold spaces, `;` and characters outside ASCII;
[RPGAPI_getCookie](#rpgapi_getcookie) decodes it. Browsers need `secure` for
`SameSite=None`.

A name that is not one a cookie can have (it has to be letters, digits or
``!#$%&'*+-.^_`|~``), a `path` or `domain` with a `;`, an unknown
`same_site`, or a cookie longer than the 1,024 characters a response header
holds ends your procedure with an escape message (`CPF9898`) that says which;
the request is answered with a 500, and the message is logged at
`RPGAPI_LOG_ERROR`.

### RPGAPI_CookieOptions
The attributes of a cookie, for [RPGAPI_setCookie](#rpgapi_setcookie) and
[RPGAPI_clearCookie](#rpgapi_clearcookie). Declare it with `inz(*likeds)` and
set what you need.

| Field | Attribute | Default |
| --- | --- | --- |
| `path` (`varchar(256)`) | `Path` | `/` |
| `domain` (`varchar(256)`) | `Domain` | none: only the host that set it |
| `max_age` (`int(10:0)`) | `Max-Age` and `Expires` | 0: until the browser closes |
| `http_only` (`ind`) | `HttpOnly` | off |
| `secure` (`ind`) | `Secure` | off |
| `same_site` (`varchar(6)`) | `SameSite` (`Strict`, `Lax` or `None`) | none: the browser decides |

### RPGAPI_clearCookie
```rpgle
RPGAPI_clearCookie(response : name : options?)
```
Tells the browser to delete a cookie (`Max-Age=0` and an `Expires` in 1970).
Pass the same `path` and `domain` it was set with.

```rpgle
RPGAPI_clearCookie(response : 'session');
```

### RPGAPI_beginResponse
```rpgle
RPGAPI_beginResponse(response : length?)
```
Starts a streamed response: sends the status and headers of `response` (a
status of 0 is 200). Write the body with [RPGAPI_write](#rpgapi_write) and
[RPGAPI_writeBytes](#rpgapi_writebytes) in as many pieces as you like, then
[RPGAPI_endResponse](#rpgapi_endresponse). For bodies over 32,000 characters,
or rows sent as they are read.

```rpgle
RPGAPI_setHeader(response : 'Content-Type' : 'application/json');
RPGAPI_beginResponse(response);
RPGAPI_write('[');
// ... RPGAPI_write(...) for each row ...
RPGAPI_write(']');
RPGAPI_endResponse();
return response;            // not sent again: the response has gone out
```
The body is sent with `Transfer-Encoding: chunked`, or up to the connection's
close for an HTTP/1.0 client. When you know its size in bytes up front, pass
`length` and it is sent with a `Content-Length` instead. See
[streaming responses](#streaming-responses).

### RPGAPI_write
```rpgle
RPGAPI_write(text)
```
Adds text (`varchar(32000)`) to a streamed response, converted from the job's
CCSID to UTF-8. Writes are collected and sent in pieces of 32KB, so writing a
row at a time is fine. After the client has stopped taking the response (the
write timeout), it does nothing, so a procedure writing rows still runs to
its end.

### RPGAPI_writeBytes
```rpgle
RPGAPI_writeBytes(%addr(buffer) : length)
```
Adds `length` bytes at `buffer` to a streamed response, as they are, for
binary content.

### RPGAPI_writeHtml
```rpgle
RPGAPI_writeHtml(text)
```
Adds text to a streamed response as HTML shows it: `&`, `<`, `>`, `"` and `'`
become entities, so a value from a user or a table cannot add tags or scripts
to a page. It is what `<%= %>` does in a [view](#views).

### RPGAPI_escapeHtml
```rpgle
html = RPGAPI_escapeHtml(text)                // varchar(192000)
```
Text with `&`, `<`, `>`, `"` and `'` as HTML entities (`&amp;` `&lt;` `&gt;`
`&quot;` `&#39;`), for building HTML yourself.

### RPGAPI_endResponse
```rpgle
RPGAPI_endResponse()
```
Finishes a streamed response. A response you do not end is ended when your
procedure returns.

### RPGAPI_sendFile
```rpgle
sent = RPGAPI_sendFile(response : path)       // ind
```
Sends an IFS file of any size as it is stored, with the status and headers of
`response`, a `Content-Length`, and a `Content-Type` from its extension unless
`response` has one. Returns `*off`, having sent nothing, when the file cannot
be opened or the path contains a `..` segment, so your procedure can answer
instead.

```rpgle
if not RPGAPI_sendFile(response : '/www/files/' + RPGAPI_getParam(request : 'name'));
   response.status = HTTP_NOT_FOUND;
endif;
return response;
```
It answers conditional and range requests as Express does; see
[files and directories](#files-and-directories).

### RPGAPI_render
```rpgle
return RPGAPI_render(template : %addr(data)? : response?)   // RPGAPI_Response
```
Sends a [view](#views): a template of HTML with RPG in it (`varchar(1024)`),
given the route's data structure by its address. The page streams as
`text/html; charset=utf-8`, or with the status and headers of `response`,
such as a 400 or a cookie. A template that cannot be compiled is answered
with a 500 naming why.

```rpgle
dcl-ds model likeds(customers_t) inz;
// ...fill model...
return RPGAPI_render('customers.erpg' : %addr(model));

return RPGAPI_render('about.erpg');                        // no data
return RPGAPI_render('form.erpg' : %addr(model) : response); // response.status = 400
```

---

## Views

### How views work
A view is a page written as HTML with RPG inside tags, the way Express apps
use EJS templates. The route fills a data structure the usual way (a fetch, a
`CHAIN`, a loop) and passes its address to [RPGAPI_render](#rpgapi_render);
the view bases the same data structure on that address and writes the page,
which is streamed to the browser. It is like calling a program with a
parameter.

Put the data structure in a copybook next to the views, so the route and the
view are sure to agree on it (`views/customers_t.rpgleinc`):
```rpgle
**free
dcl-ds customer_t qualified template;
   name varchar(50);
   city varchar(50);
   balance packed(11:2);
end-ds;
dcl-ds customers_t qualified template;
   title varchar(100);
   count int(10:0);
   customers likeds(customer_t) dim(500);
end-ds;
```
The route:
```rpgle
/include 'customers_t.rpgleinc'

dcl-proc listCustomers;
   dcl-pi *n likeds(RPGAPI_Response);
      request likeds(RPGAPI_Request) const;
   end-pi;
   dcl-ds model likeds(customers_t) inz;

   model.title = 'Customers';
   // ...fill model.customers and model.count...
   return RPGAPI_render('customers.erpg' : %addr(model));
end-proc;
```
The view, `views/customers.erpg`:
```
<%! /include 'customers_t.rpgleinc'
     dcl-ds model likeds(customers_t) based(RPGAPI_data);
     dcl-s i int(10:0); -%>
<h1><%= model.title %></h1>
<ul>
<% for i = 1 to model.count; -%>
  <li><%= model.customers(i).name %>, <%= model.customers(i).city %>: <%= model.customers(i).balance %></li>
<% endfor; -%>
</ul>
```
Call the data structure `model`, or anything but `page`, which is a reserved
word in RPG.

RPG cannot run code it reads while it runs, so RPGAPI compiles each view into
a program the first time it is asked for, and again whenever the template or
a copybook it includes changes: edit a view and refresh the page. That first
request takes a few seconds; the rest just call the program. With
[compression](#compression) on, views are gzipped like any text.

Two complete apps show views at work:
- [examples/html-page.sqlrpgle](examples/html-page.sqlrpgle): a library's
  tables, fetched from the SQL catalog into the route's data structure, in
  the app's layout.
- [examples/guestbook.rpgle](examples/guestbook.rpgle): no SQL. The notes are
  an RPG array; the view has `if`/`else`, a form it posts back to, what
  visitors typed escaped, and a 400 with the page when a field is missing
  (`RPGAPI_render`'s `response`).

### Tags
| Tag | |
| --- | --- |
| `<% code %>` | RPG statements: `for`, `if`, `dow`, `exec sql`, calls. Each ends with `;` as usual |
| `<%= expr %>` | A value, HTML-escaped: `&`, `<`, `>`, `"` and `'` become entities, so a value from a user or a table cannot add tags or scripts to the page. Numbers and dates are formatted with `%char` |
| `<%- expr %>` | A value as it is, for HTML you built and trust |
| `<%# text %>` | A comment, left out of the page |
| `<%! decls %>` | Declarations: `/include` of a copybook, `dcl-ds ... based(RPGAPI_data)`, `dcl-s`, `dcl-c`. They go first in the view's program wherever they are in the template |
| `<%@ layout('name') %>` | The [layout](#layouts) this view is written into, instead of the app's; `layout('')` for none |
| `<%%` | A literal `<%` |
| `-%>` | Ends any tag and leaves out the line break after it, so a line holding only a tag leaves no blank line in the page |

Everything else is text, written as it is. A view can run its own SQL too,
`exec sql` and all; it is then compiled with `CRTSQLRPGI`. Close the cursors
it opens.

### RPGAPI_data
In a view, the pointer the route passed to `RPGAPI_render` (or `*null`). Base
the view's data structure on it:
```rpgle
dcl-ds model likeds(customers_t) based(RPGAPI_data);
```
The view reads the route's data in place, with its own types: nothing is
copied or converted, and the data stays where it is while the page is
written, since the view runs inside the `RPGAPI_render` call.

A pointer carries no type: if the route and the view declared the data
differently, the view would read the wrong bytes, as with a program called
with the wrong parameters. The shared copybook is what prevents it, and a
view is compiled again when its copybook changes. Recompile the route's
program too when a copybook changes.

### RPGAPI_include
```rpgle
RPGAPI_include(template : %addr(data)?)
```
In a view, writes another view in place: with this view's data, or other data,
such as part of this view's (the title, one row). Shared headers and footers
are views of their own.

```
<% RPGAPI_include('nav.erpg' : %addr(model.head)); -%>
<% for i = 1 to model.count; -%>
<%    RPGAPI_include('row.erpg' : %addr(model.customers(i))); -%>
<% endfor; -%>
```

### Layouts
A layout is the page around your views: the head, navigation and footer
every page shares, written once. It is a template like any view, with
`<% RPGAPI_body(); %>` where the view goes, and
[RPGAPI_setLayout](#rpgapi_setlayout) makes it the app's:

```
<%! /include 'layout_t.rpgleinc'
     dcl-ds head likeds(layout_t) based(RPGAPI_data); -%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title><%= head.title %></title>
</head>
<body>
<h1><%= head.title %></h1>
<% RPGAPI_body(); -%>
</body>
</html>
```
- The layout gets the same data as the view, so it reads the start of the
  view's data structure. Put what it shows in a data structure of its own
  (`layout_t` above: the title) and start every page's data structure with
  it, `head likeds(layout_t)`; the route sets `model.head.title`.
- The layout's top is written, then the view, then the rest: the page still
  streams. A view that does not compile, or a layout that does not, gets the
  error page, before anything is sent.
- A view picks another layout, or none, with a tag in it, anywhere:
  `<%@ layout('admin.erpg') %>`, `<%@ layout('') %>`. It is read when the
  template is, since the layout runs first.
- Only views rendered with `RPGAPI_render` get a layout: views included with
  `RPGAPI_include` go into their page as they are, and a layout is not put in
  another layout.

Both examples use one: [views/layout.erpg](examples/views/layout.erpg).

### RPGAPI_body
```rpgle
RPGAPI_body()
```
In a [layout](#layouts), writes the view it is written around, once. In a
view that is not in a layout, it does nothing.

### Where views are compiled
[RPGAPI_setViews](#rpgapi_setviews) names the directory and the library. A
template path that does not start with `/` is relative to that directory (the
job's current directory without it), and so are the copybooks a view
includes. The programs go into the library named, or the library of the app's
program, and are named `RV` and 8 hex digits, after the template's file name
and content and its copybooks' content. The job needs the ILE RPG compiler
(5770WDS) and authority to create programs there. When a view is compiled
again, its older versions in the library are deleted (a program's text names
its template); one another job is running at that moment stays until the next
time. Any `RV...` program can be deleted: it is compiled again when it is
needed.

### ERPG
```
CALL PGM(MYLIB/ERPG) PARM('/home/me/myapp/views/customers.erpg' 'MYVIEWS')
```
`ERPG`, which `make all` builds, compiles one view into a library ahead of
time. For a server without the compiler, compile the views where there is
one, and bring the library along: a view is found by its name and content, so
the same template uses the same program. It is also a quick way to check a
template: one that does not compile ends `ERPG` with `CPF9898` and the errors.

### When a view is wrong
A view that does not compile, or a template with a tag that is never closed,
is answered with a 500 page listing the errors at their template lines, such
as `customers.erpg:7: RNF7030 The name or indicator NMAE is not defined.`,
and logged at ERROR. Every line of the generated program carries a comment
naming its template line (the source is in `/tmp/RPGAPI_RV....rpgle`). A
view that fails while it runs ends the page there, as a streamed response
does.

Good to know:
- Templates are UTF-8, with or without a byte order mark; Windows line breaks
  are fine. Their text goes through the job's CCSID, as everything written
  with [RPGAPI_write](#rpgapi_write) does.
- Not in this version: EJS's `<%_ _%>`, and passing a view the request
  itself (pass what it needs in the data).

---

## Constants and other data structures

### Status codes
These statuses have constants, and are sent with their reason phrase. Any
other status is sent with an empty one, which clients accept.

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

### Methods
`HTTP_GET`, `HTTP_POST`, `HTTP_PUT`, `HTTP_PATCH`, `HTTP_DELETE`,
`HTTP_HEAD` and `HTTP_OPTIONS`, for [RPGAPI_setRoute](#rpgapi_setroute) and
for comparing with `request.method`.

### Log levels
For [RPGAPI_setLogLevel](#rpgapi_setloglevel); each also logs the levels
above it. See [logging](#logging) for what each logs.

| Constant | |
| --- | --- |
| `RPGAPI_LOG_OFF` | nothing (the default) |
| `RPGAPI_LOG_ERROR` | failures |
| `RPGAPI_LOG_WARN` | and refused requests and clients that time out |
| `RPGAPI_LOG_INFO` | and a line per request |
| `RPGAPI_LOG_DEBUG` | and everything RPGAPI does |

### RPGAPI_Error
What went wrong, for an [error handler](#rpgapi_seterrorhandler).

| Field | |
| --- | --- |
| `status` (`int(10:0)`) | the status RPGAPI answers with unless the handler sets another: 500, or 400, 408, 413, 431 or 501 for a request or body that was refused |
| `message_id` (`char(7)`) | the escape message that ended the procedure, such as `MCH1211`; blank for a request refused before any procedure ran |
| `message_text` (`varchar(400)`) | its text; for a refused request, the status's reason phrase, such as `Content Too Large` |

### Other constants
| Constant | |
| --- | --- |
| `RPGAPI_GLOBAL_MIDDLEWARE` | `'*'`: middleware for every request |
| `RPGAPI_DEFAULT_CSP` | the Content-Security-Policy [RPGAPI_setSecurityHeaders](#rpgapi_setsecurityheaders) sends when it is given none: helmet's default, `default-src 'self'` and the rest |
| `RPGAPI_CR`, `RPGAPI_LF`, `RPGAPI_CRLF` | carriage return and line feed in EBCDIC |

### Internal data structures
Parts of the ones above, which apps do not usually need:

```rpgle
dcl-ds RPGAPI_header_ds qualified template;   // request.headers, response.headers
   name char(50);
   value varchar(1024);
end-ds;

dcl-ds RPGAPI_param_ds qualified template;    // request.params, request.query_params
   name char(50);
   value varchar(1024);
end-ds;

dcl-ds RPGAPI_route_ds qualified template;    // app.routes, app.middlewares
   method char(10);
   url varchar(32000);
   procedure pointer(*proc);
end-ds;

dcl-ds RPGAPI_static_ds qualified template;   // app.statics
   url varchar(1000);
   directory varchar(1024);
end-ds;
```

The procedures RPGAPI uses internally are declared in `rpgapi_int_h.rpgle`,
for RPGAPI itself and its unit tests; apps do not include it.

---

## Guides

### Routing rules
- A route has to match the whole path, one `/` segment at a time.
  `/api/users` matches `/api/users` and `/api/users/`, but not `/api/users/1`
  or `/x/api/users`. A `{name}` segment matches any one segment and captures
  it as a param, and `*` matches any one segment without capturing it.
- Routes are tried in the order they were added, and the first that matches
  handles the request. Since a route matches the whole path, order only
  matters when two routes match the same one, such as a fixed segment and a
  param in the same place: add the fixed one first.
  ```rpgle
  RPGAPI_get(app : '/api/v1/memberships/new' : %paddr(MBR_new));
  RPGAPI_get(app : '/api/v1/memberships/{id}' : %paddr(MBR_show));
  RPGAPI_get(app : '/api/v1/memberships' : %paddr(MBR_index));
  ```
- Middleware runs first, then [static files](#rpgapi_servestatic) for GET and
  HEAD, then the routes. A request that matches no route gets `404 Not Found`
  (see [not found and errors](#not-found-and-errors)).
- An app can have up to 250 routes and 100 middleware; adding one more ends
  your program with escape message `CPF9898` saying so, instead of the route
  never answering.
- A `HEAD` request is answered by the `GET` route for its path (unless you add
  a `HEAD` route), with the same status and headers, including the
  `Content-Length` the body would have, but without the body. Your procedure
  runs as for `GET`, and sees `request.method = 'HEAD'`. Streamed responses
  and `RPGAPI_sendFile` send only their headers too.
- An `OPTIONS` request for a path that has routes, but no `OPTIONS` route of
  its own, is answered with `204` and an `Allow` header listing their
  methods, such as `GET, HEAD, POST, OPTIONS`. It goes through middleware
  first.

### Several jobs
By default one job handles one request at a time. Pass the number of jobs to
serve with as a third parameter:
```rpgle
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
- to stop the server, end the job you started, or call
  [RPGAPI_shutdown](#rpgapi_shutdown). The others end with it, each once it
  has finished the request it is on, and the job you started waits for them
- a job that ends while the server runs (it failed, or someone ended it) is
  replaced by the job you started, once that job is between requests, and
  logged at WARN. At most 5 are replaced a minute, so a job that keeps failing
  does not keep the server busy starting it
- each job has its own memory: data a program keeps between requests, such
  as an array, is per job

### Stopping the server
`ENDJOB` ends a job controlled by default (`OPTION(*CNTRLD) DELAY(30)`), and
so does `ENDSBS *CNTRLD`. RPGAPI then takes no new requests and lets the ones
in progress finish before the job ends, within the delay. An idle kept-open
connection is closed. `ENDJOB OPTION(*IMMED)` stops at once, cutting off
requests in progress.

```
ENDJOB JOB(MYAPP)                        // finish the requests in progress
ENDJOB JOB(MYAPP) OPTION(*IMMED)         // stop now
```
From the app itself, call [RPGAPI_shutdown](#rpgapi_shutdown).

### HTTPS
Call one of these before `RPGAPI_start` to serve HTTPS instead of HTTP:
```rpgle
RPGAPI_setTlsApplication(app : 'MYCO_RPGAPI_ORDERS');   // DCM application ID
RPGAPI_setTlsKeystore(app : path : password : label);   // or a certificate store
RPGAPI_start(app : 8443);
```
Everything else works the same over HTTPS. The certificate has to be set up
in Digital Certificate Manager first; the README's HTTPS (TLS) section has
the steps and the error messages. Each job sets up TLS when it starts, and
`RPGAPI_start` ends with an escape message if it cannot. A client has 30
seconds to complete its TLS handshake; one that fails it is disconnected.

### Keep-alive and timeouts
A connection stays open after a response, so the client can send its next
request without connecting again, as browsers and HTTP client libraries do.
Responses say `Connection: keep-alive` and `Keep-Alive: timeout=5`.

- It is kept 5 seconds for the next request, for up to 100 requests;
  [RPGAPI_setKeepAlive](#rpgapi_setkeepalive) changes that, or turns it off.
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

A client has 30 seconds (the read timeout, see
[RPGAPI_setTimeouts](#rpgapi_settimeouts)) to send its whole request. If it
has not by then, or it closes the connection before the headers are complete,
the connection is closed without a response and the next one is accepted.

Likewise, a client that takes none of a response for 30 seconds (the write
timeout), for example one that stopped reading a large download, is given up
on and its connection closed. From then on `RPGAPI_write` and
`RPGAPI_writeBytes` do nothing, so a procedure writing rows still runs to its
end and can close what it opened.

### CORS
A page from another origin (scheme, host and port), such as a front end on
`https://app.example.com` calling the API on `https://api.example.com`, may
only use the API's responses when the API allows that origin. Name the
origins with [RPGAPI_setCors](#rpgapi_setcors), and set the other fields as
needed:

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
- Headers you set yourself, such as `Access-Control-Allow-Origin`, are left as
  you set them.

### Security headers
Browsers have protections they only turn on when a response asks for them:
not guessing a file's type, not letting other sites show the page in a frame,
not sending the page's address along with links, and more. After
[RPGAPI_setSecurityHeaders](#rpgapi_setsecurityheaders), every response
(routes, 404s, errors, static files, streamed responses) has them:

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
policy, or `''` for none.

A header a procedure sets itself is sent instead of RPGAPI's, so one route
can have its own policy or `X-Frame-Options`. `Cross-Origin-Resource-Policy:
same-origin` does not stop other sites from calling the API through CORS, but
it does stop them from embedding its responses as images or scripts; a route
that serves those to other sites sets `Cross-Origin-Resource-Policy:
cross-origin`. The settings are the app's `security_headers` and
`content_security_policy` fields.

### Compression
After [RPGAPI_setCompression](#rpgapi_setcompression), a response is gzipped
when:
- the request's `Accept-Encoding` allows gzip (`gzip`, `x-gzip` or `*`, and
  not with `q=0`). Browsers, curl with `--compressed`, and most HTTP clients
  send one
- its `Content-Type` is text: `text/...`, JSON, JavaScript, XML, SVG, or a
  type ending in `+json` or `+xml`. Images, PDFs and zip files are already
  compressed and are sent as they are, as is a response with no
  `Content-Type`
- its body is at least the threshold. A streamed response of unknown length
  is always gzipped
- your procedure did not set a `Content-Encoding` of its own or
  `Cache-Control: no-transform`, and it is not a 204 or 304

JSON and text usually shrink to a fifth or less, which matters for large
responses on slow connections. A gzipped response has `Content-Encoding:
gzip`, and every response with a text type has `Vary: Accept-Encoding` so
that caches keep a copy for each kind of client (unless your procedure sets
its own `Vary`). Nothing changes in your procedures:
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

### Client address
`request.remote_ip` is the client's IP address, as Express's `req.ip`, for
logging, limits or allowing only some addresses. `request.connection_ip` is
the address the connection came from. Without a proxy in front of the app,
they are the same.

Behind a proxy, such as nginx, IBM HTTP Server or a load balancer, every
connection comes from the proxy, and the proxy passes the client's address in
the `X-Forwarded-For` header. List the proxies' addresses with
[RPGAPI_setTrustedProxies](#rpgapi_settrustedproxies), so that RPGAPI uses
it:
- Only a request whose connection comes from one of them gets `remote_ip`
  from `X-Forwarded-For`; anyone else could send the header with any address.
- The header lists every hop (`client, proxy1, proxy2`), and a client can put
  addresses of its own in front, so RPGAPI reads it from the right, skipping
  the trusted proxies: the first address that is not one of them is the
  client.
- `'*'` trusts every connection and takes the leftmost address; use it only
  when nothing can reach the app except through the proxy.
- Addresses are compared exactly (no ranges such as `10.0.0.0/8`).

The INFO log line for each request shows `remote_ip`, as in
`GET /hello from 203.0.113.9 -> 200, 11 bytes, 3 ms`.

### Request bodies and uploads
`request.body` holds a body of up to 32,000 characters. Bodies can be larger:
up to 1MB by default ([RPGAPI_setMaxRequestSize](#rpgapi_setmaxrequestsize),
up to 16,000,000 bytes), sent with a `Content-Length` or with
`Transfer-Encoding: chunked`, and read with
[RPGAPI_readBody](#rpgapi_readbody) or
[RPGAPI_readBodyBytes](#rpgapi_readbodybytes).

Bodies over that limit can be allowed too, up to a second, larger limit (at
most 2GB), with [RPGAPI_setMaxUploadSize](#rpgapi_setmaxuploadsize). Such a
body is not read into memory before your procedure is called: it is read from
the connection as your procedure asks for it, with the same procedures, or
saved with [RPGAPI_saveBody](#rpgapi_savebody), so memory stays the same
whatever its size.
- A client that sent `Expect: 100-continue` is only asked for the body when
  your procedure first reads it. A procedure that refuses without reading it
  (say with 403) is never sent it.
- `RPGAPI_bodyLength` is -1 while a chunked body's size is not known yet.
- When the body turns out larger than the upload limit, is not valid, or
  stops arriving for the read timeout, the read ends your procedure with an
  escape message and the request is answered with 413, 400 or 408. Monitor
  for it if your procedure has to clean up.
- A body your procedure does not read is dropped.

Forms with files (`multipart/form-data`) are read part by part with
[RPGAPI_nextPart](#rpgapi_nextpart), the same way.

Requests that are refused before your procedures are called:

| Status | When |
| --- | --- |
| 413 Content Too Large | the body is larger than the limit. With `Expect: 100-continue` this is answered before the client sends it |
| 431 Request Header Fields Too Large | the request line and headers are over 32,000 bytes |
| 400 Bad Request | `Content-Length` is not a number, or a chunk is not valid |
| 501 Not Implemented | a `Transfer-Encoding` other than `chunked` |

A procedure that fails with an error it does not handle gets `500 Internal
Server Error`. Your [error handler](#rpgapi_seterrorhandler) can answer all of
these itself.

### Authentication
[RPGAPI_getBearerToken](#rpgapi_getbearertoken) and
[RPGAPI_getBasicAuth](#rpgapi_getbasicauth) read the credentials a client
sends in the `Authorization` header, and
[RPGAPI_checkUserProfile](#rpgapi_checkuserprofile) checks a user and password
against IBM i user profiles. Checking them is up to your app, usually in
middleware, so a route never runs without them. Answer `401`; for Basic, add
a `WWW-Authenticate` header, so a browser asks for a user and password:

```rpgle
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
anyone who has it in: serve them over [HTTPS](#https). RPGAPI does not write
the `Authorization` header to the log.

### Streaming responses
`response.body` holds up to 32,000 characters. For anything larger, or to send
rows as they are read, stream the response instead of returning it:
[RPGAPI_beginResponse](#rpgapi_beginresponse) with the status and headers,
[RPGAPI_write](#rpgapi_write) or [RPGAPI_writeBytes](#rpgapi_writebytes) as
often as you like, then [RPGAPI_endResponse](#rpgapi_endresponse).
- Writes are collected and sent in pieces of 32KB, so writing a row at a time
  is fine.
- The body is sent with `Transfer-Encoding: chunked`, or with a
  `Content-Length` when you pass its size to `RPGAPI_beginResponse`.
- A response you do not end is ended when your procedure returns. If your
  procedure fails after beginning it, the connection is closed, and the
  client can tell the response is incomplete.
- [Views](#views) are streamed the same way.

### Files and directories
[RPGAPI_sendFile](#rpgapi_sendfile) sends an IFS file of any size as it is
stored, and [RPGAPI_serveStatic](#rpgapi_servestatic) serves a whole
directory through it.
- The `Content-Type` comes from the extension: `html`, `css`, `js`, `json`,
  `txt`, `csv`, `xml`, `svg`, `png`, `jpg`, `gif`, `ico`, `pdf`, `zip`,
  otherwise `application/octet-stream`. Headers you set on the response are
  sent too, and a `Content-Type` you set is used instead.
- Files are sent as stored, so keep text files in UTF-8 or ASCII, and the job
  needs authority to read them.
- Like Express, it also sends `Last-Modified`, an `ETag`, `Accept-Ranges:
  bytes` and `Cache-Control: public, max-age=0` (unless you set a
  `Cache-Control`), and for a GET it answers `If-None-Match` /
  `If-Modified-Since` with **304 Not Modified** and no body when the client's
  copy is current, and `Range: bytes=...` (one range) with **206 Partial
  Content** and just those bytes, or **416 Range Not Satisfiable** when the
  range is outside the file. Several ranges get the whole file, and so does a
  range whose `If-Range` names an older version of the file.

A directory served with `RPGAPI_serveStatic(app : '/web' : '/www/myapp')`:
- `GET /web/css/app.css` sends `/www/myapp/css/app.css`. `/web/` sends
  `/www/myapp/index.html`, and a directory asked for without its `/` at the
  end (`/web`, `/web/docs`) is redirected to it, so the relative links in its
  `index.html` work. A directory without an `index.html` is not listed.
- Only `GET` and `HEAD` are served, after the middleware (so a login check
  covers the files too) and before the routes. A path with no file behind it
  goes on to the routes, and then to the 404.
- The path is decoded one segment at a time (`%20`, UTF-8 names), and a path
  that could leave the directory is not served: a `.` or `..` segment, or one
  that decodes to one with `/`, `\` or a NUL (`%2e%2e`, `..%2f`). Files and
  directories whose name starts with `.` (such as `.env`) are not served
  either.
- A symbolic link in the directory is followed, wherever it points.

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
see [streaming responses](#streaming-responses).

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

```rpgle
RPGAPI_setNotFound(app : %paddr(notFound));          // RPGAPI_setNotFound
RPGAPI_setErrorHandler(app : %paddr(failed));        // RPGAPI_setErrorHandler
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

### Character sets
RPGAPI sends and receives UTF-8, and converts it to and from the CCSID of the
job the server runs in: requests are converted from UTF-8 to the job's CCSID
before your procedures see them, and responses from the job's CCSID to UTF-8,
so `Content-Length` counts UTF-8 bytes. The library is compiled with
`TGTCCSID(*JOB)` so that its own text is in that CCSID too. Compile your
application the same way; for SQL RPG use `CRTSQLRPGI ... CVTCCSID(*JOB)
COMPILEOPT('TGTCCSID(*JOB)')`. The README's Character sets section explains
what goes wrong without it.
