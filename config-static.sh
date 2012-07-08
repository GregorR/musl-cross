ARCH=`uname -m`
TRIPLE=$ARCH-linux-musl
CC_PREFIX=/opt/cross/$TRIPLE
MAKEFLAGS=-j8

GCC_BOOTSTRAP_CONFFLAGS=--disable-lto-plugin
GCC_CONFFLAGS=--disable-lto-plugin
MUSL_CC_PREFIX="musl-"
# Disable these three lines when running build-gcc-deps.sh
CC="'"${MUSL_CC_PREFIX}gcc"' -Wl,-Bstatic -static-libgcc"
CXX="'"${MUSL_CC_PREFIX}g++"' -Wl,-Bstatic -static-libgcc"
export CC CXX
