#!/bin/sh

set -eu

featureFlagMultiHostFS=OFF
featureFlagNetworking=OFF

while [[ $# -gt 0 ]]
do
	case $1 in
		--help)
			echo "usage: build-rpcemu-package.sh --suffix <version suffix> [--networking]"
			exit 0
			;;
		--multihostfs)
			featureFlagMultiHostFS=ON
			shift
			;;
		--networking)
			featureFlagNetworking=ON
			shift
			;;
		--suffix)
			versionSuffix="$2"
			shift
			shift
			;;
		*)
			echo Unknown argument: $1
			exit 1
			;;
	esac
done

# Define colours.
BLK="\033[0;30m"
GRY="\033[1;30m"
RED="\033[0;31m"
GRN="\033[0;32m"
YEL="\033[0;33m"
BLU="\033[0;34m"
PUR="\033[0;35m"
CYN="\033[0;36m"
WHT="\033[1;37m"

# Set folders for source.
sourceDir=src

# Check the build location is correct.
if [ ! -d ${sourceDir} ]; then
	printf "${RED}This script must be run from inside the RPCEmu folder.${BLK}\n"
	exit 1
fi

# Extract the version number from the "rpcemu.h" header (e.g. "0.9.5").
versionNumber=$(cat ${sourceDir}/rpcemu.h | grep '#define VERSION' | cut -d ' ' -f 3 | sed -e 's/\"//g')

printf "Detected RPCEmu version: ${GRN}${versionNumber}${BLK}\n"
printf "Detected version suffix: ${GRN}${versionSuffix}${BLK}\n"
printf "Included features:\n"

if [ "${featureFlagMultiHostFS}" == "ON" ]; then
	printf "    Multiple drive support for HostFS: ${GRN}Yes${BLK}\n"
else
	printf "    Multiple drive support for HostFS: ${PUR}No${BLK}\n"
fi

if [ "${featureFlagNetworking}" == "ON" ]; then
	printf "    Networking: ${GRN}Yes${BLK}\n"
else
	printf "    Networking: ${PUR}No${BLK}\n"
fi

# Set the location for QT6.
qtDir=/usr/local/qt6

# Allow parallel builds.
makeOpts=-j5

# Set the timestamp for the release.
timestamp=$(date +"%Y%m%d-%H%M%S")

# Set the release name (e.g. "RPCEmu-0.9.5a").
releaseName=RPCEmu-${versionNumber}${versionSuffix}

# Set the output folder for the final product.
targetDir=../Releases/${releaseName}-${timestamp}

# Set the output folders for the debug and release builds.
debugDir=${targetDir}/Debug
releaseDir=${targetDir}/Release

# Set the output folder for the data (cmos file, configuration, etc).
dataDir=${targetDir}/Data

# Set the output folders for the DMG and ZIP files.
dmgDir=${targetDir}/DMGs
zipDir=${targetDir}/ZIPs
relativeZipDir=../ZIPs

# Set the build folders.
buildDir=build
debugBuildDir=${buildDir}/debug
releaseBuildDir=${buildDir}/release

# Record the build configuration.
cat > ${buildDir}/build.config <<EOF
Version: ${versionNumber}
Version suffix: ${versionSuffix}
Multi-HostFS feature enabled: ${featureFlagMultiHostFS}
Networking feature enabled: ${featureFlagNetworking}

Release name: ${releaseName}
EOF

printf "\n${BLK}Building ${GRN}${releaseName}${BLK} using folder ${GRN}${targetDir}${BLK}\n"

# Create required folders.
mkdir -p ${targetDir}
mkdir -p ${debugDir}
mkdir -p ${releaseDir}
mkdir -p ${dataDir}
mkdir -p ${dmgDir}
mkdir -p ${zipDir}

# Delete the build folder if it already exists.
if [ -d ${buildDir} ]; then
	rm -rf ${buildDir}
fi

mkdir -p ${buildDir}
mkdir -p ${debugBuildDir}
mkdir -p ${releaseBuildDir}



# Compile the debug build.
pushd ${debugBuildDir} > /dev/null
cmake -DENABLE_MULTI_HOSTFS=${featureFlagMultiHostFS} -DENABLE_NETWORKING=${featureFlagNetworking} -DENABLE_DEBUG=ON -S ../../src/
make -j5
popd > /dev/null

# Compile the release build.
pushd ${releaseBuildDir} > /dev/null
cmake -DENABLE_MULTI_HOSTFS=${featureFlagMultiHostFS} -DENABLE_NETWORKING=${featureFlagNetworking} -S ../../src/
make -j5
popd > /dev/null



# Create deployable application bundles.
# (i) Debug.
pushd ${debugBuildDir} > /dev/null
for f in *.app
do
	applicationName=$(basename ${f})
	printf "${BLK}Generating application bundle for ${GRN}${applicationName}${BLK}\n"
	${qtDir}/bin/macdeployqt $f -always-overwrite -verbose=1
done
popd > /dev/null

# (ii) Release.
pushd ${releaseBuildDir} > /dev/null
for f in *.app
do
	applicationName=$(basename ${f})
	printf "${BLK}Generating application bundle for ${GRN}${applicationName}${BLK}\n"
	${qtDir}/bin/macdeployqt $f -always-overwrite -verbose=1
done
popd > /dev/null



