#!/bin/bash

set -e

if [ -d ./build ]; then
	rm -rf build
fi

mkdir build
cd build

../configure -prefix $1 \
	-qt-zlib \
	-nomake examples \
	-nomake tests \
	-opensource \
	-submodules qtbase,qtmultimedia \
	-no-feature-ffmpeg \
	-skip qtdeclarative,qtimageformats,qtlanguageserver,qtquick3d,qtquicktimeline,qtsvg \
	-- -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"

cmake --build . --parallel

