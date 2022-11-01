#!/bin/bash

set -o errexit
set -x

COMMON_CFLAGS="-g -O2"
OVN_CFLAGS=""
EXTRA_OPTS="--with-pthread=`realpath ./ovs/PTHREADS-BUILT | xargs cygpath -m`"


function configure_ovs()
{
    pushd ovs
    ./boot.sh
    ./configure CC="./build-aux/cccl" LD="`which link`" \
    LIBS="-lws2_32 -lShlwapi -liphlpapi -lwbemuuid -lole32 -loleaut32" \
    CFLAGS="${COMMON_CFLAGS}" $* || { cat config.log; exit 1; }
    make -j || { cat config.log; exit 1; }
    popd
}

function configure_ovn()
{
    configure_ovs $*
    ./boot.sh
    ./configure CC="./build-aux/cccl" LD="`which link`" \
    LIBS="-lws2_32 -lShlwapi -liphlpapi -lwbemuuid -lole32 -loleaut32" \
    CFLAGS="${COMMON_CFLAGS} ${OVN_CFLAGS}" $* || { cat config.log; exit 1; }
}


OPTS="${EXTRA_OPTS} ${OPTS} $*"
configure_ovn $OPTS
make -j || { cat config.log; exit 1; }

if [ "$TESTSUITE" ]; then
    if ! make check RECHECK=yes; then
        # testsuite.log is necessary for debugging.
        cat ./tests/testsuite.log
        exit 1
    fi
fi

exit 0