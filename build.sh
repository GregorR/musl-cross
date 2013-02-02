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
. "$MUSL_CC_BASE"/defs.sh

# Switch to the CC prefix for all of this
PREFIX="$CC_PREFIX"

# binutils
if [ "$BINUTILS_VERSION" = "2.17" ]
then
    # The version of the latest GPLv2 binutils on gnu.org is a lie...
    fetchextract http://landley.net/aboriginal/mirror/ binutils-$BINUTILS_VERSION .tar.bz2
else
    fetchextract http://ftp.gnu.org/gnu/binutils/ binutils-$BINUTILS_VERSION .tar.bz2
fi
buildinstall 1 binutils-$BINUTILS_VERSION --target=$TRIPLE --disable-werror \
    $BINUTILS_CONFFLAGS

# gcc 1
fetchextract http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/ gcc-$GCC_VERSION .tar.bz2
[ "$GCC_BUILTIN_PREREQS" = "yes" ] && gccprereqs
buildinstall 1 gcc-$GCC_VERSION --target=$TRIPLE \
    --enable-languages=c --with-newlib --disable-multilib --disable-libssp \
    --disable-libquadmath --disable-threads --disable-decimal-float \
    --disable-shared --disable-libmudflap --disable-libgomp \
    $GCC_BOOTSTRAP_CONFFLAGS

# linux headers
fetchextract http://www.kernel.org/pub/linux/kernel/v3.0/ linux-$LINUX_HEADERS_VERSION .tar.bz2
if [ ! -e linux-$LINUX_HEADERS_VERSION/configured ]
then
    (
    cd linux-$LINUX_HEADERS_VERSION
    make $LINUX_DEFCONFIG ARCH=$LINUX_ARCH
    touch configured
    )
fi
if [ ! -e linux-$LINUX_HEADERS_VERSION/installedheaders ]
then
    (
    cd linux-$LINUX_HEADERS_VERSION
    make headers_install ARCH=$LINUX_ARCH INSTALL_HDR_PATH="$CC_PREFIX/$TRIPLE"
    touch installedheaders
    )
fi

if [ "$MUSL_VERSION" != "no" ]
then
    # musl in CC prefix
    PREFIX="$CC_PREFIX/$TRIPLE"
    muslfetchextract
    buildinstall '' musl-$MUSL_VERSION \
        --enable-debug CC="$TRIPLE-gcc" $MUSL_CONFFLAGS
    unset PREFIX
    PREFIX="$CC_PREFIX"

    # if it didn't build libc.so, disable dynamic linking
    if [ ! -e "$CC_PREFIX/$TRIPLE/lib/libc.so" ]
    then
        GCC_CONFFLAGS="--disable-shared $GCC_CONFFLAGS"
    fi

    # gcc 2
    buildinstall 2 gcc-$GCC_VERSION --target=$TRIPLE \
        --enable-languages=$LANGUAGES --disable-multilib --disable-libmudflap \
        $GCC_CONFFLAGS
fi

# un"fix" headers
rm -rf "$CC_PREFIX/lib/gcc/$TRIPLE"/*/include-fixed/ "$CC_PREFIX/lib/gcc/$TRIPLE"/*/include/stddef.h

# make backwards-named compilers for easier cross-compiling
(
    cd "$CC_PREFIX/bin"
    for tool in $TRIPLE-*
    do
        btool=`echo "$tool" | sed 's/-linux-musl/-musl-linux/'`
        [ "$tool" != "$btool" -a ! -e "$btool" ] && ln -s $tool $btool
    done
)