# Verify the universal binaries.
for a in ${debugBuildDir}/RPCEmu-Interpreter-Debug.app ${releaseBuildDir}/RPCEmu-Interpreter*.app
do
	# Application.
	applicationName=$(basename ${a} | cut -d '.' -f 1)
	architecture=$(lipo -info ${a}/Contents/MacOS/${applicationName} | cut -d ':' -f 3 | xargs)
	
	printf "\nStarting validation of universal binaries for ${GRN}${applicationName}${BLK}\n"

	if [ "${architecture}" != "x86_64 arm64" ]; then
		echo "${RED}Verification of application universal binary ${a} failed - unexpected architecture '${architecture}'${BLK}\n"
		exit 1
	fi

	# Frameworks
	for f in ${a}/Contents/Frameworks/*.framework
	do
		frameworkName=$(basename ${f} | cut -d '.' -f 1)
		architecture=$(lipo -info ${f}/${frameworkName} | cut -d ':' -f 3 | xargs)

		if [ "${architecture}" != "x86_64 arm64" ]; then
			echo "${RED}Verification of framework universal binary ${frameworkName} failed - unexpected architecture '${architecture}'${BLK}\n"
			exit 1
		fi
	done

	printf "Completed validation of universal binaries for ${GRN}${applicationName}${BLK}\n"
done

printf "\n"



# Copy the applications to the final folders.
for a in ${debugBuildDir}/*.app ${releaseBuildDir}/*.app
do
	leafName=$(basename ${a})
	buildType=$(echo ${leafName} | sed -e 's/\.app//' | cut -f 3 -d '-')

	if [ "${buildType}" == "Debug" ]; then
		printf "${BLK}Copying application ${GRN}${leafName}${BLK} to debug folder\n"
		cp -R $a ${debugDir}
	else
		printf "${BLK}Copying application ${GRN}${leafName}${BLK} to release folder\n"
		cp -R $a ${releaseDir}
	fi
done



# Ensure the HostFS files are present.
if [ "${featureFlagMultiHostFS}" == "ON" ]; then
	if [ ! -f poduleroms/multihostfs,ffa ] || [ ! -f poduleroms/multihostfsfiler,ffa ]; then
		printf "\n${BLK}Building ${GRN}HostFS${BLK} binaries\n"
		pushd riscos-progs/MultiHostFS > /dev/null
		make
		popd > /dev/null
	fi
else
	if [ ! -f poduleroms/hostfs,ffa ] || [ ! -f poduleroms/hostfsfiler,ffa ]; then
		printf "\n${BLK}Building ${GRN}HostFS${BLK} binaries\n"
		pushd riscos-progs/HostFS > /dev/null
		make
		popd > /dev/null
	fi
fi

# Create required folders in the data directory.
printf "\n"

for f in hostfs netroms poduleroms roms
do
	printf "${BLK}Creating data folder ${GRN}${f}${BLK}\n"
	mkdir -p ${dataDir}/${f}
done

# Copy required files and folders to the data directory.
printf "\n"

for f in cmos.ram COPYING readme.txt rpc.cfg
do
	printf "${BLK}Copying file ${GRN}${f}${BLK} to data directory\n"
	cp ${f} ${dataDir}/
done

for f in netroms/*,ffa
do
	printf "${BLK}Copying file ${GRN}${f}${BLK} to data directory\n"
	cp ${f} ${dataDir}/netroms
done

if [ "${featureFlagMultiHostFS}" == "ON" ]; then
	for f in poduleroms/multihostfs,ffa poduleroms/multihostfsfiler,ffa
	do
		printf "${BLK}Copying file ${GRN}${f}${BLK} to data directory\n"
		cp ${f} ${dataDir}/poduleroms
	done
else
	for f in poduleroms/hostfs,ffa poduleroms/hostfsfiler,ffa
	do
		printf "${BLK}Copying file ${GRN}${f}${BLK} to data directory\n"
		cp ${f} ${dataDir}/poduleroms
	done
fi

for f in roms/*.txt
do
	printf "${BLK}Copying file ${GRN}${f}${BLK} to data directory\n"
	cp ${f} ${dataDir}/roms
done



# Copy the data to the debug and release folders.
printf "\n${BLK}Copying data folder\n"
cp -R ${dataDir} ${debugDir}/Data
cp -R ${dataDir} ${releaseDir}/Data



# Generate DMGs.
# (i) Debug.
printf "\n${BLK}Building DMG for ${GRN}debug${BLK} application(s)\n"
hdiutil create -volname ${releaseName}-Debug -srcfolder ${debugDir} -ov -format UDZO -fs HFS+ ${dmgDir}/${releaseName}-Debug.dmg -quiet

# (ii) Release.
printf "${BLK}Building DMG for ${GRN}release${BLK} application(s)\n"
hdiutil create -volname ${releaseName}-Release -srcfolder ${releaseDir} -ov -format UDZO -fs HFS+ ${dmgDir}/${releaseName}-Release.dmg -quiet



# Generate ZIPs.
# (i) Debug.
printf "${BLK}Building ZIP for ${GRN}debug${BLK} application(s)\n"

pushd ${debugDir} > /dev/null
zip -r -q ${relativeZipDir}/${releaseName}-Debug.zip *
popd > /dev/null

# (ii) Release.
printf "${BLK}Building ZIP for ${GRN}release${BLK} application(s)\n"

pushd ${releaseDir} > /dev/null
zip -r -q ${relativeZipDir}/${releaseName}-Release.zip *
popd > /dev/null

# EOF
