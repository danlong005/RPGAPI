#!/QOpenSys/usr/bin/sh
# Integration tests for RPGAPI, run on the IBM i in a clone of the repository:
#
#   sh tests/integration/run.sh [suite ...]
#
# Builds RPGAPI into LIB, compiles the test apps into it, and for each suite
# starts an app in a batch job, runs its checks against it on PORT, and ends
# it. With no suites named, runs them all. Settings, from the environment:
#   LIB      library to build into (default RPGAPI); it must exist
#   PORT     port the apps listen on (default 41731); it must be free
#   WORK     work directory for test files (default tests/integration/work)
#   TIMEOUT  read/write timeout for the apps, seconds (default 5)
#   PYTHON   Python 3 (default /QOpenSys/pkgs/bin/python3)
#   MAKE     GNU make (default /QOpenSys/pkgs/bin/make)
# The library is not cleared. Exits with 1 when a check fails.

REPO=$(cd "$(dirname "$0")/../.." && pwd)
TESTS=$REPO/tests/integration
LIB=${LIB:-RPGAPI}
PORT=${PORT:-41731}
WORK=${WORK:-$TESTS/work}
TIMEOUT=${TIMEOUT:-5}
PYTHON=${PYTHON:-/QOpenSys/pkgs/bin/python3}
MAKE=${MAKE:-/QOpenSys/pkgs/bin/make}
QSH=/QOpenSys/usr/bin/qsh
ALL="basic timeouts routes misc hello bodies multipart stream jobs logging tls examples"
SUITES=${*:-$ALL}
PASSED=0
FAILED=0
FAILURES=""
JOB=""

cl() { system "$1" </dev/null 2>&1; }
# the first value of an SQL query
sql() { $QSH -c "db2 \"$1\"" </dev/null 2>/dev/null | sed -n 4p | sed 's/^ *//; s/ *$//'; }
listening() { sql "select count(*) from qsys2.netstat_job_info where local_port = $PORT"; }
running() { sql "select count(*) from table(qsys2.active_job_info(job_name_filter => '$1')) x"; }

pass() { PASSED=$((PASSED + 1)); echo "PASS $1"; }
fail() { FAILED=$((FAILED + 1)); FAILURES="$FAILURES
  $1"; echo "FAIL $1"; }

# compiles an app from apps/, with the RPGAPI binding directory in LIB
compile() {
  name=$1
  upper=$(echo "$name" | tr a-z A-Z)
  cl "CHGATR OBJ('$TESTS/apps/*') ATR(*CCSID) VALUE(1252)" >/dev/null
  if [ -f "$TESTS/apps/$name.sqlrpgle" ]; then
    command="CRTSQLRPGI OBJ($LIB/$upper) SRCSTMF('$TESTS/apps/$name.sqlrpgle') CVTCCSID(*JOB) DBGVIEW(*SOURCE) COMPILEOPT('INCDIR(''$REPO/qrpglesrc'' ''$TESTS/apps'') TGTCCSID(*JOB)')"
  else
    command="CRTBNDRPG PGM($LIB/$upper) SRCSTMF('$TESTS/apps/$name.rpgle') INCDIR('$REPO/qrpglesrc' '$TESTS/apps') DBGVIEW(*SOURCE) TGTCCSID(*JOB)"
  fi
  $QSH -c "liblist -a $LIB >/dev/null 2>&1; system \"$command\"" </dev/null > "$WORK/compile-$name.log" 2>&1
  if cl "CHKOBJ OBJ($LIB/$upper) OBJTYPE(*PGM)" >/dev/null; then
    return 0
  fi
  fail "compile $name (see $WORK/compile-$name.log)"
  return 1
}

# compiles an example from examples/ as $2, only to check that it builds
compile_example() {
  file=$1 object=$2
  cl "CHGATR OBJ('$REPO/examples/*') ATR(*CCSID) VALUE(1252)" >/dev/null
  case $file in
    *.sqlrpgle) command="CRTSQLRPGI OBJ($LIB/$object) SRCSTMF('$REPO/examples/$file') CVTCCSID(*JOB) COMPILEOPT('INCDIR(''$REPO/qrpglesrc'') TGTCCSID(*JOB)')" ;;
    *)          command="CRTBNDRPG PGM($LIB/$object) SRCSTMF('$REPO/examples/$file') INCDIR('$REPO/qrpglesrc') TGTCCSID(*JOB)" ;;
  esac
  cl "DLTOBJ OBJ($LIB/$object) OBJTYPE(*PGM)" >/dev/null
  $QSH -c "liblist -a $LIB >/dev/null 2>&1; system \"$command\"" </dev/null > "$WORK/compile-$object.log" 2>&1
  if cl "CHKOBJ OBJ($LIB/$object) OBJTYPE(*PGM)" >/dev/null; then
    pass "example $file compiles"
  else
    fail "example $file does not compile (see $WORK/compile-$object.log)"
  fi
}

