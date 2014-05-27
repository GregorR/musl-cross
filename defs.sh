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

ORIGPWD="$PWD"
cd "$MUSL_CC_BASE"
MUSL_CC_BASE="$PWD"
export MUSL_CC_BASE
cd "$ORIGPWD"
unset ORIGPWD

if [ ! -e config.sh ]
then
    echo 'Create a config.sh file.'
    exit 1
fi

# Versions of things (do this before config.sh so they can be config'd)
BINUTILS_VERSION=2.24
GCC_VERSION=4.8.3
GDB_VERSION=7.4.1
GMP_VERSION=4.3.2
LIBELF_VERSION=71bf774909fd654d8167a475333fa8f37fbbcb5d
LINUX_HEADERS_VERSION=3.12.6
MPC_VERSION=0.8.1
MPFR_VERSION=2.4.2

# musl can optionally be checked out from GIT, in which case MUSL_VERSION must
# be set to a git tag and MUSL_GIT set to yes in config.sh
MUSL_DEFAULT_VERSION=1.1.1
MUSL_GIT_VERSION=0b4e0732db5e6ed0cca78d787cbd764248fcbaac
MUSL_GIT_REPO='git://repo.or.cz/musl.git'
MUSL_VERSION="$MUSL_DEFAULT_VERSION"
MUSL_GIT=no

# You can choose languages
LANG_CXX=yes
LANG_OBJC=no
LANG_FORTRAN=no

. ./config.sh

# Auto-deteect an ARCH if not specified
if [ -z "$ARCH" ]
then
    for MAYBECC in cc gcc clang
    do
        $MAYBECC -dumpmachine > /dev/null 2> /dev/null &&
        ARCH=`$MAYBECC -dumpmachine | sed 's/-.*//'` &&
        break
    done
    unset MAYBECC

    [ -z "$ARCH" ] && ARCH=`uname -m`
fi

# Auto-detect a TRIPLE if not specified
if [ -z "$TRIPLE" ]
then
    case "$ARCH" in
        armhf)
            ARCH="arm"
            TRIPLE="$ARCH-linux-musleabihf"
            ;;

        arm*)
            TRIPLE="$ARCH-linux-musleabi"
            ;;

	aarch64)
	    TRIPLE="aarch64-linux-musl"
	    ;;

        x32)
            TRIPLE="x86_64-x32-linux-musl"
            ;;

        *)
            TRIPLE="$ARCH-linux-musl"
            ;;
    esac
fi

# Choose our languages
LANGUAGES=c
[ "$LANG_CXX" = "yes" ] && LANGUAGES="$LANGUAGES,c++"
[ "$LANG_OBJC" = "yes" ] && LANGUAGES="$LANGUAGES,objc"
[ "$LANG_CXX" = "yes" -a "$LANG_OBJC" = "yes" ] && LANGUAGES="$LANGUAGES,obj-c++"
[ "$LANG_FORTRAN" = "yes" ] && LANGUAGES="$LANGUAGES,fortran"

# Use gmake if it exists
if [ -z "$MAKE" ]
then
    MAKE=make
    gmake --help > /dev/null 2>&1 && MAKE=gmake
fi

# Generate CC_PREFIX from CC_BASE_PREFIX and TRIPLE if not specified
[ -n "$CC_BASE_PREFIX" -a -z "$CC_PREFIX" ] && CC_PREFIX="$CC_BASE_PREFIX/$TRIPLE"
[ -z "$CC_PREFIX" ] && die 'Failed to determine a CC_PREFIX.'

PATH="$CC_PREFIX/bin:$PATH"
export PATH

# Get our Linux arch and defconfig
LINUX_ARCH=`echo "$ARCH" | sed 's/-.*//'`
LINUX_DEFCONFIG=defconfig
case "$LINUX_ARCH" in
    i*86) LINUX_ARCH=i386 ;;
    arm*) LINUX_ARCH=arm ;;
    aarch64*) LINUX_ARCH=arm64 ;;
    mips*) LINUX_ARCH=mips ;;
    x32) LINUX_ARCH=x86_64 ;;

    powerpc* | ppc*)
        LINUX_ARCH=powerpc
        LINUX_DEFCONFIG=g5_defconfig
        ;;

    microblaze)
        LINUX_DEFCONFIG=mmu_defconfig
        ;;
esac
export LINUX_ARCH

