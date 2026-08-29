#!/bin/sh

set -eu
set -x

BLK="\033[0;30m"
GRY="\033[1;30m"
RED="\033[0;31m"
GRN="\033[0;32m"
YEL="\033[0;33m"
BLU="\033[0;34m"
PUR="\033[0;35m"
CYN="\033[0;36m"
WHT="\033[1;37m"

# Check a version suffix was supplied.
if [ "$1" == "" ]; then
	echo A version suffix must be specified.
	exit 1
fi

# Extract the version suffix letter from the arguments.
VERSIONSUFFIX=$1

# Check the branch is correct.
BRANCH=$(git branch | grep '^*' | sed 's/* //' )
if [ "$BRANCH" != "macosx-release" ]; then
 	echo This script must be run from the release branch.
 	exit 1
fi

# Set folders for source.
SOURCEDIR=src
SOURCEQTDIR=${SOURCEDIR}/qt6
SOURCEHOSTFSDIR=riscos-progs/HostFS

# Check the build location is correct.
if [ ! -d ${SOURCEDIR} ]; then
	echo This script must be run from inside the RPCEmu folder.
	exit 1
fi

# Extract the version number from the "rpcemu.h" header (e.g. "0.9.5").
VERSION=$(cat ${SOURCEDIR}/rpcemu.h | grep '#define VERSION' | cut -d ' ' -f 3 | sed -e 's/\"//g')

printf "Detected RPCEmu version: ${GRN}${VERSION}${BLK}\n"
printf "Detected version suffix: ${GRN}${VERSIONSUFFIX}\n"

# Set the build folder.
BUILDDIR=build/qt6

# Allow parallel builds.
MAKEOPTS=-j5

# Set the timestamp for the release.
NOW=$(date +"%Y%m%d-%H%M%S")

# Set the release name (e.g. "RPCEmu-0.9.5a").
RELEASENAME=RPCEmu-${VERSION}${VERSIONSUFFIX}

# Set the location for QT6.
QTDIR=/usr/local/qt6

# Set the output folder for the final product.
TARGETDIR=../Releases/${RELEASENAME}-${NOW}

# Set the output folders for the debug and release builds.
DEBUGDIR=${TARGETDIR}/Debug
RELEASEDIR=${TARGETDIR}/Release

# Set the output folder for the data (cmos file, configuration, etc).
DATADIR=${TARGETDIR}/Data

# Set the output folders for the DMG and ZIP files.
DMGDIR=${TARGETDIR}/DMGs
ZIPDIR=${TARGETDIR}/ZIPs
RELATIVEZIPDIR=../ZIPs

printf "\n${BLK}Building ${GRN}${RELEASENAME}${BLK} into folder ${PUR}${TARGETDIR}${BLK}\n"

# Create required folders.
mkdir -p ${TARGETDIR}
mkdir -p ${DEBUGDIR}
mkdir -p ${RELEASEDIR}
mkdir -p ${DATADIR}
mkdir -p ${DMGDIR}
mkdir -p ${ZIPDIR}

# Delete the build folder if it already exists.
if [ -d ${BUILDDIR} ]; then
	rm -rf ${BUILDDIR}
fi

# Create the build folders for the various architectures.
# (i) ARM - interpreter only.
mkdir -p ${BUILDDIR}/arm
mkdir -p ${BUILDDIR}/arm/apps
mkdir -p ${BUILDDIR}/arm/interpreter

# (ii) Intel - interpreter and recompiler.
mkdir -p ${BUILDDIR}/intel
mkdir -p ${BUILDDIR}/intel/apps
mkdir -p ${BUILDDIR}/intel/interpreter
mkdir -p ${BUILDDIR}/intel/recompiler

# (iii) Universal.
mkdir -p ${BUILDDIR}/universal



# Configure and build the ARM interpreter.
printf "\n${BLK}Starting build of application ${GRN}1${BLK} of ${GRN}3${BLK} - ${GRN}ARM interpreter${BLK}\n"
pushd ${BUILDDIR}/arm/interpreter > /dev/null

PATH=$PATH:${QTDIR}/bin qmake "CONFIG+=networking" "CONFIG-=dynarec" "QMAKE_APPLE_DEVICE_ARCHS=arm64" \
	-after DESTDIR=../apps ../../../../src/qt6/rpcemu.pro

make -f Makefile.Debug $MAKEOPTS
make -f Makefile.Release $MAKEOPTS

