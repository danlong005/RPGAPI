# Library the module, service program and binding directory are built into.
# It must already exist; this Makefile builds into it, it does not create it.
LIB ?= RPGAPI

# Name of the binding directory. Deliberately separate from LIB: building into
# an existing shared library must not create a binding directory named after
# that library. Applications bind against it with ctl-opt bnddir('RPGAPI').
BNDDIR ?= RPGAPI

# Absolute IFS path of this checkout: by default the directory make runs in.
IFS_PATH ?= $(CURDIR)

# zlib, as an ILE service program, for gzip and for naming compiled views.
# IBM i does not come with one: build it from zlib's os400 port (see README).
ZLIB ?= ZLIB/ZLIB

# CCSID of LIB/QRPGLESRC when the build creates it, for the copybooks it puts
# there. Not *JOB: a job of CCSID 65535 would copy them unconverted.
SRC_CCSID ?= 37

# the copybooks copied into LIB/QRPGLESRC, as file:member, so that apps can
# include them from source members as well as from the IFS
COPYBOOKS = rpgapi_h:RPGAPI_H socket_h:SOCKET_H rpgapi_int_h:RPGAPI_INT

SHELL=/QOpenSys/usr/bin/qsh

.PHONY: all test clean integration

all:
	@system "CHKOBJ OBJ(QSYS/$(LIB)) OBJTYPE(*LIB)" >/dev/null 2>&1 || { \
	  echo "Library $(LIB) does not exist."; \
	  echo "Create it first with  CRTLIB LIB($(LIB))  or build into one you"; \
	  echo "already have:  make all LIB=MYLIB IFS_PATH=$(IFS_PATH)"; \
	  exit 1; \
	}
	-system "CRTBNDDIR BNDDIR($(LIB)/$(BNDDIR))"
	system "CHGATR OBJ('$(IFS_PATH)/qrpglesrc/*.rpgle') ATR(*CCSID) VALUE(1252)"
	system "CRTRPGMOD MODULE($(LIB)/RPGAPI) SRCSTMF('$(IFS_PATH)/qrpglesrc/RPGAPI.rpgle') REPLACE(*YES) DBGVIEW(*SOURCE) OPTION(*EVENTF) TGTCCSID(*JOB) INCDIR('$(IFS_PATH)/qrpglesrc')"
	-system "CPYTOSTMF FROMMBR('/QSYS.LIB/$(LIB).LIB/EVFEVENT.FILE/RPGAPI.MBR') TOSTMF('$(IFS_PATH)/RPGAPI.evfevent') STMFOPT(*REPLACE)"
	-cat $(IFS_PATH)/RPGAPI.evfevent
	system "CRTRPGMOD MODULE($(LIB)/VIEWS) SRCSTMF('$(IFS_PATH)/qrpglesrc/views.rpgle') REPLACE(*YES) DBGVIEW(*SOURCE) OPTION(*EVENTF) TGTCCSID(*JOB) INCDIR('$(IFS_PATH)/qrpglesrc')"
	-system "CPYTOSTMF FROMMBR('/QSYS.LIB/$(LIB).LIB/EVFEVENT.FILE/VIEWS.MBR') TOSTMF('$(IFS_PATH)/VIEWS.evfevent') STMFOPT(*REPLACE)"
	system "CRTSRVPGM SRVPGM($(LIB)/RPGAPI) MODULE($(LIB)/RPGAPI $(LIB)/VIEWS) SRCSTMF('$(IFS_PATH)/qbndsrc/RPGAPI_B.bnd') BNDSRVPGM(($(ZLIB)))"
	-system "ADDBNDDIRE BNDDIR($(LIB)/$(BNDDIR)) OBJ(($(LIB)/RPGAPI))"
	system "CRTBNDRPG PGM($(LIB)/ERPG) SRCSTMF('$(IFS_PATH)/qrpglesrc/erpg.rpgle') REPLACE(*YES) DBGVIEW(*SOURCE) TGTCCSID(*JOB) INCDIR('$(IFS_PATH)/qrpglesrc') DFTACTGRP(*NO) BNDDIR($(LIB)/$(BNDDIR))"
	@system "CHKOBJ OBJ($(LIB)/QRPGLESRC) OBJTYPE(*FILE)" >/dev/null 2>&1 || \
	  system "CRTSRCPF FILE($(LIB)/QRPGLESRC) RCDLEN(112) CCSID($(SRC_CCSID)) TEXT('RPG source, and RPGAPI copybooks')"
	for copybook in $(COPYBOOKS); do \
	  member=$${copybook#*:}; \
	  system "CPYFRMSTMF FROMSTMF('$(IFS_PATH)/qrpglesrc/$${copybook%%:*}.rpgle') TOMBR('/QSYS.LIB/$(LIB).LIB/QRPGLESRC.FILE/$$member.MBR') MBROPT(*REPLACE)" && \
	  system "CHGPFM FILE($(LIB)/QRPGLESRC) MBR($$member) SRCTYPE(RPGLE) TEXT('RPGAPI copybook, from $${copybook%%:*}.rpgle')" || exit 1; \
	done

# RUCRTTST is run from qtestsrc so that the /include '../qrpglesrc/...' in the
# test source resolves: RPGAPI is precompiled into a QTEMP member, so relative
# includes are resolved against the job's current directory, not the source file.
# liblist fails (CPF2103) when RPGUNIT is already in the library list, so its
# result is ignored: a missing RPGUNIT still stops RUCRTTST.
test:
	system "CHGATR OBJ('$(IFS_PATH)/qtestsrc/*.sqlrpgle') ATR(*CCSID) VALUE(1252)"
	cd $(IFS_PATH)/qtestsrc && \
	{ liblist -a RPGUNIT >/dev/null 2>&1 || true; } && \
	system "RPGUNIT/RUCRTTST TSTPGM($(LIB)/RPGAPITEST) SRCSTMF('$(IFS_PATH)/qtestsrc/rpgapi.test.sqlrpgle') MODULE($(LIB)/RPGAPI $(LIB)/VIEWS) BNDSRVPGM((RUTESTCASE) ($(ZLIB))) TGTCCSID(*JOB)" && \
	system "RPGUNIT/RUCALLTST TSTPGM($(LIB)/RPGAPITEST)"

# Runs the integration tests in tests/integration against a build in LIB: see
# tests/integration/README.md. SUITES picks some of them. The PASE shell is
# named in full: SHELL is qsh, where sh is qsh too, and run.sh under qsh writes
# its files in EBCDIC.
integration:
	/QOpenSys/usr/bin/sh $(IFS_PATH)/tests/integration/run.sh $(SUITES)

# Removes what `all` and `test` create. The library is never deleted: this
# Makefile does not create it, so it does not own it. Nor is QRPGLESRC, which
# may hold your own source: only the copybook members are removed.
clean:
	-system "DLTOBJ OBJ($(LIB)/RPGAPITEST) OBJTYPE(*PGM)"
	-system "DLTOBJ OBJ($(LIB)/ERPG) OBJTYPE(*PGM)"
	-system "RMVBNDDIRE BNDDIR($(LIB)/$(BNDDIR)) OBJ(($(LIB)/RPGAPI))"
	-system "DLTOBJ OBJ($(LIB)/RPGAPI) OBJTYPE(*SRVPGM)"
	-system "DLTOBJ OBJ($(LIB)/RPGAPI) OBJTYPE(*MODULE)"
	-system "DLTOBJ OBJ($(LIB)/VIEWS) OBJTYPE(*MODULE)"
	-system "DLTOBJ OBJ($(LIB)/$(BNDDIR)) OBJTYPE(*BNDDIR)"
	-for copybook in $(COPYBOOKS); do \
	  system "RMVM FILE($(LIB)/QRPGLESRC) MBR($${copybook#*:})"; \
	done