# Get the target-specific multilib option, if applicable
GCC_MULTILIB_CONFFLAGS="--disable-multilib"
if [ "$ARCH" = "x32" ]
then
    GCC_MULTILIB_CONFFLAGS="--with-multilib-list=mx32"
fi

die() {
    echo "$@"
    exit 1
}

fetch() {
    if [ ! -e "$MUSL_CC_BASE/tarballs/$2" ]
    then
        wget -c "$1""$2" -O "$MUSL_CC_BASE/tarballs/$2.part"
        mv "$MUSL_CC_BASE/tarballs/$2.part" "$MUSL_CC_BASE/tarballs/$2"
    fi
    return 0
}

extract() {
    if [ ! -e "$2/extracted" ]
    then
        tar xf "$MUSL_CC_BASE/tarballs/$1" ||
            tar Jxf "$MUSL_CC_BASE/tarballs/$1" ||
            tar jxf "$MUSL_CC_BASE/tarballs/$1" ||
            tar zxf "$MUSL_CC_BASE/tarballs/$1"
        mkdir -p "$2"
        touch "$2/extracted"
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
        (
        cd "$3" || die "Failed to cd $3"
        extract "$3".tar.gz extracted
        touch extracted
        )
    fi
}

muslfetchextract() {
    if [ "$MUSL_GIT" = "yes" ]
    then
        gitfetchextract "$MUSL_GIT_REPO" $MUSL_VERSION musl-$MUSL_VERSION
    else
        fetchextract http://www.musl-libc.org/releases/ musl-$MUSL_VERSION .tar.gz
    fi
}

gccprereqs() {
    if [ ! -e gcc-$GCC_VERSION/gmp ]
    then
        fetchextract ftp://ftp.gmplib.org/pub/gmp-$GMP_VERSION/ gmp-$GMP_VERSION .tar.bz2
        mv gmp-$GMP_VERSION gcc-$GCC_VERSION/gmp
    fi

    if [ ! -e gcc-$GCC_VERSION/mpfr ]
    then
        fetchextract http://ftp.gnu.org/gnu/mpfr/ mpfr-$MPFR_VERSION .tar.bz2
        mv mpfr-$MPFR_VERSION gcc-$GCC_VERSION/mpfr
    fi

    if [ ! -e gcc-$GCC_VERSION/mpc ]
    then
        fetchextract http://www.multiprecision.org/mpc/download/ mpc-$MPC_VERSION .tar.gz
        mv mpc-$MPC_VERSION gcc-$GCC_VERSION/mpc
    fi
}

patch_source() {
    BD="$1"

    (
    cd "$BD" || die "Failed to cd $BD"

    if [ ! -e patched ]
    then
        for f in "$MUSL_CC_BASE/patches/$BD"-*.diff ; do
            if [ -e "$f" ] ; then patch -p1 < "$f" || die "Failed to apply patch $f to $BD" ; fi
        done
        touch patched
    fi
    )
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

        (
        cd "$BD" || die "Failed to cd $BD"

        if [ "$BP" ]
        then
            mkdir -p build"$BP"
            cd build"$BP" || die "Failed to cd to build dir for $BD $BP"
            CF="../configure"
        fi
        ( $CF --prefix="$PREFIX" "$@" &&
            $MAKE $MAKEFLAGS &&
            touch "$BUILT" ) ||
            die "Failed to build $BD"

        )
    fi
}

buildmake() {
    BD="$1"
    BUILT="$PWD/$BD/built"
    shift

    if [ ! -e "$BUILT" ]
    then
        patch_source "$BD"

        (
        cd "$BD" || die "Failed to cd $BD"

        ( $MAKE "$@" $MAKEFLAGS &&
            touch "$BUILT" ) ||
            die "Failed to build $BD"

        )
    fi
}

doinstall() {
    BP="$1"
    BD="$2"
    INSTALLED="$PWD/$BD/installed$BP"
    shift; shift

    if [ ! -e "$INSTALLED" ]
    then
        (
        cd "$BD" || die "Failed to cd $BD"

        if [ "$BP" ]
        then
            cd build"$BP" || die "Failed to cd build$BP"
        fi

        ( $MAKE install "$@" $MAKEINSTALLFLAGS &&
            touch "$INSTALLED" ) ||
            die "Failed to install $BP"

        )
    fi
}

buildinstall() {
    build "$@"
    doinstall "$1" "$2"
}
