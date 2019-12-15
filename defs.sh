# Definitions for build scripts
# 
# Copyright (C) 2012-2014 Gregor Richards
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
BINUTILS_URL=http://ftpmirror.gnu.org/gnu/binutils/binutils-2.27.tar.bz2
#BINUTILS_URL=http://mirrors.kernel.org/sourceware/binutils/snapshots/binutils-2.24.90.tar.bz2
#last GPL2 release is 2.17, with backported  -Bsymbolic support
#BINUTILS_URL=http://landley.net/aboriginal/mirror/binutils-2.17.tar.bz2
GCC_VERSION=5.3.0
GDB_VERSION=7.9.1
GMP_VERSION=6.1.0
MPC_VERSION=1.0.3
MPFR_VERSION=3.1.4
LIBELF_VERSION=master
# use kernel headers from vanilla linux kernel - may be necessary for porting to a bleeding-edge arch
# LINUX_HEADERS_URL=http://www.kernel.org/pub/linux/kernel/v3.0/linux-3.12.6.tar.xz
# use patched sabotage-linux kernel-headers package (fixes userspace clashes of some kernel structs)
# from upstream repo https://github.com/sabotage-linux/kernel-headers
LINUX_HEADERS_URL=http://ftp.barfooze.de/pub/sabotage/tarballs/linux-headers-4.19.88.tar.xz

# musl can optionally be checked out from GIT, in which case MUSL_VERSION must
# be set to a git tag and MUSL_GIT set to yes in config.sh
MUSL_DEFAULT_VERSION=1.1.24
MUSL_GIT_VERSION=ea9525c8bcf6170df59364c4bcd616de1acf8703
MUSL_GIT_REPO='git://git.musl-libc.org/musl'
MUSL_VERSION="$MUSL_DEFAULT_VERSION"
MUSL_GIT=no

CONFIG_SUB_REV=3d5db9ebe860

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
    x32) LINUX_ARCH=x86_64 ;;
    arm*) LINUX_ARCH=arm ;;
    aarch64*) LINUX_ARCH=arm64 ;;
    mips*) LINUX_ARCH=mips ;;
    or1k*) LINUX_ARCH=openrisc ;;
    sh*) LINUX_ARCH=sh ;;

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
GCC_MULTILIB_CONFFLAGS="--disable-multilib --with-multilib-list="
if [ "$ARCH" = "x32" ]
then
    GCC_MULTILIB_CONFFLAGS="--with-multilib-list=mx32"
fi

die() {
    echo "$@"
    exit 1
}

https_url() {
	printf "%s\n" "$1" | sed 's/^http:/https:/'
}

fetch() {
    if [ ! -e "$MUSL_CC_BASE/tarballs/$2" ]
    then
        wget -O "$MUSL_CC_BASE/tarballs/$2.part" -c "$(https_url "$1""$2")" || \
        wget -O "$MUSL_CC_BASE/tarballs/$2.part" -c "$1""$2"
        test $? = 0 || { echo "error downloading $1$2" >&2 ; exit 1 ; }
        mv "$MUSL_CC_BASE/tarballs/$2.part" "$MUSL_CC_BASE/tarballs/$2"
        hashf="$MUSL_CC_BASE/hashes/$2.sha256"
        while ! test -e "$hashf" ; do
		echo "WARNING: no checksum file for $2 found, please report!">&2
		echo "provide $hashf , so this can continue">&2
		echo "(will detect presence in the next loop)">&2
		echo >&2
		echo "sleeping 10s...">&2
		sleep 10
        done
        (
            cd "$MUSL_CC_BASE/tarballs"
            sha256sum -c "$hashf"
        ) || { echo "checksum error!">&2 ; exit 1; }
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

stripfileext() {
	case "$1" in
		*.tar.*) printf "%s" "$1"| sed 's/\.tar\.[0-9a-z]*$//' ;;
		*) basename "$1" | sed 's/\..*//' ;;
	esac
}

fetchextract() {
    baseurl="$1"
    [ -z "$2" ] && baseurl=$(printf "%s" "$1" | sed 's/\(.*\/\).*/\1/')
    dir="$2"
    [ -z "$dir" ] && dir=$(stripfileext $(basename "$1"))
    fn="$2""$3"
    [ -z "$fn" ] && fn=$(basename "$1")

    fetch "$baseurl" "$fn"
    extract "$fn" "$dir"
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
        fetchextract http://ftpmirror.gnu.org/gnu/gmp/ gmp-$GMP_VERSION .tar.bz2
        mv gmp-$GMP_VERSION gcc-$GCC_VERSION/gmp
    fi

    if [ ! -e gcc-$GCC_VERSION/mpfr ]
    then
        fetchextract http://ftpmirror.gnu.org/gnu/mpfr/ mpfr-$MPFR_VERSION .tar.bz2
        mv mpfr-$MPFR_VERSION gcc-$GCC_VERSION/mpfr
    fi

    if [ ! -e gcc-$GCC_VERSION/mpc ]
    then
        fetchextract https://ftpmirror.gnu.org/gnu/mpc/ mpc-$MPC_VERSION .tar.gz
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

config_sub_guess() {
for i in config.sub config.guess ; do
    fn="$i;hb=${CONFIG_SUB_REV}"
    fetch 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=' "$fn"
    cp -f "$MUSL_CC_BASE/tarballs/$fn" "$1"/"$i" || exit 1
    chmod +x "$1"/"$i"
done
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
        config_sub_guess "$BD"

        SAVED_PREFIX="$PREFIX"

        (
        cd "$BD" || die "Failed to cd $BD"

        if [ "$BP" ]
        then
            mkdir -p build"$BP"
            cd build"$BP" || die "Failed to cd to build dir for $BD $BP"
            CF="../configure"
        fi
        test "$USE_DESTDIR" = 1 && PREFIX=
        (   $CF --prefix="$PREFIX" "$@" &&
            $MAKE $MAKEFLAGS &&
            touch "$BUILT" ) ||
            die "Failed to build $BD"

        )

        PREFIX="$SAVED_PREFIX"

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

        test "$USE_DESTDIR" = 1 && DD="DESTDIR=$PREFIX" || DD=
        ( $MAKE install "$@" $MAKEINSTALLFLAGS $DD &&
            touch "$INSTALLED" ) ||
            die "Failed to install $BP"

        )
    fi
}

buildinstall() {
    build "$@"
    doinstall "$1" "$2"
}
