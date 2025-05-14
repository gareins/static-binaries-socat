FROM alpine:edge

RUN apk --update add build-base bash automake git curl linux-headers autoconf musl-dev
RUN apk add yodl --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/

RUN mkdir /build
ADD . /build

# This builds the program and copies it to /output
CMD /build/build.sh