# settings for the next app: log level;request limit;upload limit;timeout;jobs;tls
configure() {
  cl "CRTDTAARA DTAARA($LIB/TESTCFG) TYPE(*CHAR) LEN(500)" >/dev/null
  cl "CHGDTAARA DTAARA($LIB/TESTCFG) VALUE('$PORT;$1;$WORK;$2')" >/dev/null
}

# submits an app and waits for it to listen; library list in $2
start_app() {
  upper=$(echo "$1" | tr a-z A-Z)
  out=$(cl "SBMJOB CMD(CALL PGM($LIB/$upper)) JOB($upper) INLLIBL(${2:-*CURRENT}) INQMSGRPY(*DFT)")
  JOB=$(echo "$out" | sed -n 's/.*Job \([^ ]*\) submitted.*/\1/p')
  user=$(echo "$JOB" | cut -d/ -f2)
  i=0
  while [ $i -lt 60 ]; do
    [ "$(listening)" != "0" ] && return 0
    # a job that has ended is on the output queue: it will not listen
    [ "$(sql "select job_status from table(qsys2.job_info(job_user_filter => '$user')) x where job_name = '$JOB'")" = "OUTQ" ] && return 1
    sleep 1
    i=$((i + 1))
  done
  return 1
}

# ends the app's job and waits for its jobs to end and the port to be free
stop_app() {
  upper=$(echo "$1" | tr a-z A-Z)
  [ -n "$JOB" ] && cl "ENDJOB JOB($JOB) OPTION(*IMMED)" >/dev/null
  i=0
  while [ $i -lt 30 ]; do
    [ "$(listening)" = "0" ] && [ "$(running "$upper")" = "0" ] && return 0
    sleep 1
    i=$((i + 1))
  done
  return 1
}

client() {
  "$PYTHON" "$TESTS/clients/$1.py" --port "$PORT" --work "$WORK" --timeout "$TIMEOUT" "$2" > "$WORK/client.out" 2>&1
  status=$?
  cat "$WORK/client.out"
  PASSED=$((PASSED + $(grep -c '^PASS ' "$WORK/client.out")))
  count=$(grep -c '^FAIL ' "$WORK/client.out")
  FAILED=$((FAILED + count))
  [ "$count" -gt 0 ] && FAILURES="$FAILURES
$(grep '^FAIL ' "$WORK/client.out" | sed "s/^FAIL /  $1 $2: /")"
  if [ $status -ne 0 ] && [ "$count" -eq 0 ]; then
    fail "$1 $2 client ended with status $status"
  fi
}

# starts an app with settings, runs a client, ends the app
suite() {
  app=$1 settings=$2 name=$3 mode=$4 libraries=$5
  configure "$settings" ""
  if start_app "$app" "$libraries"; then
    client "$name" "$mode"
  else
    fail "$app did not start listening on port $PORT"
  fi
  stop_app "$app" || fail "$app did not end"
}

# starts an app that must fail to start, and looks for text in its job log
fails_to_start() {
  app=$1 settings=$2 tls=$3 text=$4
  configure "$settings" "$tls"
  upper=$(echo "$app" | tr a-z A-Z)
  if start_app "$app"; then
    fail "$app started although it should not ($text)"
    stop_app "$app"
    return
  fi
  i=0
  found=""
  while [ $i -lt 15 ] && [ -z "$found" ]; do
    sleep 1
    found=$($QSH -c "db2 \"select spooled_data from table(systools.spooled_file_data(job_name => '$JOB', spooled_file_name => 'QPJOBLOG')) x\"" </dev/null 2>/dev/null | tr -d '\n' | tr -s ' ' | grep -c "$text")
    [ "$found" = "0" ] && found=""
    i=$((i + 1))
  done
  if [ -n "$found" ]; then pass "$app fails to start with '$text'"; else fail "$app job log has no '$text'"; fi
}

