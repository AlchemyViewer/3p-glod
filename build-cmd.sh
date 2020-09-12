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

# Early versions of GLOD seem awfully coy about version numbers. The most
# likely place we've found is the README file's CHANGELOG section -- and even
# that doesn't seem completely up-to-date!
# The first sed command prints everything from the word CHANGELOG through the
# end of the file.
# The second sed command matches lines that look like this:
# version (date)
# trusting that from the CHANGELOG line on, the only lines that look like that
# are in fact version headers.
# We only want the second sed command to print the FIRST version header -- so
# instead of just printing every such line, make it execute {spq}: substitute,
# print, quit.
# But for some reason that introduces a final '\r' character -- yes, even on
# Posix. Get rid of it.
GLOD_VERSION="$(sed -n '/^CHANGELOG/,$p' README | \
sed -n -E '/^([^[:space:]]+)[[:space:]]+\(.*\)/{
s//\1/
p
q
}' | \
tr -d '\r')"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${GLOD_VERSION}.${build}" > "${STAGING_DIR}/VERSION.txt"

case "$AUTOBUILD_PLATFORM" in
    windows*)
        build_sln "glodlib.sln" "Debug" "$AUTOBUILD_WIN_VSPLATFORM"
        build_sln "glodlib.sln" "Release" "$AUTOBUILD_WIN_VSPLATFORM"

        mkdir -p stage/lib/debug
        mkdir -p stage/lib/release

        cp "lib/debug/glod."{lib,dll,exp,pdb} "stage/lib/release/"
        cp "lib/release/glod."{lib,dll,exp,pdb} "stage/lib/release/"
    ;;
    darwin*)
        libdir="$top/stage/lib"
        mkdir -p "$libdir"/release
        export CFLAGS="-m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE"
        export CXXFLAGS="$CFLAGS"
        export LFLAGS="$CFLAGS"
        make -C src clean
        make -C src release
        install_name_tool -id "@executable_path/../Resources/libGLOD.dylib" "lib/libGLOD.dylib" 
        cp "lib/libGLOD.dylib" \
            "$libdir/release/libGLOD.dylib"
    ;;
    linux*)
        libdir="$top/stage/lib"
        mkdir -p "$libdir"/release
        export CFLAGS="-m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE"
        export CXXFLAGS="$CFLAGS"
        export LFLAGS="$CFLAGS"
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
