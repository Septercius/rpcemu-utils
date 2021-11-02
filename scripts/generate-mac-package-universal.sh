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

VERSION=$(cat $SOURCEDIR/rpcemu.h | grep '#define VERSION' | cut -d ' ' -f 3 | sed -e 's/\"//g')
NOW=$(date +"%Y%m%d-%H%M%S")
RELEASENAME=RPCEmu-$VERSION$1

QTX86DIR=/usr/local/qt
QTARMDIR=/usr/local/qt-arm

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

if [ -d $BUILDDIR ]; then
	rm -rf $BUILDDIR
fi

mkdir $BUILDDIR

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

function buildForArchitecture
{
    local ARCHITECTURE=$1
    
    echo "Configuring interpreter builds ($ARCHITECTURE)..."
    
	  pushd $BUILDDIR/$ARCHITECTURE/interpreter
            
    if [ "$ARCHITECTURE" == "x86" ]; then
        configureForX86 $BUILDDIR/$ARCHITECTURE/interpreter "CONFIG-=dynarec"
    else
        configureForArm $BUILDDIR/$ARCHITECTURE/interpreter "CONFIG-=dynarec"
    fi

    compileBuilds $ARCHITECTURE
    
    popd

    if [ "$ARCHITECTURE" == "x86" ]; then
        echo "Configuring recompiler builds ($ARCHITECTURE)..."
        
        pushd $BUILDDIR/$ARCHITECTURE/recompiler
        
        configureForX86 $BUILDDIR/$ARCHITECTURE/interpreter "CONFIG+=dynarec"
        compileBuilds $ARCHITECTURE
        
        popd
    fi
}

function compileBuilds
{
    local ARCHITECTURE="$1"

    echo "- Compiling debug build ($ARCHITECTURE)"
    make -f Makefile.Debug $MAKEOPTS

    echo "- Compiling release build ($ARCHITECTURE)"
    make -f Makefile.Release $MAKEOPTS
}

function configureForArm
{
    local OUTPUTDIR=$1
    local CONFIGVALUE=$2
    
    PATH=$OLDPATH:$QTARMDIR/bin qmake $CONFIGVALUE "QMAKE_APPLE_DEVICE_ARCHS=arm64" -after DESTDIR=../apps ../../../src/qt5/rpcemu.pro
}

function configureForX86
{
    local OUTPUTDIR=$1
    local CONFIGVALUE=$2
  
    PATH=$PATH:$QTX86DIR/bin qmake $CONFIGVALUE -after DESTDIR=../apps ../../../src/qt5/rpcemu.pro
}

function deployForArchitecture
{
	local ARCHITECTURE=$1
	
	echo "Generating self-contained application bundles ($ARCHITECTURE)..."
	
	pushd $BUILDDIR/$ARCHITECTURE/apps
	
	for f in *
	do
		echo "- $f"
		if [ "$ARCHITECTURE" == "x86" ]; then
			$QTX86DIR/bin/macdeployqt $f -qtdir=$QTX86DIR -always-overwrite -verbose=1
		else
			$QTARMDIR/bin/macdeployqt $f -qtdir=$QTARMDIR -always-overwrite -verbose=1
		fi
	done
	
	popd
}

function generateUniversalBinary
{
	local APPNAME=$1
	
	echo - $APPNAME
	makeuniversal $BUILDDIR/universal/$APPNAME $BUILDDIR/x86/apps/$APPNAME $BUILDDIR/arm/apps/$APPNAME
}

function makeFolders
{
		local ARCHITECTURE=$1
		
		mkdir $BUILDDIR/$ARCHITECTURE
		
		if [ "$ARCHITECTURE" == "x86" ] || [ "$ARCHITECTURE" == "arm" ]; then
				mkdir $BUILDDIR/$ARCHITECTURE/apps
				mkdir $BUILDDIR/$ARCHITECTURE/interpreter

				if [ "$ARCHITECTURE" == "x86" ]; then
					mkdir $BUILDDIR/$ARCHITECTURE/recompiler
				fi
    fi
}

function verifyArchitectures
{
	local FILEPATH=$1
	
	if [ ! -f $FILEPATH ]; then
		echo The $FILEPATH file does not exist
		exit 1
	fi	
	
	local ARCHITECTURES=$(lipo -info $FILEPATH | cut -d ':' -f 3 | xargs)
	
	if [ "$ARCHITECTURES" != "x86_64 arm64" ]; then
		echo "    $FILEPATH [FAIL - '$ARCHITECTURES']"
		exit 1
	fi
	
	echo "    $FILEPATH [PASS]"
}

function verifyUniversalBinary
{
	echo - $1

	local APPNAME=$(echo $1 | cut -d '.' -f 1)
	local APPDIR=$BUILDDIR/universal/$1
	local CONTENTSDIR=$APPDIR/Contents
	local FRAMEWORKSDIR=$CONTENTSDIR/Frameworks
	
	local APPFILE=$CONTENTSDIR/MacOS/$APPNAME
	verifyArchitectures $APPFILE
	
	for f in $FRAMEWORKSDIR/*.framework
	do
			local FRAMEWORKNAME=$(basename $f | cut -d '.' -f 1)
			local FRAMEWORKFILE=$f/$FRAMEWORKNAME

			verifyArchitectures $FRAMEWORKFILE
	done
}

makeFolders arm
makeFolders x86
makeFolders universal

buildForArchitecture arm
buildForArchitecture x86

deployForArchitecture arm
deployForArchitecture x86

echo "Generating universal binaries..."

generateUniversalBinary rpcemu-interpreter.app
generateUniversalBinary rpcemu-interpreter-debug.app

verifyUniversalBinary rpcemu-interpreter.app
verifyUniversalBinary rpcemu-interpreter-debug.app

echo "Copying single-architecture binaries..."

for f in $BUILDDIR/x86/apps/*recompiler*
do
	LEAFNAME=$(basename $f)
	
	echo "- $LEAFNAME"
	cp -r $f $BUILDDIR/universal/$LEAFNAME
done

echo "Copying application bundles..."

for f in $BUILDDIR/universal/*
do
	LEAFNAME=$(basename $f)
	
	echo "- $LEAFNAME"
	
	NEWNAME=$(echo $LEAFNAME | sed -e 's/debug/Debug/' -e 's/rpcemu/RPCEmu/' -e 's/interpreter/Interpreter/' -e 's/recompiler/Recompiler/')
	BUILDTYPE=$(echo $LEAFNAME | sed -e 's/\.app//' | cut -f 3 -d '-')
	
	if [ "$BUILDTYPE" == "debug" ]; then
		cp -r $f $DEBUGDIR/$NEWNAME
	else
		cp -r $f $RELEASEDIR/$NEWNAME
	fi
done

echo "Copying to data directory..."
for i in cmos.ram COPYING readme.txt rpc.cfg ; do cp $i $DATADIR/ ; done
for i in netroms poduleroms roms ; do cp -r $i $DATADIR/ ; done
mkdir $DATADIR/hostfs

cp -r $DATADIR $DEBUGDIR/Data
cp -r $DATADIR $RELEASEDIR/Data

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


