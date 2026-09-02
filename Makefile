# Library the module, service program and binding directory are built into.
# It must already exist; this Makefile builds into it, it does not create it.
LIB ?= RPGAPI

# Name of the binding directory. Deliberately separate from LIB: building into
# an existing shared library must not create a binding directory named after
# that library. Applications bind against it with ctl-opt bnddir('RPGAPI').
BNDDIR ?= RPGAPI

# Absolute IFS path of this checkout.
IFS_PATH ?= /home/longdm/builds/RPGAPI

SHELL=/QOpenSys/usr/bin/qsh

.PHONY: all test clean

all:
	@system "CHKOBJ OBJ(QSYS/$(LIB)) OBJTYPE(*LIB)" >/dev/null 2>&1 || { \
	  echo "Library $(LIB) does not exist."; \
	  echo "Create it first with  CRTLIB LIB($(LIB))  or build into one you"; \
	  echo "already have:  make all LIB=MYLIB IFS_PATH=$(IFS_PATH)"; \
	  exit 1; \
	}
	-system "CRTBNDDIR BNDDIR($(LIB)/$(BNDDIR))"
	system "CHGATR OBJ('$(IFS_PATH)/qrpglesrc/*.rpgle') ATR(*CCSID) VALUE(1252)"
	system "CHGATR OBJ('$(IFS_PATH)/qrpglesrc/*.sqlrpgle') ATR(*CCSID) VALUE(1252)"
	system "CRTSQLRPGI OBJ($(LIB)/RPGAPI) SRCSTMF('$(IFS_PATH)/qrpglesrc/RPGAPI.sqlrpgle') OBJTYPE(*MODULE) REPLACE(*YES) DBGVIEW(*SOURCE) OPTION(*EVENTF) COMPILEOPT('INCDIR(''$(IFS_PATH)/qrpglesrc'')')"
	-system "CPYTOSTMF FROMMBR('/QSYS.LIB/$(LIB).LIB/EVFEVENT.FILE/RPGAPI.MBR') TOSTMF('$(IFS_PATH)/RPGAPI.evfevent') STMFOPT(*REPLACE)"
	-cat $(IFS_PATH)/RPGAPI.evfevent
	system "CRTSRVPGM SRVPGM($(LIB)/RPGAPI) MODULE($(LIB)/RPGAPI) SRCSTMF('$(IFS_PATH)/qbndsrc/RPGAPI_B.bnd')"
	-system "ADDBNDDIRE BNDDIR($(LIB)/$(BNDDIR)) OBJ(($(LIB)/RPGAPI))"

# RUCRTTST is run from qtestsrc so that the /include '../qrpglesrc/...' in the
# test source resolves: RPGAPI is precompiled into a QTEMP member, so relative
# includes are resolved against the job's current directory, not the source file.
test:
	system "CHGATR OBJ('$(IFS_PATH)/qtestsrc/*.sqlrpgle') ATR(*CCSID) VALUE(1252)"
	cd $(IFS_PATH)/qtestsrc && \
	liblist -a RPGUNIT && \
	system "RPGUNIT/RUCRTTST TSTPGM($(LIB)/RPGAPITEST) SRCSTMF('$(IFS_PATH)/qtestsrc/rpgapi.test.sqlrpgle') MODULE($(LIB)/RPGAPI) BNDSRVPGM((RUTESTCASE))" && \
	system "RPGUNIT/RUCALLTST TSTPGM($(LIB)/RPGAPITEST)"

# Removes what `all` and `test` create. The library is never deleted: this
# Makefile does not create it, so it does not own it.
clean:
	-system "DLTOBJ OBJ($(LIB)/RPGAPITEST) OBJTYPE(*PGM)"
	-system "RMVBNDDIRE BNDDIR($(LIB)/$(BNDDIR)) OBJ(($(LIB)/RPGAPI))"
	-system "DLTOBJ OBJ($(LIB)/RPGAPI) OBJTYPE(*SRVPGM)"
	-system "DLTOBJ OBJ($(LIB)/RPGAPI) OBJTYPE(*MODULE)"
	-system "DLTOBJ OBJ($(LIB)/$(BNDDIR)) OBJTYPE(*BNDDIR)"
