#!/usr/bin/env bash

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unreferenced env variables
set -u

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

# run build from root of checkout
cd "$(dirname "$0")"
top="$(pwd)"
STAGING_DIR="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$STAGING_DIR/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# Just hard code the version. It will never change for this dead decrepit sad library.
echo "1.0.3" > "${STAGING_DIR}/VERSION.txt"

case "$AUTOBUILD_PLATFORM" in
    windows*)
        build_sln "glodlib.sln" "Debug" "$AUTOBUILD_WIN_VSPLATFORM"
        build_sln "glodlib.sln" "Release" "$AUTOBUILD_WIN_VSPLATFORM"

        mkdir -p stage/lib/debug
        mkdir -p stage/lib/release

        cp "lib/debug/glod."{lib,dll,exp,pdb} "stage/lib/debug/"
        cp "lib/release/glod."{lib,dll,exp,pdb} "stage/lib/release/"
    ;;
    darwin*)
        # Setup osx sdk platform
        SDKNAME="macosx"
        export SDKROOT=$(xcodebuild -version -sdk ${SDKNAME} Path)
        export MACOSX_DEPLOYMENT_TARGET=10.13

        # Setup build flags
        ARCH_FLAGS="-arch x86_64"
        SDK_FLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDKROOT}"
        DEBUG_COMMON_FLAGS="$ARCH_FLAGS $SDK_FLAGS -Og -g -msse4.2 -fPIC -DPIC"
        RELEASE_COMMON_FLAGS="$ARCH_FLAGS $SDK_FLAGS -Ofast -ffast-math -g -msse4.2 -fPIC -DPIC -fstack-protector-strong"
        DEBUG_CFLAGS="$DEBUG_COMMON_FLAGS"
        RELEASE_CFLAGS="$RELEASE_COMMON_FLAGS"
        DEBUG_CXXFLAGS="$DEBUG_COMMON_FLAGS -std=c++17"
        RELEASE_CXXFLAGS="$RELEASE_COMMON_FLAGS -std=c++17"
        DEBUG_CPPFLAGS="-DPIC"
        RELEASE_CPPFLAGS="-DPIC"
        DEBUG_LDFLAGS="$ARCH_FLAGS $SDK_FLAGS -Wl,-headerpad_max_install_names"
        RELEASE_LDFLAGS="$ARCH_FLAGS $SDK_FLAGS -Wl,-headerpad_max_install_names"

        libdir="$top/stage/lib"
        mkdir -p "$libdir"/debug
        mkdir -p "$libdir"/release

        export CFLAGS="$DEBUG_CFLAGS"
        export CXXFLAGS="$DEBUG_CXXFLAGS"
        export LDFLAGS="$DEBUG_LDFLAGS"
        make -C src clean
        make -C src debug
        cp "lib/libGLOD.dylib" \
            "$libdir/debug/libGLOD.dylib"

        pushd "${libdir}/debug"
            fix_dylib_id "libGLOD.dylib"
            dsymutil libGLOD.dylib
            strip -x -S libGLOD.dylib
        popd

        export CFLAGS="$RELEASE_CFLAGS"
        export CXXFLAGS="$RELEASE_CXXFLAGS"
        export LDFLAGS="$RELEASE_LDFLAGS"
        make -C src clean
        make -C src release
        cp "lib/libGLOD.dylib" \
            "$libdir/release/libGLOD.dylib"

        pushd "${libdir}/release"
            fix_dylib_id "libGLOD.dylib"
            dsymutil libGLOD.dylib
            strip -x -S libGLOD.dylib
        popd
    ;;
    linux*)
        # Default target per --address-size
        opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE}"

        # Setup build flags
		DEBUG_COMMON_FLAGS="$opts -Og -g -fPIC -DPIC"
		RELEASE_COMMON_FLAGS="$opts -O3 -g -fPIC -DPIC -fstack-protector-strong -D_FORTIFY_SOURCE=2"
		DEBUG_CFLAGS="$DEBUG_COMMON_FLAGS"
		RELEASE_CFLAGS="$RELEASE_COMMON_FLAGS"
        DEBUG_CXXFLAGS="$DEBUG_COMMON_FLAGS -std=c++17"
		RELEASE_CXXFLAGS="$RELEASE_COMMON_FLAGS -std=c++17"
        DEBUG_CPPFLAGS="-DPIC"
		RELEASE_CPPFLAGS="-DPIC"

        libdir="$top/stage/lib"
        mkdir -p "$libdir"/debug
        export CFLAGS="$DEBUG_CFLAGS"
        export CXXFLAGS="$DEBUG_CXXFLAGS"
        export LFLAGS="$DEBUG_CFLAGS"
        make -C src clean
        make -C src debug
        cp "lib/libGLOD.so" \
            "$libdir/debug/libGLOD.so"

        mkdir -p "$libdir"/release
        export CFLAGS="$RELEASE_CFLAGS"
        export CXXFLAGS="$RELEASE_CXXFLAGS"
        export LFLAGS="$RELEASE_CFLAGS"
        make -C src clean
        make -C src release
        cp "lib/libGLOD.so" \
            "$libdir/release/libGLOD.so"
    ;;
esac
mkdir -p "stage/include/glod"
cp "include/glod.h" "stage/include/glod/glod.h"
mkdir -p stage/LICENSES
cp LICENSE stage/LICENSES/GLOD.txt
