ARCH=`uname -m`
TRIPLE=$ARCH-linux-musl
CC_PREFIX=/opt/cross/$TRIPLE
MAKEFLAGS=-j8
