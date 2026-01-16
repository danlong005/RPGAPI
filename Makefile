LIB=RPGAPI
IFS_PATH=/home/longdm/builds/RPGAPI

all:
	-system "CRTLIB LIB($(LIB))"
	-system "CRTBNDDIR BNDDIR($(LIB)/$(LIB))"
	system "CHGATR OBJ('$(IFS_PATH)/qrpglesrc/*.rpgle') ATR(*CCSID) VALUE(1252)"
	system "CHGATR OBJ('$(IFS_PATH)/qrpglesrc/*.sqlrpgle') ATR(*CCSID) VALUE(1252)"
	system "CRTSQLRPGI OBJ($(LIB)/RPGAPI) SRCSTMF('$(IFS_PATH)/qrpglesrc/RPGAPI.sqlrpgle') OBJTYPE(*MODULE) REPLACE(*YES) DBGVIEW(*SOURCE) OPTION(*EVENTF)"
	-system "CPYTOSTMF FROMMBR('/QSYS.LIB/$(LIB).LIB/EVFEVENT.FILE/RPGAPI.MBR') TOSTMF('$(IFS_PATH)/RPGAPI.evfevent') STMFOPT(*REPLACE)"
	-cat $(IFS_PATH)/RPGAPI.evfevent
	system "CRTSRVPGM SRVPGM($(LIB)/RPGAPI) MODULE($(LIB)/RPGAPI) SRCSTMF('$(IFS_PATH)/qbndsrc/RPGAPI_B.bnd')"
	-system "ADDBNDDIRE BNDDIR($(LIB)/$(LIB)) OBJ(($(LIB)/RPGAPI))"

test:
	system "CHGATR OBJ('$(IFS_PATH)/qtestsrc/*.sqlrpgle') ATR(*CCSID) VALUE(1252)"
	system "RUCRTTST TSTPGM($(LIB)/RPGAPITEST) SRCSTMF('$(IFS_PATH)/qtestsrc/rpgapi.test.sqlrpgle') MODULE($(LIB)/RPGAPI)"
	system "RUCALLTST TSTPGM($(LIB)/RPGAPITEST)"

clean:
	-system "DLTLIB LIB($(LIB))"
