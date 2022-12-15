# syntax=docker/dockerfile:1.4

#FROM --platform=$BUILDPLATFORM alpine AS builder-base
#SHELL ["/bin/sh", "-xeo", "pipefail", "-c"]
#RUN <<eof
#  apk add gcc automake autoconf libtool gettext pkgconf git make musl-dev \
#    python3 libcap-dev libseccomp-dev yajl-dev argp-standalone go-md2man \
#    systemd-devel \
#    tree
#eof

FROM --platform=$BUILDPLATFORM ubuntu AS lib-builder-base
SHELL ["/bin/bash", "-xeo", "pipefail", "-c"]
ENV DEBIAN_FRONTEND noninteractive
RUN \
  --mount=type=cache,sharing=locked,target=/var/cache/apt \
  --mount=type=cache,sharing=locked,target=/var/lib/apt <<eof
  apt update
  apt install -y --no-install-recommends \
    make git gcc build-essential pkgconf libtool libsystemd-dev libcap-dev \
    libseccomp-dev libyajl-dev go-md2man libtool autoconf python3 automake \
    libprotobuf-c-dev ca-certificates
eof

FROM lib-builder-base AS lib-builder
WORKDIR /src
COPY . .
RUN <<eof
  ./autogen.sh
  ./configure
  make -j$(nproc)
eof

FROM --platform=$BUILDPLATFORM nixos/nix:2.3.12 AS builder-base
RUN <<eof
  apk add tree file
eof

#RUN --mount=from=lib-builder,src=/src,target=/src,rw <<eof
FROM builder-base AS builder
WORKDIR /src
COPY . .
RUN <<eof
  set -ex
  nix --print-build-logs build --file nix/ 
  cp ./result/bin/crun /crun
  file /crun
eof

#FROM builder-base AS no-systemd-builder
#RUN --mount=from=lib-builder,src=/src,target=/src <<eof
#  nix --print-build-logs --option cores $(nproc) --option max-jobs $(nproc) build --file nix/ --arg enableSystemd false
#eof

FROM scratch AS releaser
COPY --link --from=builder /crun /crun-linux-amd64
#COPY --link --from=no-systemd-builder /src/result/bin/crun /crun-linux-amd64-disable-systemd
