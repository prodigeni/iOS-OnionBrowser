#!/bin/bash
#  Builds libevent for all three current iPhone targets: iPhoneSimulator-i386,
#  iPhoneOS-armv6, iPhoneOS-armv7.
#
#  Copyright 2012 Mike Tigas <mike@tig.as>
#
#  Based on work by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
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
#  Choose your libevent version and your currently-installed iOS SDK version:
#
VERSION="2.0.17-stable"
SDKVERSION="5.1"
#
#
###########################################################################
#
# Don't change anything under this line!
#
###########################################################################

ARCHS="i386 armv6 armv7"
DEVELOPER=`xcode-select -print-path`

cd "`dirname \"$0\"`"
REPOROOT=$(pwd)

# Where we'll end up storing things in the end
OUTPUTDIR="${REPOROOT}/dependencies"
mkdir -p ${OUTPUTDIR}/include
mkdir -p ${OUTPUTDIR}/lib


BUILDDIR="${REPOROOT}/build"

# where we will keep our sources and build from.
SRCDIR="${BUILDDIR}/src"
mkdir -p $SRCDIR
# where we will store intermediary builds
INTERDIR="${BUILDDIR}/built"
mkdir -p $INTERDIR

########################################

cd $SRCDIR

set -e
if [ ! -e "${SRCDIR}/libevent-${VERSION}.tar.gz" ]; then
	echo "Downloading libevent-${VERSION}.tar.gz"
    curl -LO https://github.com/downloads/libevent/libevent/libevent-${VERSION}.tar.gz
else
	echo "Using libevent-${VERSION}.tar.gz"
fi

tar zxf libevent-${VERSION}.tar.gz -C $SRCDIR
cd "${SRCDIR}/libevent-${VERSION}"

for ARCH in ${ARCHS}
do
	if [ "${ARCH}" == "i386" ];
	then
		PLATFORM="iPhoneSimulator"
        EXTRA_CONFIG=""
	else
		PLATFORM="iPhoneOS"
        EXTRA_CONFIG="--host=arm-apple-darwin10"
	fi

	mkdir -p "${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"

	./configure --disable-shared --enable-static --disable-debug-mode ${EXTRA_CONFIG} \
    --prefix="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" \
    CC="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/usr/bin/gcc -arch ${ARCH}" \
    LDFLAGS="$LDFLAGS -L${OUTPUTDIR}/lib" \
    CFLAGS="$CFLAGS -I${OUTPUTDIR}/include -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk" \
    CPPFLAGS="$CPPFLAGS -I${OUTPUTDIR}/include -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk"

    # Build the application and install it to the fake SDK intermediary dir
    # we have set up. Make sure to clean up afterward because we will re-use
    # this source tree to cross-compile other targets.
	make -j2
	make install
	make clean
done

########################################

echo "Build library..."

# These are the libs that comprise libevent. `libevent_openssl` and `libevent_pthreads`
# may not be compiled if those dependencies aren't available.
OUTPUT_LIBS="libevent.a libevent_core.a libevent_extra.a libevent_openssl.a libevent_pthreads.a"
for OUTPUT_LIB in ${OUTPUT_LIBS}
do
    # Combine the three architectures into a universal library.
    if [ -e "${INTERDIR}/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/${OUTPUT_LIB}" ]; then
        lipo -create "${INTERDIR}/iPhoneSimulator${SDKVERSION}-i386.sdk/lib/${OUTPUT_LIB}" \
        "${INTERDIR}/iPhoneOS${SDKVERSION}-armv6.sdk/lib/${OUTPUT_LIB}" \
        "${INTERDIR}/iPhoneOS${SDKVERSION}-armv7.sdk/lib/${OUTPUT_LIB}" \
        -output "${OUTPUTDIR}/lib/${OUTPUT_LIB}"
    else
        echo "$OUTPUT_LIB does not exist, skipping (are the dependencies installed?)"
    fi
done

cp -R ${INTERDIR}/iPhoneSimulator${SDKVERSION}-i386.sdk/include/* ${OUTPUTDIR}/include/

####################

echo "Building done."
echo "Cleaning up..."
rm -fr ${INTERDIR}
rm -fr "${SRCDIR}/libevent-${VERSION}"
echo "Done."