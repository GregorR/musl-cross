#!/bin/sh
# Build a cross-compiler
# 
# Copyright (C) 2012 Gregor Richards
# 
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

if [ ! "$MUSL_CC_BASE" ]
then
    MUSL_CC_BASE=`dirname "$0"`
fi

# Fail on any command failing, show commands:
set -ex

BINUTILS_CONFFLAGS=
GCC_BOOTSTRAP_CONFFLAGS=
MUSL_CONFFLAGS=
GCC_CONFFLAGS=
WITH_SYSROOT=no
. "$MUSL_CC_BASE"/defs.sh

# Switch to the CC prefix for all of this
PREFIX="$CC_PREFIX"
USE_DESTDIR=0

# make the sysroot usr directory
if [ ! -e "$PREFIX"/"$TRIPLE"/usr ]
then
    mkdir -p "$PREFIX"/"$TRIPLE"
    ln -sf . "$PREFIX"/"$TRIPLE"/usr
fi
if [ "$WITH_SYSROOT" = "yes" ]
then
    SYSROOT_FLAGS="--with-sysroot=""$PREFIX"/"$TRIPLE"
fi

# binutils
fetchextract "$BINUTILS_URL"
BINUTILS_DIR=$(stripfileext $(basename $BINUTILS_URL))
if printf "%s" "$BINUTILS_URL" | grep "2\.[2-9][0-9]" >/dev/null 2>&1 ; then
    BINUTILS_CONFFLAGS="$BINUTILS_CONFFLAGS --enable-deterministic-archives"
fi

sed -i -e 's,MAKEINFO="$MISSING makeinfo",MAKEINFO=true,g' \
    $BINUTILS_DIR/configure
buildinstall 1 $BINUTILS_DIR --target=$TRIPLE --disable-werror $SYSROOT_FLAGS \
    $BINUTILS_CONFFLAGS

# gcc 1
if [ -z $GCC_URL ];
then
    fetchextract http://ftpmirror.gnu.org/gnu/gcc/gcc-$GCC_VERSION/ gcc-$GCC_VERSION .tar.bz2
else
    fetchextract "$GCC_URL"
    if [ -e $GCC_EXTRACT_DIR ]; then
	mv $GCC_EXTRACT_DIR gcc-$GCC_VERSION
    fi
fi

[ "$GCC_BUILTIN_PREREQS" = "yes" ] && gccprereqs

# gcc 1 is only used to bootstrap musl and gcc 2, so it is pointless to
# optimize it.
# If GCC_STAGE1_NOOPT is set, we build it without optimization and debug info,
# which reduces overall build time considerably.
SAVE_CFLAGS="$CFLAGS"
SAVE_CXXFLAGS="$CXXFLAGS"
if [ -z "$GCC_STAGE1_NOOPT" ]; then GCC_STAGE1_NOOPT=0; fi
if [ "$GCC_STAGE1_NOOPT" -ne 0 ]
then
    export CFLAGS="-O0 -g0"
    export CXXFLAGS="-O0 -g0"
fi

buildinstall 1 gcc-$GCC_VERSION --target=$TRIPLE $SYSROOT_FLAGS \
    --enable-languages=c --with-newlib --disable-libssp --disable-nls \
    --disable-libquadmath --disable-threads --disable-decimal-float \
    --disable-shared --disable-libmudflap --disable-libgomp --disable-libatomic \
    $GCC_MULTILIB_CONFFLAGS \
    $GCC_BOOTSTRAP_CONFFLAGS

export CFLAGS="$SAVE_CFLAGS"
export CXXFLAGS="$SAVE_CXXFLAGS"

# linux headers
fetchextract $LINUX_HEADERS_URL
LINUX_HEADERS_DIR=$(stripfileext $(basename $LINUX_HEADERS_URL))

if [ ! -e $LINUX_HEADERS_DIR/configured ]
then
    (
    cd $LINUX_HEADERS_DIR
    make $LINUX_DEFCONFIG ARCH=$LINUX_ARCH
    touch configured
    )
fi
if [ ! -e $LINUX_HEADERS_DIR/installedheaders ]
then
    (
    cd $LINUX_HEADERS_DIR
    make headers_install ARCH=$LINUX_ARCH INSTALL_HDR_PATH="$CC_PREFIX/$TRIPLE"
    touch installedheaders
    )
fi

if [ "$MUSL_VERSION" != "no" ]
then
    # musl in CC prefix
    PREFIX="$CC_PREFIX/$TRIPLE"
    muslfetchextract
    # We set both CROSS_COMPILE and CC because CC in the environment overrides
    # and CROSS_COMPILE setting
    USE_DESTDIR=1
    buildinstall '' musl-$MUSL_VERSION \
        --enable-debug --enable-optimize CROSS_COMPILE="$TRIPLE-" CC="$TRIPLE-gcc" $MUSL_CONFFLAGS
    unset PREFIX
    PREFIX="$CC_PREFIX"
    USE_DESTDIR=0

    # if it didn't build libc.so, disable dynamic linking
    if [ ! -e "$CC_PREFIX/$TRIPLE/lib/libc.so" ]
    then
        GCC_CONFFLAGS="--disable-shared $GCC_CONFFLAGS"
    fi

    # gcc 2
    buildinstall 2 gcc-$GCC_VERSION --target=$TRIPLE $SYSROOT_FLAGS \
        --enable-languages=$LANGUAGES --disable-libmudflap \
        --disable-libsanitizer --disable-nls --disable-libssp \
        $GCC_MULTILIB_CONFFLAGS \
        $GCC_CONFFLAGS
fi

# un"fix" headers
rm -rf "$CC_PREFIX/lib/gcc/$TRIPLE"/*/include-fixed/ "$CC_PREFIX/lib/gcc/$TRIPLE"/*/include/stddef.h

# make backwards-named compilers for easier cross-compiling
if test "$MAKE_BACKWARDS_LINKS" = yes ; then
(
    cd "$CC_PREFIX/bin"
    for tool in $TRIPLE-*
    do
        btool=`echo "$tool" | sed -E 's/linux-(musl.*)-/\1-linux-/'`
        if [ "$tool" != "$btool" -a ! -e "$btool" ] ; then
            ln -s $tool $btool
        fi
    done
)
fi

if test "$REMOVE_JUNK" = yes ; then
(
    cd "$CC_PREFIX"
    rm -rf info man share
    find . -name libiberty.a -delete
)
fi

exit 0
