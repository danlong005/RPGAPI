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
  dcl-ds response likeds(RPGAPI_Response);
  
  ...your code...
  
  return response;
end-proc;
```
You will notice that the procedure takes a RPGAPI_Request(RPGAPI request) and returns a RPGAPI_Response(RPGAPI response). That's it! Inside of the method you can create whatever you need and load it into the response before you return it. We will dive more into this later.

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
- to stop the server, end the job you started; the others end within a few
  seconds. A job that ends on its own is not replaced

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

Each job handles one connection at a time, so a client has 30 seconds to send
its whole request. If it has not by then, or it closes the connection before the
headers are complete, the connection is closed without a response and the next
one is accepted.

Likewise, a client that takes none of a response for 30 seconds, for example
one that stopped reading a large download, is given up on and its connection
closed. From then on `RPGAPI_write` and `RPGAPI_writeBytes` do nothing, so a
procedure writing rows still runs to its end and can close what it opened.


#### Routing
To create routes in your application we have given you several ways to create those. 

First up is the setRoute method. This can be used for all types of routes. POST, PATCH, PUT, DELETE, GET... etc You simply pass the application data structure, METHOD, url and a pointer to the procedure you want to call when this route is hit. 

```
RPGAPI_setRoute(app : METHOD : url : %paddr(procedure));
```

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

When defining routes it is the same as other api frameworks. Define specific routes before more general routes.
```
RPGAPI_get(app : '/api/v1/memberships/{id}' : %paddr(MBR_show));
RPGAPI_get(app : '/api/v1/memberships' : %paddr(MBR_index));
```

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


### Requests
Given that you followed the outline specs for your callback procedures the request datastructure will be passed into the method that is handing the current request. You can find everything out about the request by looking in the request data structure. 

#### Headers
These are the headers that came in on the request. You can access those headers using the following api method

```
header_value = RPGAPI_getHeader(request : 'Content-Type');
```

#### Params
These are the route params that came in on the request. To define route params in your route see the section on routing. You can access the params using the following api method

```
id_value = RPGAPI_getParam(request : 'id');
```

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
RPGAPI_setMaxRequestSize(5000000);
RPGAPI_start(app);
```

#### Uploads larger than memory
Bodies over the request size limit can be allowed too, up to a second, larger
limit (at most 2GB):

```
RPGAPI_setMaxUploadSize(500000000);     // 500MB; 0, the default, is off
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
  stops arriving for 30 seconds, the read ends your procedure with an escape
  message and the request is answered with 413, 400 or 408. Monitor for it if
  your procedure has to clean up.
- A body your procedure does not read is dropped.

Requests that are refused before your procedures are called:
| Status | When |
| --- | --- |
| 413 Content Too Large | the body is larger than the limit. With `Expect: 100-continue` this is answered before the client sends it |
| 431 Request Header Fields Too Large | the request line and headers are over 32,000 bytes |
| 400 Bad Request | `Content-Length` is not a number, or a chunk is not valid |
| 501 Not Implemented | a `Transfer-Encoding` other than `chunked` |

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
  dcl-ds response likeds(RPGAPI_Response);

  return response;
```

#### Headers
You can set response headers very easily. The following is an example. 

```
RPGAPI_setHeader(response : 'Connection' : 'close');
```

#### Body
Setting the body of the response can be done like so.

```
response.body = 'Here is the body!';
```

#### Status
Once again setting the status is a simple thing to to do.

```
response.status = 200;

// some http codes are mapped into constants. We are working to map more of them.
response.status = HTTP_OK;      // 200
response.status = HTTP_CREATED; // 201
```

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