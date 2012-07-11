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
    MUSL_CC_BASE=`dirname "$0"`/..
fi

# Fail on any command failing, show commands:
set -ex

. "$MUSL_CC_BASE"/defs.sh

PREFIX="$CC_PREFIX"

fetchextract http://ftp.gnu.org/gnu/gdb/ gdb-$GDB_VERSION .tar.bz2
cp -f "$MUSL_CC_BASE/extra/config.sub" gdb-$GDB_VERSION/config.sub
buildinstall 1 gdb-$GDB_VERSION --target="$TRIPLE"
