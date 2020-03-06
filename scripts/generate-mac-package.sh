#!/bin/bash
set -e
set -x

SOURCEDIR=src
SOURCEQTDIR=src/qt5

MAKEOPTS=-j5

VERSION=$(cat $SOURCEDIR/rpcemu.h | grep '#define VERSION' | cut -d ' ' -f 3 | sed -e 's/\"//g')
NOW=$(date +"%Y%m%d-%H%M%S")
RELEASENAME=RPCEmu-$VERSION$1

TARGETDIR=../Releases/$RELEASENAME-$NOW
DEBUGDIR=$TARGETDIR/Debug
RELEASEDIR=$TARGETDIR/Release
DATADIR=$TARGETDIR/Data
DMGDIR=$TARGETDIR/DMGs

echo Building release \'$RELEASENAME\'

if [ -d $TARGETDIR ]; then
	rm -rf $TARGETDIR
fi

if [ ! -d $SOURCEDIR ]; then
	echo This script must be run from inside the RPCEmu folder.
	exit 1
fi

mkdir $TARGETDIR
mkdir $DEBUGDIR
mkdir $RELEASEDIR
mkdir $DATADIR
mkdir $DMGDIR

pushd $SOURCEQTDIR > /dev/null

# Clean.
if [ -f Makefile ]; then
	make distclean
fi

echo Configuring interpreter builds...
qmake "CONFIG-=dynarec" rpcemu.pro

echo * Compiling debug build
make -f Makefile.Debug $MAKEOPTS

echo * Compiling release build
make -f Makefile.Release $MAKEOPTS

echo Configuring recompiler builds...
qmake "CONFIG+=dynarec" rpcemu.pro

echo * Compiling debug build
make -f Makefile.Debug $MAKEOPTS

echo * Compiling release build
make -f Makefile.Release $MAKEOPTS

popd > /dev/null

echo Copying application bundles...

cp -r ./rpcemu-interpreter-debug.app $DEBUGDIR/
cp -r ./rpcemu-recompiler-debug.app $DEBUGDIR/

cp -r ./rpcemu-interpreter.app $RELEASEDIR/
cp -r ./rpcemu-recompiler.app $RELEASEDIR/

echo Generating self-contained application bundles...

echo * Debug - interpreter
macdeployqt $DEBUGDIR/rpcemu-interpreter-debug.app

echo * Debug - recompiler
macdeployqt $DEBUGDIR/rpcemu-recompiler-debug.app

echo * Release - interpreter
macdeployqt $RELEASEDIR/rpcemu-interpreter.app

echo * Release - recompiler
macdeployqt $RELEASEDIR/rpcemu-recompiler.app

echo Copying to data directory...
for i in cmos.ram COPYING readme.txt rpc.cfg ; do cp $i $DATADIR/ ; done
for i in netroms riscos-progs roms ; do cp -r $i $DATADIR/ ; done

cp -r $DATADIR $DEBUGDIR/RPCEmu
cp -r $DATADIR $RELEASEDIR/RPCEmu

echo Generating DMGs

echo * Debug
hdiutil create -volname $RELEASENAME-Debug -srcfolder $DEBUGDIR -ov -format UDZO $DMGDIR/$RELEASENAME-Debug.dmg -quiet

echo * Release
hdiutil create -volname $RELEASENAME-Release -srcfolder $RELEASEDIR -ov -format UDZO $DMGDIR/$RELEASENAME-Release.dmg -quiet
