# Examples

Complete RPGAPI apps to read and start from. Each file begins with how to
build it, run it and try it with curl.

| Example | Shows |
| --- | --- |
| [hello.rpgle](hello.rpgle) | The smallest app: two routes, one with a `{param}` |
| [notes-api.sqlrpgle](notes-api.sqlrpgle) | A JSON API over an SQL table (GET, POST, PUT, DELETE), with SQL building and reading the JSON. Creates its table in QTEMP, so there is nothing to set up |
| [table-export.sqlrpgle](table-export.sqlrpgle) | Streaming a large SQL result as JSON or as a CSV download, row by row, with `RPGAPI_beginResponse` / `RPGAPI_write` |
| [api-key.rpgle](api-key.rpgle) | Middleware that checks an API key header and answers 401, a public health check, and INFO logging |
| [static-files.rpgle](static-files.rpgle) | Serving an IFS directory with `RPGAPI_sendFile`: content types, caching (304) and ranges (206) |
| [upload.rpgle](upload.rpgle) | A browser upload form, and `multipart/form-data` files saved to the IFS with `RPGAPI_savePart` |
| [production.rpgle](production.rpgle) | Every setting in one place: jobs, limits, timeouts, logging and HTTPS |
| [memberships.sqlrpgle](memberships.sqlrpgle) | Middleware for all routes and for one path, and a route param read from a table you provide |

All of them listen on port 8080 (memberships on 3012). Build them with the
library holding the RPGAPI binding directory in your library list, and
`TGTCCSID(*JOB)` (for SQL: `CVTCCSID(*JOB)` and `TGTCCSID(*JOB)` in
`COMPILEOPT`), as each file shows; `<clone>` is where you cloned RPGAPI.

The [integration tests](../tests/integration/README.md) compile every example
(`run.sh examples`), so they keep building as RPGAPI changes.
