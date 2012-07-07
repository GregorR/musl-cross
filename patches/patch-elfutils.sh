#!/bin/bash -x
# Patch elfutils bit by bit

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

patch -Np1 -i "$1"
patch -Np1 -i "$MUSL_CC_BASE/patches/elfutils-add_ar.h.patch"
patch -Np1 -i "$MUSL_CC_BASE/patches/elfutils-no_error.patch"
patch -Np1 -i "$MUSL_CC_BASE/patches/elfutils-no_fts.patch"
patch -Np1 -i "$MUSL_CC_BASE/patches/elfutils-libelf_only.patch"

find . -name Makefile.in -exec sed -i 's/-Werror//g' '{}' \;
sed -i 's@strndupa@strndup@g' libdwfl/find-debuginfo.c
sed -i -e "/canonicalize_file_name/s@)@, NULL)@" -e 's@canonicalize_file_name@realpath@' \
  libdwfl/find-debuginfo.c libdwfl/dwfl_build_id_find_elf.c
sed -i 's@loff_t@off_t@g' libelf/libelf.h libdwfl/core-file.c
sed -i '/features.h/d' libelf/elf.h
sed -i "/ifndef LIB_SYSTEM_H/s@.*@#ifndef TEMP_FAILURE_RETRY\n#define TEMP_FAILURE_RETRY(x) x\n#define rawmemchr(s,c) memchr((s),(size_t)-1,(c))\n#endif\n\n&@" lib/system.h
sed -i "/libdwflP.h/s@.*@&\n#include <system.h>@" libdwfl/dwfl_module_getdwarf.c \
  libdwfl/dwfl_build_id_find_elf.c
sed -i "/libdwP.h/s@.*@&\n#include <system.h>@" libdw/dwarf_getpubnames.c
sed -i -e '/cdefs/d' -e "/define CONCAT/s@.*@#define CONCAT1(x,y) x##y\n#define CONCAT(x,y) CONCAT1(x,y)@" lib/fixedsizehash.h
sed -i \
  -e "s@__BEGIN_DECLS@#ifdef __cplusplus\nextern \"C\" {\n#endif@" \
      -e "s@__END_DECLS@#ifdef __cplusplus\n}\n#endif@" libelf/elf.h
sed -i 's@__mempcpy@mempcpy@g' libelf/elf_begin.c 
sed -i 's@^LIBS=$$@@' configure
