#!/bin/bash
set -e
set -x

SOURCEDIR=src
SOURCEQTDIR=src/qt5
SOURCEHOSTFSDIR=riscos-progs/HostFS

MAKEOPTS=-j5

VERSION=$(cat $SOURCEDIR/rpcemu.h | grep '#define VERSION' | cut -d ' ' -f 3 | sed -e 's/\"//g')
NOW=$(date +"%Y%m%d-%H%M%S")
RELEASENAME=RPCEmu-$VERSION$1

TARGETDIR=../Releases/$RELEASENAME-$NOW
DEBUGDIR=$TARGETDIR/Debug
RELEASEDIR=$TARGETDIR/Release
DATADIR=$TARGETDIR/Data
DMGDIR=$TARGETDIR/DMGs
ZIPDIR=$TARGETDIR/ZIPs
RELZIPDIR=../ZIPs

echo Building release \'$RELEASENAME\'

if [ -d $TARGETDIR ]; then
	rm -rf $TARGETDIR
fi

if [ ! -d $SOURCEDIR ]; then
	echo This script must be run from inside the RPCEmu folder.
	exit 1
fi

BRANCH=$(git branch | grep '^*' | sed 's/* //' )
if [ "$BRANCH" != "macosx-release" ]; then
	echo This script must be run from the release branch.
	exit 1
fi

mkdir $TARGETDIR
mkdir $DEBUGDIR
mkdir $RELEASEDIR
mkdir $DATADIR
mkdir $DMGDIR
mkdir $ZIPDIR

pushd $SOURCEQTDIR > /dev/null

# Clean.
if [ -f Makefile ]; then
	make distclean
fi

echo Configuring interpreter builds...
qmake "CONFIG-=dynarec" rpcemu.pro

echo - Compiling debug build
make -f Makefile.Debug $MAKEOPTS

echo - Compiling release build
make -f Makefile.Release $MAKEOPTS

echo Configuring recompiler builds...
qmake "CONFIG+=dynarec" rpcemu.pro

echo - Compiling debug build
make -f Makefile.Debug $MAKEOPTS

echo - Compiling release build
make -f Makefile.Release $MAKEOPTS

popd > /dev/null

echo Building HostFS modules
pushd $SOURCEHOSTFSDIR > /dev/null
make
popd > /dev/null

echo Copying application bundles...

cp -r ./rpcemu-interpreter-debug.app $DEBUGDIR/RPCEmu-Interpreter-Debug.app
cp -r ./rpcemu-recompiler-debug.app $DEBUGDIR/RPCEmu-Recompiler-Debug.app

cp -r ./rpcemu-interpreter.app $RELEASEDIR/RPCEmu-Interpreter.app
cp -r ./rpcemu-recompiler.app $RELEASEDIR/RPCEmu-Recompiler.app

echo Generating self-contained application bundles...

echo - Debug - interpreter
macdeployqt $DEBUGDIR/RPCEmu-Interpreter-Debug.app

echo - Debug - recompiler
macdeployqt $DEBUGDIR/RPCEmu-Recompiler-Debug.app

echo - Release - interpreter
macdeployqt $RELEASEDIR/RPCEmu-Interpreter.app

echo - Release - recompiler
macdeployqt $RELEASEDIR/RPCEmu-Recompiler.app

echo Copying to data directory...
for i in cmos.ram COPYING readme.txt rpc.cfg ; do cp $i $DATADIR/ ; done
for i in netroms poduleroms roms ; do cp -r $i $DATADIR/ ; done
mkdir $DATADIR/hostfs

cp -r $DATADIR $DEBUGDIR/Data
cp -r $DATADIR $RELEASEDIR/Data

echo Generating DMGs

echo - Debug
hdiutil create -volname $RELEASENAME-Debug -srcfolder $DEBUGDIR -ov -format UDZO -fs HFS+ $DMGDIR/$RELEASENAME-Debug.dmg -quiet

echo - Release
hdiutil create -volname $RELEASENAME-Release -srcfolder $RELEASEDIR -ov -format UDZO -fs HFS+ $DMGDIR/$RELEASENAME-Release.dmg -quiet

echo Generating ZIPs

echo - Debug
pushd $DEBUGDIR > /dev/null
zip -r -q $RELZIPDIR/$RELEASENAME-Debug.zip *
popd > /dev/null

echo - Release
pushd $RELEASEDIR > /dev/null
zip -r -q $RELZIPDIR/$RELEASENAME-Release.zip *
popd > /dev/null
