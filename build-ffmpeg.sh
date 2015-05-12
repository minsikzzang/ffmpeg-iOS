#!/bin/sh

#  build-ffmpeg.sh
#  Automated ffmpeg build script for iPhoneOS and iPhoneSimulator
#
#  Created by Min Kim on 10/1/13.
#  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#  Change values here	(ffmpeg and iOS SDK version)												#
#																		                                      #
SDKVERSION="8.3"
VERSION="2.0.1"
#																		                                      #
###########################################################################
#																		                                      #
# Don't change anything under this line!								                  #
#																		                                      #
###########################################################################

CURRENTPATH=`pwd`
ARCHS="i386 x86_64 armv7 armv7s arm64"
BUILDPATH="${CURRENTPATH}/build"
LIBPATH="${CURRENTPATH}/lib"
INCLUDEPATH="${CURRENTPATH}/include"
SRCPATH="${CURRENTPATH}/src"
DEVELOPER=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

set -e
if [ ! -e ffmpeg-${VERSION}.tar.bz2 ]; then
	echo "Downloading ffmpeg-${VERSION}.tar.bz2"
    curl -O http://ffmpeg.org/releases/ffmpeg-${VERSION}.tar.bz2
else
	echo "Using ffmpeg-${VERSION}.tar.bz2"

	# Remove the source directory if already exist
  rm -rf "${SRCPATH}/ffmpeg-${VERSION}"
fi

# Before building libarary, copy the gas-procecessor.pl to '/usr/local/bin'
cp gas-preprocessor.pl /usr/local/bin/gas-preprocessor.pl

mkdir -p "${SRCPATH}"
mkdir -p "${BUILDPATH}"
mkdir -p "${LIBPATH}"
mkdir -p "${INCLUDEPATH}"

tar zxf ffmpeg-${VERSION}.tar.bz2 -C "${SRCPATH}"
cd "${SRCPATH}/ffmpeg-${VERSION}"

for ARCH in ${ARCHS}
do
	if [ "${ARCH}" == "i386" -o "${ARCH}" == "x86_64" ];
	then
		PLATFORM="iPhoneSimulator"
		if [ "${ARCH}" == "i386" ];
		then
			EXTRA_CONFIG="--arch=i386 --target-os=darwin --enable-cross-compile"
    	EXTRA_CFLAGS="-arch i386 -miphoneos-version-min=7.0"
    else
    	EXTRA_CONFIG="--arch=x86_64 --target-os=darwin --enable-cross-compile"
    	EXTRA_CFLAGS="-arch x86_64 -miphoneos-version-min=7.0"
    fi
	else
		PLATFORM="iPhoneOS"
		EXTRA_CONFIG="--arch=arm --target-os=darwin --enable-cross-compile --disable-armv5te"
    		EXTRA_CFLAGS="-w -arch ${ARCH} -miphoneos-version-min=7.0"
	fi

  EXTRA_LDFLAGS="-miphoneos-version-min=7.0"
  OUTPATH="${BUILDPATH}/ffmpeg-${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
  mkdir -p "${OUTPATH}"
  LOG="${OUTPATH}/build-ffmpeg.log"

	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
  export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
  SDKPATH="${CROSS_TOP}/SDKs/${CROSS_SDK}"

	echo "Building ffmpeg-${VERSION} for ${PLATFORM} ${SDKVERSION} ${ARCH}"
	echo "Please stand by..."

  if [ ! -d "$SDKPATH" ]; then
    echo "iOS SDK(${SDKPATH}) not found. Please make sure you have iOS SDK version=${SDKVERSION}"
    continue
  fi

  mkdir -p ${OUTPATH}/lib
  mkdir -p ${OUTPATH}/include

	./configure --disable-shared --enable-static --enable-pic \
	  --disable-programs --enable-debug=3 --disable-optimizations --disable-stripping --disable-asm --assert-level=2 \
	  --cc=${BUILD_TOOLS}/usr/bin/gcc ${EXTRA_CONFIG} \
    --prefix="${OUTPATH}" \
    --sysroot="${SDKPATH}" \
    --extra-ldflags="-arch ${ARCH} ${EXTRA_LDFLAGS} -L${SDKPATH}/usr/lib/system -isysroot ${SDKPATH} $LDFLAGS -L${OUTPATH}/lib" \
    --extra-cflags="$CFLAGS ${EXTRA_CFLAGS} -I${OUTPATH}/include -isysroot ${SDKPATH}" \
    --extra-cxxflags="$CPPFLAGS -I${OUTPATH}/include -isysroot ${SDKPATH}" > "${LOG}" 2>&1

  # Build the application and install it to build directory
  # for target sdk version and platform.
  make -j2 >> "${LOG}" 2>&1
	make install >> "${LOG}" 2>&1
	make clean >> "${LOG}" 2>&1

	OUT_LIB_PATHS+="${OUTPATH}/lib "
done

echo "Build universal library..."

OUTPUT_LIBS="libavcodec.a libavdevice.a libavfilter.a libavformat.a libavutil.a libswresample.a libswscale.a"
for OUTPUT_LIB in ${OUTPUT_LIBS};
do
    ALL_LIBS=""
    for OUT_LIB_PATH in ${OUT_LIB_PATHS};
    do
      ALL_LIBS+="${OUT_LIB_PATH}/${OUTPUT_LIB} "
    done

    lipo -create ${ALL_LIBS}-output "${LIBPATH}/${OUTPUT_LIB}"
done

mkdir -p ${INCLUDEPATH}
cp -R ${BUILDPATH}/ffmpeg-iPhoneSimulator${SDKVERSION}-i386.sdk/include/ ${INCLUDEPATH}/

echo "Building done."
echo "Cleaning up..."

rm -rf "${SRCPATH}/ffmpeg-${VERSION}"
echo "Done."



