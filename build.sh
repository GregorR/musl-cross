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
fetchextract http://ftp.gnu.org/gnu/binutils/ binutils-$BINUTILS_VERSION .tar.bz2
buildinstall 1 binutils-$BINUTILS_VERSION --target=$TRIPLE $BINUTILS_CONFFLAGS

# gcc 1
fetchextract http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/ gcc-$GCC_VERSION .tar.bz2
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
    make defconfig ARCH=$LINUX_ARCH
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

# musl in CC prefix
PREFIX="/"
export PREFIX
muslfetchextract
CC="$TRIPLE-gcc" AR="$TRIPLE-ar" RANLIB="$TRIPLE-ranlib" \
    DESTDIR="$CC_PREFIX/$TRIPLE" buildinstall '' musl-$MUSL_VERSION \
    --enable-debug $MUSL_CONFFLAGS
unset PREFIX
PREFIX="$CC_PREFIX"

# gcc 2
buildinstall 2 gcc-$GCC_VERSION --target=$TRIPLE \
    --enable-languages=c,c++ --disable-multilib --disable-libmudflap \
    $GCC_CONFFLAGS

# un"fix" headers
rm -rf "$CC_PREFIX/lib/gcc/$TRIPLE"/*/include-fixed/
