# README

## Description
RPGWeb - An web framework for building web application in RPG.  
  
brought to you by [_Modern-I-Nation_](http://modernination.com).

[<img src="./imgs/patreon.png">](https://www.patreon.com/modernination)

## Installation
Install via this SAVF 
[RPGWEB.savf](http://modernination.com/dwnloads/RPGWEB.SAVF). 
Unpack it and it will create the RPGWEB library
for you.

In QShell
```
cd /
git clone ....
```

Then exit QShell and run the following CL command
```
QSYS/CRTBNDCL PGM([YOURLIB]/BUILD)                        
              SRCSTMF('/downloaded/location/RPGWEB/build.clle')
              DBGVIEW(*SOURCE)                         
```

If you cannot compile CL's from the IFS on your machine, use the following command to copy the build program to a source member. Then use the CHGPFM command to make it a CL. Then compile as normal.
```
CPYFRMSTMF FROMSTMF('/downloaded/location/RPGWEB/BUILD.CLLE')
           TOMBR('/QSYS.LIB/[YOURLIB].LIB/QCLSRC.FILE/BUILD.MBR')

CHGPFM FILE([YOURLIB]/QCLSRC) MBR(BUILD) SRCTYPE(CLLE)
```

Then you can run the build script to create the RPGWEB library, and all of the 
programs, and include files.
```
CALL [YOURLIB]/BUILD PARM('/downloaded/location')
```

That's it!!! Now you are ready to write completely RPGLE web api's. Check the 
Quick start guide for a quick intro.

For getting started quickly here is a small quick start guide

[Quick Start](docs/QuickStart.md)

Here is the full documentation for the library.

[Api Documentation](docs/ApiDocumentation.md)


## Dependencies
REGEXP_INSTR 
* 7.1 TR9 
* 7.2 TR1

Custom hex conversion table because I am using QCDXLATE. In a future release we will be changing over to iconv.
```
CRTTBL TBL(RPGWEB/QJSON)       
       SRCFILE(*PROMPT)        
       TBLTYPE(*CVT)           
       BASETBL(QUSRSYS/QTCPASC)
       TEXT('json conversion') 
```
Then make the following changes  
63 -> 5B  
FC -> 5D  
43 -> 7B  
DC -> 7D  
BA -> 5B  
BB -> 5D  