echo "RPGAPI integration tests: library $LIB, port $PORT, work $WORK"
if [ "$(listening)" != "0" ]; then
  echo "Port $PORT is in use; set PORT to a free one"
  exit 1
fi
mkdir -p "$WORK/files" "$WORK/uploads"
"$PYTHON" - "$WORK" <<'PY'
import os, sys
work = sys.argv[1]
files = os.path.join(work, 'files')
open(os.path.join(files, 'big.bin'), 'wb').write(os.urandom(2000000))
open(os.path.join(files, 'huge.bin'), 'wb').write(os.urandom(20000000))
open(os.path.join(files, 'data.json'), 'wb').write(b'{"a": [1, 2, 3], "b": "x@y"}')
open(os.path.join(files, 'pic.png'), 'wb').write(bytes([137, 80, 78, 71]) + os.urandom(50000))
open(os.path.join(files, 'notes.txt'), 'wb').write('hello Jürgen\n'.encode())
open(os.path.join(work, 'secret.txt'), 'wb').write(b'secret')
PY

echo "== build"
(cd "$REPO" && "$MAKE" all LIB="$LIB" IFS_PATH="$REPO" </dev/null > "$WORK/build.log" 2>&1)
if grep -q "CPC5D0B" "$WORK/build.log"; then pass "build RPGAPI into $LIB"; else fail "build (see $WORK/build.log)"; exit 1; fi

T=$TIMEOUT
for suite_name in $SUITES; do
  echo "== $suite_name"
  case $suite_name in
    basic)     compile basic && suite basic ";;;$T;" basic ;;
    timeouts)  compile basic && suite basic ";;;$T;" timeouts ;;
    routes)    compile routes && suite routes ";;;;" routes ;;
    misc)      compile misc && suite misc ";;;;" misc ;;
    hello)     compile hello && suite hello ";;;;" hello ;;
    bodies)    compile bodies && {
                 suite bodies ";;;$T;" bodies memory
                 suite bodies ";;100000000;$T;" bodies uploads
                 suite bodies ";1000;3000000;$T;" bodies limits; } ;;
    multipart) compile bodies && suite bodies ";;100000000;$T;" multipart ;;
    stream)    compile stream && suite stream ";;;$T;" stream ;;
    jobs)      compile jobs && {
                 suite jobs ";;;;4" jobs "$LIB QGPL QTEMP" "$LIB QGPL QTEMP"
                 [ "$(running JOBS)" = "0" ] && pass "jobs: all 4 jobs end with the main job" || fail "jobs: jobs left running"; } ;;
    logging)   compile logging && {
                 for level in 0 1 2 3 4; do suite logging "$level;1000;;$T;" logging $level; done
                 fails_to_start logging "9;1000;;$T;" "" "is not a level"; } ;;
    tls)       compile tls && {
                 fails_to_start tls ";;;;" "APP:RPGAPI_TEST_NOT_REGISTERED" "not registered"
                 fails_to_start tls ";;;;" "KDB:$WORK/missing.kdb:secret" "Key database file was not found"
                 suite tls ";;;;" tls; } ;;
    examples)  compile_example hello.rpgle EXHELLO
               compile_example notes-api.sqlrpgle EXNOTES
               compile_example table-export.sqlrpgle EXEXPORT
               compile_example api-key.rpgle EXAPIKEY
               compile_example static-files.rpgle EXFILES
               compile_example upload.rpgle EXUPLOAD
               compile_example production.rpgle EXPROD
               compile_example memberships.sqlrpgle EXMEMBERS ;;
    *)         fail "no suite called $suite_name" ;;
  esac
done

rm -rf "$WORK/uploads" "$WORK/files/huge.bin"
echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -gt 0 ] && echo "Failures:$FAILURES" && exit 1
exit 0
