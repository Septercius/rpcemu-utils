#!/bin/bash

set -e

./configure -prefix $1 \
	-nomake examples \
	-nomake tests \
	-opensource \
	-confirm-license \
	-skip qt3d \
	-skip qtactiveqt \
	-skip qtandroidextras \
	-skip qtcanvas3d \
	-skip qtcharts \
	-skip qtconnectivity \
	-skip qtdatavis3d \
	-skip qtdeclarative \
	-skip qtdoc \
	-skip qtgamepad \
	-skip qtgraphicaleffects \
	-skip qtimageformats \
	-skip qtlocation \
	-skip qtnetworkauth \
	-skip qtpurchasing \
	-skip qtquickcontrols \
	-skip qtquickcontrols2 \
	-skip qtremoteobjects \
	-skip qtscript \
	-skip qtscxml \
	-skip qtsensors \
	-skip qtserialbus \
	-skip qtserialport \
	-skip qtspeech \
	-skip qtsvg \
	-skip qtvirtualkeyboard \
	-skip qtwayland \
	-skip qtwebchannel \
	-skip qtwebengine \
	-skip qtwebglplugin \
	-skip qtwebsockets \
	-skip qtwebview \
	-skip qtxmlpatterns

sed -e '/^        CONFIG += no_plist$/d;/^    !force_debug_plist/d' -i .bak qtbase/mkspecs/features/resolve_config.prf
make -j5

