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

2. Point `IFS_PATH` at your clone. Either edit the Makefile, or pass it on the
command line of the build in step 4, which overrides the value in the file:
```bash
IFS_PATH=/home/[youruser]/RPGAPI
```

3. Make sure the target library exists. The build writes into `LIB`, it does not
create it, so create one once up front:
```bash
system "CRTLIB LIB(RPGAPI)"
```
Or skip this and build into a library you already own, which is what you want on
a shared system such as PUB400 where `CRTLIB` is not authorized:
```bash
make all LIB=MYLIB IFS_PATH=/home/[youruser]/RPGAPI
```

4. Build the project:
```bash
make all
```

This will:
- Create the binding directory
- Set the proper CCSID on source files
- Compile the RPGAPI module
- Create the service program
- Add it to the binding directory

If `LIB` does not exist the build stops immediately and tells you so, rather than
failing later with a confusing compile error.

5. (Optional) Run tests:
```bash
make test
```
This needs [iRPGUnit](https://github.com/tools-400/irpgunit) installed in library
`RPGUNIT`; the target fails immediately with `CPF2110` if it is missing.

6. (Optional) Remove the objects the build created (the module, service program,
binding directory and test program):
```bash
make clean
```
The library itself is never deleted. The build does not create it, so it does not
own it, and `LIB` is often a library holding your other work. Drop it yourself
with `DLTLIB` if you really mean to.

### Makefile variables
| Variable | Default | Purpose |
| --- | --- | --- |
| `LIB` | `RPGAPI` | Existing library the module, service program and binding directory are built into |
| `BNDDIR` | `RPGAPI` | Binding directory name. Kept separate from `LIB` so building into a shared library does not create a binding directory named after it |
| `IFS_PATH` | `/home/longdm/builds/RPGAPI` | Absolute IFS path of your clone |


That's it!!! Now you are ready to write completely RPGLE web api's. Check the 
Quick start guide for a quick intro.

For getting started quickly here is a small quick start guide

[Quick Start](QuickStart.md)

Here is the full documentation for the library.

[Api Documentation](ApiDocumentation.md)