popd > /dev/null
printf "\n${BLK}Completed build of application ${GRN}1${BLK} of ${GRN}3${BLK} - ${GRN}ARM interpreter${BLK}\n"



# Configure and build the Intel interpreter.
printf "\n${BLK}Starting build of application ${GRN}2${BLK} of ${GRN}3${BLK} - ${GRN}Intel interpreter${BLK}\n"
pushd ${BUILDDIR}/intel/interpreter > /dev/null

PATH=$PATH:${QTDIR}/bin qmake "CONFIG+=networking" "CONFIG-=dynarec" "QMAKE_APPLE_DEVICE_ARCHS=x86_64" \
	-after DESTDIR=../apps ../../../../src/qt6/rpcemu.pro

make -f Makefile.Debug $MAKEOPTS
make -f Makefile.Release $MAKEOPTS
popd > /dev/null
printf "\n${BLK}Starting build of application ${GRN}2${BLK} of ${GRN}3${BLK} - ${GRN}Intel interpreter${BLK}\n"



# Configure and build the Intel recompiler.
printf "\n${BLK}Starting build of application ${GRN}3${BLK} of ${GRN}3${BLK} - ${GRN}Intel recompiler${BLK}\n"

pushd ${BUILDDIR}/intel/recompiler > /dev/null
PATH=$PATH:${QTDIR}/bin qmake "CONFIG+=networking" "CONFIG+=dynarec" "QMAKE_APPLE_DEVICE_ARCHS=x86_64" \
	-after DESTDIR=../apps ../../../../src/qt6/rpcemu.pro

make -f Makefile.Debug $MAKEOPTS
make -f Makefile.Release $MAKEOPTS

popd > /dev/null
printf "\n${BLK}Completed build of application ${GRN}3${BLK} of ${GRN}3${BLK} - ${GRN}Intel recompiler${BLK}\n\n"



# Generate application bundles.
# (i) ARM.
pushd ${BUILDDIR}/arm/apps > /dev/null
for f in *.app
do
	APPLICATIONNAME=$(basename ${f})
	printf "${BLK}Generating ARM application bundle for ${GRN}${APPLICATIONNAME}${BLK}\n"
	${QTDIR}/bin/macdeployqt $f -always-overwrite -verbose=1
done
popd > /dev/null

# (ii) Intel.
pushd ${BUILDDIR}/intel/apps > /dev/null
for f in *.app
do
	APPLICATIONNAME=$(basename ${f})
	printf "${BLK}Generating Intel application bundle for ${GRN}${APPLICATIONNAME}${BLK}\n"
	
	${QTDIR}/bin/macdeployqt $f -always-overwrite -verbose=1
done
popd > /dev/null



# Generate universal binaries for the interpreter builds.
for f in ${BUILDDIR}/intel/apps/RPCEmu-Interpreter*.app
do
	APPLICATIONNAME=$(basename ${f})
	BINARYNAME=$(echo ${APPLICATIONNAME} | cut -d '.' -f 1)
	
	printf "\nStarting generation of universal binary for application ${GRN}${APPLICATIONNAME}${BLK}\n"
	
	cp -R ${BUILDDIR}/intel/apps/${APPLICATIONNAME} ${BUILDDIR}/universal/
	lipo -create -output ${BUILDDIR}/universal/${APPLICATIONNAME}/Contents/MacOS/${BINARYNAME} \
		${BUILDDIR}/intel/apps/${APPLICATIONNAME}/Contents/MacOS/${BINARYNAME} \
		${BUILDDIR}/arm/apps/${APPLICATIONNAME}/Contents/MacOS/${BINARYNAME}

	printf "Completed generation of universal binary for application ${GRN}${APPLICATIONNAME}${BLK}\n"
done



