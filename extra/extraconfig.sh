# This is a suggested extraconfig.sh for build-tarballs.sh

case "$ARCH" in
    arm*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-arch=armv4t"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-arch=armv4t"
        ;;

    powerpc* | ppc*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-long-double-64 --enable-secureplt"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-long-double-64 --enable-secureplt"
        ;;
esac

case "$ARCH" in
    *hf | \
    *-hf*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-float=hard"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-float=hard"
        ;;

    *sf | \
    *-sf*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-float=soft"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-float=soft"
        ;;
esac
