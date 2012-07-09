# This is a suggested extraconfig.sh for build-tarballs.sh

case ARCH in
    arm*)
        GCC_BOOTSTRAP_CONFFLAGS="$GCC_BOOTSTRAP_CONFFLAGS --with-cpu=armv4t"
        GCC_CONFFLAGS="$GCC_CONFFLAGS --with-cpu=armv4t"
        ;;
esac