# Verify the universal binaries.
for a in ${BUILDDIR}/universal/*.app
do
	# Application.
	BINARYNAME=$(basename ${a} | cut -d '.' -f 1)
	ARCHITECTURE=$(lipo -info ${a}/Contents/MacOS/${BINARYNAME} | cut -d ':' -f 3 | xargs)
	
	printf "\nStarting validation of universal binaries for ${GRN}${APPLICATIONNAME}${BLK}\n"

	if [ "$ARCHITECTURE" != "x86_64 arm64" ]; then
		echo "${RED}Verification of application universal binary ${FILEPATH} failed - unexpected architecture '${ARCHITECTURE}'$BLK}\n"
		exit 1
	fi

	# Frameworks
	for f in ${a}/Contents/Frameworks/*.framework
	do
		FRAMEWORKNAME=$(basename ${f} | cut -d '.' -f 1)
		ARCHITECTURE=$(lipo -info ${f}/${FRAMEWORKNAME} | cut -d ':' -f 3 | xargs)

		if [ "$ARCHITECTURE" != "x86_64 arm64" ]; then
			echo "${RED}Verification of framework universal binary ${FRAMEWORKNAME} failed - unexpected architecture '${ARCHITECTURE}'$BLK}\n"
			exit 1
		fi
	done

	printf "Completed validation of universal binaries for ${GRN}${APPLICATIONNAME}${BLK}\n"
done

printf "\n"

# Copy single-architecture applications to the final folders.
for f in ${BUILDDIR}/intel/apps/*Recompiler*.app
do
	LEAFNAME=$(basename ${f})
	BUILDTYPE=$(echo ${LEAFNAME} | sed -e 's/\.app//' | cut -f 3 -d '-')

	if [ "${BUILDTYPE}" == "Debug" ]; then
		printf "${BLK}Copying single-architecture application ${GRN}${LEAFNAME}${BLK} to debug folder\n"
		cp -R $f ${DEBUGDIR}
	else
		printf "${BLK}Copying single-architecture application ${GRN}${LEAFNAME}${BLK} to release folder\n"
		cp -R $f ${RELEASEDIR}
	fi
done



# Copy universal applications to the final folders.
for f in ${BUILDDIR}/universal/*.app
do
	LEAFNAME=$(basename ${f})
	BUILDTYPE=$(echo ${LEAFNAME} | sed -e 's/\.app//' | cut -f 3 -d '-')

	if [ "${BUILDTYPE}" == "Debug" ]; then
		printf "${BLK}Copying universal application ${GRN}${LEAFNAME}${BLK} to debug folder\n"
		cp -R $f ${DEBUGDIR}
	else
		printf "${BLK}Copying universal application ${GRN}${LEAFNAME}${BLK} to release folder\n"
		cp -R $f ${RELEASEDIR}
	fi
done



# Ensure the HostFS files are present.
if [ ! -f poduleroms/hostfs,ffa ] || [ ! -f poduleroms/hostfsfiler,ffa ]; then
	printf "\n${BLK}Building ${GRN}HostFS${BLK} binaries\n"
	pushd riscos-progs/HostFS > /dev/null
	make
	popd > /dev/null
fi



# Copy required files and folders to the data directory.
printf "\n"
for f in cmos.ram COPYING readme.txt rpc.cfg
do
	printf "${BLK}Copying file ${GRN}${f}${BLK} to data directory\n"
	cp ${f} ${DATADIR}/
done

for f in netroms poduleroms roms
do
	printf "${BLK}Copying folder ${GRN}${f}${BLK} to data directory\n"
	cp -R ${f} $DATADIR/
done



# Create an empty HostFS folder
mkdir ${DATADIR}/hostfs



# Copy the data to the debug and release folders.
printf "${BLK} Copying data folder\n"
cp -R ${DATADIR} ${DEBUGDIR}/Data
cp -R ${DATADIR} ${RELEASEDIR}/Data



# Generate DMGs.
# (i) Debug.
printf "\n${BLK}Building DMG for ${GRN}debug${BLK} application(s)\n"
hdiutil create -volname ${RELEASENAME}-Debug -srcfolder ${DEBUGDIR} -ov -format UDZO -fs HFS+ ${DMGDIR}/${RELEASENAME}-Debug.dmg -quiet

# (ii) Release.
printf "${BLK}Building DMG for ${GRN}release${BLK} application(s)\n"
hdiutil create -volname ${RELEASENAME}-Release -srcfolder ${RELEASEDIR} -ov -format UDZO -fs HFS+ ${DMGDIR}/${RELEASENAME}-Release.dmg -quiet



# Generate ZIPs.
# (i) Debug.
printf "${BLK}Building ZIP for ${GRN}debug${BLK} application(s)\n"

pushd ${DEBUGDIR} > /dev/null
zip -r -q ${RELATIVEZIPDIR}/${RELEASENAME}-Debug.zip *
popd > /dev/null

# (ii) Release.
printf "${BLK}Building ZIP for ${GRN}release${BLK} application(s)\n"

pushd ${RELEASEDIR} > /dev/null
zip -r -q ${RELATIVEZIPDIR}/${RELEASENAME}-Release.zip *
popd > /dev/null
