# README

## Description
A small RPGLE web framework for building web api's on the IBM i.

## Dependencies
REGEXP_INSTR 
* 7.1 TR9 
* 7.2 TR1

## Installation

1. Clone the repository in QShell:
```bash
cd /home/[youruser]
git clone git@github.com:danlong005/RPGAPI.git
```

2. Update the `IFS_PATH` variable in the Makefile to match your clone location:
```bash
cd RPGAPI
# Edit the Makefile and set IFS_PATH to your actual path
```

3. Build the project:
```bash
make all
```

This will:
- Create the RPGAPI library
- Create the binding directory
- Set the proper CCSID on source files
- Compile the RPGAPI module
- Create the service program
- Add it to the binding directory

4. (Optional) Run tests:
```bash
make test
```

5. (Optional) Clean/remove the library:
```bash
make clean
```


That's it!!! Now you are ready to write completely RPGLE web api's. Check the 
Quick start guide for a quick intro.

For getting started quickly here is a small quick start guide

[Quick Start](QuickStart.md)

Here is the full documentation for the library.

[Api Documentation](ApiDocumentation.md)