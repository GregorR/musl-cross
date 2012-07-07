# Definitions for build scripts
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

pushd "$MUSL_CC_BASE"
MUSL_CC_BASE="$PWD"
export MUSL_CC_BASE
popd

if [ ! -e config.sh ]
then
    echo 'Create a config.sh file.'
    exit 1
fi

# Versions of things (do this before config.sh so they can be config'd)
BINUTILS_VERSION=2.22
# later elfutils versions currently nonworking
ELFUTILS_VERSION=0.152
GCC_VERSION=4.7.1
GMP_VERSION=5.0.5
LINUX_HEADERS_VERSION=3.2.21
MPC_VERSION=0.9
MPFR_VERSION=3.1.1

# musl can optionally be checked out from GIT, in which case MUSL_VERSION must
# be set to a git tag and MUSL_GET set to yes in config.sh
MUSL_DEFAULT_VERSION=0.9.2
MUSL_GIT_VERSION=ec820f1262a5d6331ad0fe9b56a8a84365766fd1
MUSL_VERSION="$MUSL_DEFAULT_VERSION"
MUSL_GIT=no

. config.sh

PATH="$CC_PREFIX/bin:$PATH"
export PATH

case "$ARCH" in
    i*86) LINUX_ARCH=i386 ;;
    armeb) LINUX_ARCH=arm ;;
    *) LINUX_ARCH="$ARCH" ;;
esac
export LINUX_ARCH

die() {
    echo "$@"
    exit 1
}

fetch() {
    if [ ! -e "$MUSL_CC_BASE/tarballs/$2" ]
    then
        wget "$1""$2" -O "$MUSL_CC_BASE/tarballs/$2" || ( rm -f "$MUSL_CC_BASE/tarballs/$2" && return 1 )
    fi
    return 0
}

extract() {
    if [ ! -e "$2" ]
    then
        tar xf "$MUSL_CC_BASE/tarballs/$1" ||
            tar Jxf "$MUSL_CC_BASE/tarballs/$1" ||
            tar jxf "$MUSL_CC_BASE/tarballs/$1" ||
            tar zxf "$MUSL_CC_BASE/tarballs/$1"
    fi
}

fetchextract() {
    fetch "$1" "$2""$3"
    extract "$2""$3" "$2"
}

gitfetchextract() {
    if [ ! -e "$MUSL_CC_BASE/tarballs/$3".tar.gz ]
    then
        git archive --format=tar --remote="$1" "$2" | \
            gzip -c > "$MUSL_CC_BASE/tarballs/$3".tar.gz || die "Failed to fetch $3-$2"
    fi
    if [ ! -e "$3/extracted" ]
    then
        mkdir -p "$3"
        pushd "$3" || die "Failed to pushd $3"
        extract "$3".tar.gz extracted
        touch extracted
        popd
    fi
}

muslfetchextract() {
    if [ "$MUSL_GIT" = "yes" ]
    then
        gitfetchextract 'git://repo.or.cz/musl.git' $MUSL_VERSION musl-$MUSL_VERSION
    else
        fetchextract http://www.etalabs.net/musl/releases/ musl-$MUSL_VERSION .tar.gz
    fi
}

patch_source() {
    BD="$1"

    pushd "$BD" || die "Failed to pushd $BD"

    if [ -e "$MUSL_CC_BASE/patches/$BD"-musl.diff -a ! -e patched ]
    then
        patch -p1 < "$MUSL_CC_BASE/patches/$BD"-musl.diff || die "Failed to patch $BD"
        touch patched
    fi
    popd
}

build() {
    BP="$1"
    BD="$2"
    CF="./configure"
    BUILT="$PWD/$BD/built$BP"
    shift; shift

    if [ ! -e "$BUILT" ]
    then
        patch_source "$BD"

        pushd "$BD" || die "Failed to pushd $BD"

        if [ "$BP" ]
        then
            mkdir -p build"$BP"
            cd build"$BP" || die "Failed to cd to build dir for $BD $BP"
            CF="../configure"
        fi
        ( $CF --prefix="$PREFIX" "$@" &&
            make $MAKEFLAGS &&
            touch "$BUILT" ) ||
            die "Failed to build $BD"

        popd
    fi
}

buildmake() {
    BD="$1"
    BUILT="$PWD/$BD/built"
    shift

    if [ ! -e "$BUILT" ]
    then
        pushd "$BD" || die "Failed to pushd $BD"

        if [ -e "$MUSL_CC_BASE/$BD"-musl.diff -a ! -e patched ]
        then
            patch -p1 < "$MUSL_CC_BASE/$BD"-musl.diff || die "Failed to patch $BD"
            touch patched
        fi

        ( make "$@" $MAKEFLAGS &&
            touch "$BUILT" ) ||
            die "Failed to build $BD"

        popd
    fi
}

doinstall() {
    BP="$1"
    BD="$2"
    INSTALLED="$PWD/$BD/installed$BP"
    shift; shift

    if [ ! -e "$INSTALLED" ]
    then
        pushd "$BD" || die "Failed to pushd $BD"

        if [ "$BP" ]
        then
            cd build"$BP" || die "Failed to cd build$BP"
        fi

        ( make install "$@" &&
            touch "$INSTALLED" ) ||
            die "Failed to install $BP"

        popd
    fi
}

buildinstall() {
    build "$@"
    doinstall "$1" "$2"
}
