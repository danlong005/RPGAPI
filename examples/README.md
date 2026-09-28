# Examples

Complete RPGAPI apps to read and start from. Each file begins with how to
build it, run it and try it with curl.

| Example | Shows |
| --- | --- |
| [hello.rpgle](hello.rpgle) | The smallest app: two routes, one with a `{param}` |
| [notes-api.sqlrpgle](notes-api.sqlrpgle) | A JSON API over an SQL table (GET, POST, PUT, DELETE), with SQL building and reading the JSON. Creates its table in QTEMP, so there is nothing to set up |
| [table-export.sqlrpgle](table-export.sqlrpgle) | Streaming a large SQL result as JSON or as a CSV download, row by row, with `RPGAPI_beginResponse` / `RPGAPI_write`, gzipped for clients that accept it |
| [html-page.rpgle](html-page.rpgle) | An HTML page from views ([views/](views)): a list straight from SQL rendered by a template of HTML and RPG that includes another, compiled at runtime and gzipped |
| [api-key.rpgle](api-key.rpgle) | Middleware that checks an API key header and answers 401, a public health check, and INFO logging |
| [static-files.rpgle](static-files.rpgle) | Serving an IFS directory with `RPGAPI_serveStatic` (content types, `index.html`, caching with 304s, ranges with 206), and one file as a download with `RPGAPI_sendFile` |
| [upload.rpgle](upload.rpgle) | A browser upload form, and `multipart/form-data` files saved to the IFS with `RPGAPI_savePart` |
| [production.rpgle](production.rpgle) | Every setting in one place: jobs, limits, timeouts, logging, HTTPS, security headers, compression, and JSON answers for 404s and errors |
| [yajl-orders.rpgle](yajl-orders.rpgle) | JSON with YAJL: a request body read with `DATA-INTO` and YAJLINTO, a response built with YAJL's generator, and one with `DATA-GEN`. Needs YAJL in library YAJL, in the library list to build and run |
| [memberships.sqlrpgle](memberships.sqlrpgle) | Middleware for all routes and for one path, and a route param read from a table you provide, as JSON built by `JSON_OBJECT` |

All of them listen on port 8080 (memberships on 3012). Build them with the
library holding the RPGAPI binding directory in your library list, and
`TGTCCSID(*JOB)` (for SQL: `CVTCCSID(*JOB)` and `TGTCCSID(*JOB)` in
`COMPILEOPT`), as each file shows; `<clone>` is where you cloned RPGAPI.

The [integration tests](../tests/integration/README.md) compile every example
(`run.sh examples`), so they keep building as RPGAPI changes, and run
`notes-api` and `memberships` (`run.sh sqljson`) and `yajl-orders`
(`run.sh yajl`) against their checks.
