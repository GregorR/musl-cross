# This is a suggested extraconfig.sh for build-tarballs.sh

case "$ARCH" in
    arm*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-arch=armv4t"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-arch=armv4t"
        ;;

    powerpc* | ppc*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-long-double-64"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-long-double-64"
        ;;
esac

case "$ARCH" in
    *-sf*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-float=soft"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-float=soft"
        ;;
esac
