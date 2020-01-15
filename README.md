About musl-cross
================

This is a small suite of scripts and patches to build a musl libc
cross-compiler. <strike>Prebuilt cross and native compilers are available at
http://musl.codu.org/</strike>

For the impatient, `./build.sh` should build a cross compiler to
`/opt/cross/<arch>-linux-musl`, no muss, no fuss. Otherwise, you can edit
config.sh to make cross-compilers to other architectures, and even copy
config.sh to another directory then run `build.sh` from there to avoid polluting
the source dir.

Project Scope
=============
Supported are GCC 4.0.3 until 5.3.0.
for newer GCCs check out the [musl-cross-make project][0].

Notes on building normal cross compilers
========================================

* For ARM, you must set the triple to `arm-linux-musleabi` (`eabi` is the important
  bit here)

* You can set versions of binutils, GCC or musl in `config.sh` with:

        BINUTILS_VERSION=<version>
        GCC_VERSION=<version>
        MUSL_VERSION=<version>

* You can set configure flags for each step:

        BINUTILS_CONFFLAGS=...
        GCC_BOOTSTRAP_CONFFLAGS=...
        MUSL_CONFFLAGS=...
        GCC_CONFFLAGS=...

* You can use a git checkout of musl with:

        MUSL_VERSION=<git tag or commit>
        MUSL_GIT=yes

* If you do not have the GMP, MPFR and/or MPC development libraries on your
  host, you can build them along with GCC with a config.sh line:

        GCC_BUILTIN_PREREQS=yes


Recommendations
===============

* If you would like to target a specific CPU revision, usually this is done by
  GCC configuration options like so:

        GCC_BOOTSTRAP_CONFFLAGS="--with-cpu=armv4t"
        GCC_CONFFLAGS="--with-cpu=armv4t"

  For ix86 however, it is more common to do this by the target name, e.g.
  `i486-linux-musl` instead of `i686-linux-musl`.


Upgrading cross compilers
=========================

It is possible to upgrade the musl version in a musl-cross cross compiler
without rebuilding the entire cross compiler prefix from scratch. Simply
download and extract the new version of musl, then configure it like so:

    ./configure --prefix="<prefix>/<triple>" CC="<triple>-gcc"

Where `<prefix>` is the prefix the cross compiler root was installed/extracted
to, and `<triple>` is the GNU-style target triple (e.g. `i486-linux-musl`).


Other scripts and helpers
=========================

* `config.sh` is an example configuration file. In many cases, it will do exactly
  what you want it to do with no modification, which is why it's simply named
  `config.sh` instead of, e.g., `config-sample.sh`

* `extra/build-gcc-deps.sh` will build the dependencies for GCC into the build
  prefix specified by `config.sh`, which are just
  often a nice thing to have. It is of course not necessary.

* `extra/build-tarballs.sh` builds convenient musl cross-compiler tarballs in a
  rather inconvenient way. It first builds a musl cross-compiler to the host
  platform (e.g. `i686`), then it uses that to build static cross-compilers to
  various platforms. As a result, building e.g. three cross-compiler tarballs
  involves eight compiler build phases (read: this is slow). However, the
  resultant tarballs are cross-compilers statically linked against musl, making
  them stable and portable.

* `config-static.sh` is an example configuration file for building a static
  cross-compiler. You can use this if, e.g., you already have a build of musl
  (and so have `musl-gcc`) but would like to make a complete, static
  cross-compiler based on that, or if you already have a musl cross-compiler
  (and so have `<arch>-linux-musl-gcc`) but would like to make a static
  cross-compiler itself compiled against musl.


Requirements
============

musl-cross depends on:

* shell and coreutils (busybox is fine)
* mercurial or git (for checkout only)
* wget (busybox is fine)
* patch
* gcc
* make
* awk (busybox is fine)

The following are GCC dependencies, which can be installed on the host system,
or installed automatically using `GCC_BUILTIN_PREREQS=yes`:

* gmp
* mpfr
* mpc

Building GMP additionally requires `m4`.


Compiler/Arch Compatibility Matrix
==================================
|       | i?86 | x86_64 | x32 | mips | powerpc | arm7 | armhf | mb  | sh4 | or1k|
|:------|:-----|:-------|:----|:-----|:--------|:-----|:------|:----|:----|:---:|
| 4.4.7 | yes  | yes    |     | yes  | yes     | yes  |       |     |     |     |
| 4.5.4 | yes  | yes    |     | yes  | yes     | yes  |       |     |     |     |
| 4.6.4 | yes  | yes    |     | yes  | yes     | yes  |       |     |     |     |
| 4.7.4 | yes  | yes    |     | yes  | yes     | yes  | yes   |     | yes |     |
| 4.8.5 | yes  | yes    | yes | yes  | yes     | yes  | yes   | yes | yes |     |
| 4.9.3 | yes  | yes    | yes | yes  | yes     | yes  | yes   | yes | yes |     |
| 5.3.0 | yes  | yes    | yes | yes  | yes     | yes  | yes   | yes | yes | *   |

`*` or1k requires integration of a patch (issue #61)

[0]:https://github.com/richfelker/musl-cross-make
