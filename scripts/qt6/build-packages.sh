#!/bin/sh
set -e
set -x

if [ "$1" == "" ]; then
	echo A version identifer must be specified.
	exit 1
fi

SOURCEDIR=src
SOURCEQTDIR=src/qt5
SOURCEHOSTFSDIR=riscos-progs/HostFS

BUILDDIR=build

MAKEOPTS=-j5

RELEASENAME=RPCEmu-$1

QTX86DIR=/usr/local/qt
QTARMDIR=/usr/local/qt-arm

TARGETDIR=.
DEBUGDIR=$TARGETDIR/Debug
RELEASEDIR=$TARGETDIR/Release
DATADIR=$TARGETDIR/Data
DMGDIR=$TARGETDIR/DMGs
ZIPDIR=$TARGETDIR/ZIPs
RELZIPDIR=../ZIPs

echo "Generating DMGs"

echo - Debug
hdiutil create -volname $RELEASENAME-Debug -srcfolder $DEBUGDIR -ov -format UDZO -fs HFS+ $DMGDIR/$RELEASENAME-Debug.dmg -quiet

echo - Release
hdiutil create -volname $RELEASENAME-Release -srcfolder $RELEASEDIR -ov -format UDZO -fs HFS+ $DMGDIR/$RELEASENAME-Release.dmg -quiet

echo "Generating ZIPs..."

echo - Debug
pushd $DEBUGDIR > /dev/null
zip -r -q $RELZIPDIR/$RELEASENAME-Debug.zip *
popd > /dev/null

echo - Release
pushd $RELEASEDIR > /dev/null
zip -r -q $RELZIPDIR/$RELEASENAME-Release.zip *
popd > /dev/null

echo
echo Package complete.
