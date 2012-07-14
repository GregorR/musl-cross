# This is a suggested extraconfig.sh for build-tarballs.sh

case "$ARCH" in
    arm*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-arch=armv5t"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-arch=armv5t"
        ;;

    mips*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-arch=mips2"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-arch=mips2"
        ;;
esac

case "$ARCH" in
    *-sf*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-float=soft"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-float=soft"
        ;;
esac
