#!/bin/bash

set -e
set -x

if [ -d install-universal ]; then
	rm -rf install-universal
fi

if [ ! -d install-arm ]; then
	echo The 'install-arm' folder cannot be found.
	exit 1
fi

if [ ! -d install-x86 ]; then
	echo The 'install-x86' folder cannot be found.
	exit 1
fi


UNIVERSALDIR=install-universal
BINDIR=bin
LIBDIR=lib

mkdir $UNIVERSALDIR
mkdir $UNIVERSALDIR/$BINDIR
mkdir $UNIVERSALDIR/$LIBDIR

for f in install-arm/bin/* install-x86/bin/*
do
	LEAFNAME=$(basename $f)
	ARMFILE=install-arm/bin/$LEAFNAME
	X86FILE=install-x86/bin/$LEAFNAME
	UNIVERSALFILE=$UNIVERSALDIR/bin/$LEAFNAME
	
	if [ ! -f $UNIVERSALFILE ]; then
		echo "- $LEAFNAME"
		
		if [ -f $ARMFILE ] && [ -f $X86FILE ]; then
			lipo -create -arch arm64 $ARMFILE -arch x86_64 $X86FILE -output $UNIVERSALFILE
		elif [ -f $ARMFILE ]; then
			cp $ARMFILE $UNIVERSALFILE
		elif [ -f $X86FILE ]; then
			cp $X86FILE $UNIVERSALFILE
		fi
	fi
done

for f in install-x86/lib/*.a install-arm/lib/*.a
do
	LEAFNAME=$(basename $f)
	ARMFILE=install-arm/lib/$LEAFNAME
	X86FILE=install-x86/lib/$LEAFNAME
	UNIVERSALFILE=$UNIVERSALDIR/lib/$LEAFNAME
	
	if [ ! -f $UNIVERSALFILE ]; then
		echo "- $LEAFNAME"
		
		if [ -f $ARMFILE ] && [ -f $X86FILE ]; then
			lipo -create -arch arm64 $ARMFILE -arch x86_64 $X86FILE -output $UNIVERSALFILE
		elif [ -f $ARMFILE ]; then
			cp $ARMFILE $UNIVERSALFILE
		elif [ -f $X86FILE ]; then
			cp $X86FILE $UNIVERSALFILE
		fi
	fi	
done

for f in install-x86/lib/*.dylib install-arm/lib/*.dylib
do
	LEAFNAME=$(basename $f)
	ARMFILE=install-arm/lib/$LEAFNAME
	X86FILE=install-x86/lib/$LEAFNAME
	UNIVERSALFILE=$UNIVERSALDIR/lib/$LEAFNAME
	
	if [ ! -f $UNIVERSALFILE ]; then
		echo "- $LEAFNAME"
		
		if [ -f $ARMFILE ] && [ -f $X86FILE ]; then
			lipo -create -arch arm64 $ARMFILE -arch x86_64 $X86FILE -output $UNIVERSALFILE
		elif [ -f $ARMFILE ]; then
			cp $ARMFILE $UNIVERSALFILE
		elif [ -f $X86FILE ]; then
			cp $X86FILE $UNIVERSALFILE
		fi
	fi	
done

for f in $UNIVERSALDIR/$BINDIR/*
do
	LEAFNAME=$(basename $f)
	
	echo "- $LEAFNAME"
	install -c -m 755 $f "/usr/local/bin"
done

for f in install-universal/lib/*.dylib
do
	LEAFNAME=$(basename $f)
	
	echo "- $LEAFNAME"
	install -c -m 755 $f "/usr/local/lib"
done

for f in $UNIVERSALDIR/$LIBDIR/*.a
do
	LEAFNAME=$(basename $f)
	
	echo "- $LEAFNAME"
	install -c -m 644 $f "/usr/local/bin"
done
