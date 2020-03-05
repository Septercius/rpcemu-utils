# rpcemu-utils

This repository contains utilities to aid developing RPCEmu.

## Scripts

This folder contains the following scripts:

### build-qt.sh

This is a Bash script to automate the process of building the QT toolkit that RPCEmu uses for its user interface.  Compiling QT can take a while, even on a machine with plenty of RAM and a fast CPU.  In addition, not all of the frameworks are required by RPCEmu, so it makes sense to cut out as much as possible to reduce build time.

The script compiles QT using the open source license, and will also not build the examples or any tests.

To compile QT, you will need to download the source from the QT web site: https://download.qt.io/archive/qt/.  Navigate to the appropriate version (generally speaking, the latest) and download the "qt-everywhere-src-<version>.tar.gz" file (e.g. for 5.14.1, https://download.qt.io/archive/qt/5.14/5.14.1/single/qt-everywhere-src-5.14.1.tar.xz).

(These instructions assume that 5.14.1 is being downloaded - change file/folder names to suit.)

From the terminal prompt, unpack the archive:

    tar fx qt-everywhere-src-5.14.1.tar.xz
    
Once the unpack process has finished, change into the QT folder:

    cd qt-everywhere-src-5.14.1
    
Next, copy the "build-qt.sh" script into this folder (either via command line or using a file manager).

Type the following to make the script executable:

    chmod +x build-qt.sh
    
The script requires a single parameter, namely the installation folder (e.g. "/opt/qt" or "/usr/local/qt").
    
Run the script, passing in the required installation folder.  For example:

    ./build-qt /usr/local/qt
    
QT will be configured and the script will invoke a build.  It will compile the code using the "-j5" option - change to suit the number of CPU cores present.

When compilation has completed, install QT:

    sudo make install
    
This will prompt you to enter your normal password.  When the shell prompt appears, QT is ready for use.

### make-patch.sh

This is a simple Bash script used to generate a patch file from a folder of unified diffs.  It requires a single parameter, namely the folder that contains the diff files.  For example:

    ./make-patch.sh ../rpcemu-dev/diffs/0.9.2
    
The script will output the diffs to a file named "rpcemu-0.9.2-mac-patch-vX.patch".

