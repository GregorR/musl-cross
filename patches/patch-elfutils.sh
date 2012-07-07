#!/bin/bash -x
# Patch elfutils bit by bit
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

# Fail on any command failing:
set -e

if [ ! "$1" ]
then
    echo 'Use: patch-elfutils.sh <path to elfutils-portability.patch>'
    exit 1
fi

patch -Np1 -i "$1" || exit 1
patch -Np1 -i "$MUSL_CC_BASE/patches/elfutils-add_ar.h.patch" || exit 1
patch -Np1 -i "$MUSL_CC_BASE/patches/elfutils-musl-compat.patch" || exit 1
sed -i 's@loff_t@off_t@g' libelf/libelf.h
sed -i "/stdint/s@.*@&\n#define TEMP_FAILURE_RETRY(x) x\n#define rawmemchr(s,c) memchr((s),(size_t)-1,(c))@" lib/system.h
sed -i '/cdefs/d' lib/fixedsizehash.h
sed -i -e \
      "s@__BEGIN_DECLS@#ifdef __cplusplus\nextern \"C\" {\n#endif@" \
      -e "s@__END_DECLS@#ifdef __cplusplus\n}\n#endif@" libelf/elf.h
sed -i 's@__mempcpy@mempcpy@g' libelf/elf_begin.c
find . -name Makefile.in -exec sed -i 's/-Werror//g' '{}' \;
find . -name Makefile.in -exec sed -i 's/if readelf -d $@ | fgrep -q TEXTREL; then exit 1; fi$//' "{}" \;
sed -i 's,am__EXEEXT_1 = libelf.so$(EXEEXT),,' libelf/Makefile.in
sed -i 's,install: install-am libelf.so,install: install-am\n\nfoobar:\n,' libelf/Makefile.in
