# ARCH will be auto-detected as the host if not specified
#ARCH=i486
#ARCH=x86_64
#ARCH=powerpc
#ARCH=arm
#ARCH=microblaze
#ARCH=mips
#ARCH=mipsel
#ARCH=armv7hf
#ARCH=armv7

CC_BASE_PREFIX=/opt/cross
MAKEFLAGS=-j8

if [ "$ARCH" = armv7hf ] ; then
	# arm hardfloat v7
	TRIPLE=arm-linux-musleabihf
	GCC_BOOTSTRAP_CONFFLAGS="--with-arch=armv7-a --with-float=hard --with-fpu=vfpv3-d16"
	GCC_CONFFLAGS="--with-arch=armv7-a --with-float=hard --with-fpu=vfpv3-d16"
	ARCH=arm

elif [ "$ARCH" = armv7 ] ; then
	#arm softfp
	TRIPLE=arm-linux-musleabi
	GCC_BOOTSTRAP_CONFFLAGS="--with-arch=armv7-a --with-float=softfp"
	GCC_CONFFLAGS="--with-arch=armv7-a --with-float=softfp"
	ARCH=arm
fi

