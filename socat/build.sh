#!/bin/bash

set -e
set -o pipefail
set -x

SOCAT_VERSION=cc71013
NCURSES_VERSION=6.0
READLINE_VERSION=7.0
OPENSSL_VERSION=1.1.0f

function build_ncurses() {
    cd /build

    # Download
    curl -LO http://invisible-mirror.net/archives/ncurses/ncurses-${NCURSES_VERSION}.tar.gz
    tar zxvf ncurses-${NCURSES_VERSION}.tar.gz
    cd ncurses-${NCURSES_VERSION}

    # Build
    CC='/usr/bin/gcc -static' CFLAGS='-fPIC' ./configure \
        --disable-shared \
        --enable-static
}

function build_readline() {
    cd /build

    # Download
    curl -LO ftp://ftp.cwru.edu/pub/bash/readline-${READLINE_VERSION}.tar.gz
    tar xzvf readline-${READLINE_VERSION}.tar.gz
    cd readline-${READLINE_VERSION}

    # Build
    CC='/usr/bin/gcc -static' CFLAGS='-fPIC' ./configure \
        --disable-shared \
        --enable-static
    make -j4

    # Note that socat looks for readline in <readline/readline.h>, so we need
    # that directory to exist.
    ln -s /build/readline-${READLINE_VERSION} /build/readline
}

function build_openssl() {
    cd /build

    # Download
    curl -LO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
    tar zxvf openssl-${OPENSSL_VERSION}.tar.gz
    cd openssl-${OPENSSL_VERSION}

    sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g" test/recipes/90-test_fuzz.t
    sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g" test/recipes/80-test_ssl_new.t
    sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g" test/recipes/40-test_rehash.t
    sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g" test/build.info
    sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g" test/run_tests.pl
    sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g" util/process_docs.pl
    sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g" Configure

    # Configure
    CC='/usr/bin/gcc -static' ./Configure no-shared no-async linux-x86_64

    # Build
    make -j4
    echo "** Finished building OpenSSL"
}

function build_socat() {
    cd /build

    # Download
    curl --output socat-${SOCAT_VERSION}.tar.gz -L https://github.com/runsisi/socat/tarball/${SOCAT_VERSION}
    tar xzvf socat-${SOCAT_VERSION}.tar.gz
    mv runsisi-socat-${SOCAT_VERSION} socat-${SOCAT_VERSION}

    cd socat-${SOCAT_VERSION}

    autoconf

    # Build
    # NOTE: `NETDB_INTERNAL` is non-POSIX, and thus not defined by MUSL.
    # We define it this way manually.
    CC='/usr/bin/gcc -static' \
    CFLAGS='-fPIC' \
    CPPFLAGS="-I/build -I/build/openssl-${OPENSSL_VERSION}/include -DNETDB_INTERNAL=-1" \
    LDFLAGS="-L/build/readline-${READLINE_VERSION} -L/build/ncurses-${NCURSES_VERSION}/lib -L/build/openssl-${OPENSSL_VERSION}" \
        ./configure

    make -j4
    strip socat
}

function doit() {
    build_ncurses
    build_readline
    build_openssl
    build_socat

    # Copy to output
    if [ -d /output ]
    then
        OUT_DIR=/output/`uname | tr 'A-Z' 'a-z'`/`uname -m`
        mkdir -p $OUT_DIR
	cp /build/socat-${SOCAT_VERSION}/socat $OUT_DIR/
        echo "** Finished **"
    else
        echo "** /output does not exist **"
    fi
}

doit

