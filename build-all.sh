#!/bin/sh
for a in i486 x86_64 mips mipsel powerpc microblaze armv7 armv7hf ; do
	export ARCH=$a
	./clean.sh
	if ! ./build.sh ; then
		echo "error: $a failed, stopping"
		exit 1
	fi
done
