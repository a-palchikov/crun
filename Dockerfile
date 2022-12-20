# syntax=docker/dockerfile:1.4

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
eof

FROM --platform=$BUILDPLATFORM nixos/nix:2.11.1 AS builder-base
RUN \
  --mount=type=cache,sharing=locked,target=/var/cache/apt \
  --mount=type=cache,sharing=locked,target=/var/lib/apt <<eof
  nix-channel --add https://nixos.org/channels/nixpkgs-unstable
  nix-channel --update
  nix-env -i tree file
eof

FROM builder-base AS builder
WORKDIR /src
RUN \
  --mount=from=lib-builder,src=/src,target=/src,rw <<eof
  set -ex
  nix-build --cores 0 --max-jobs auto --arg enableSystemd true nix/
  cp ./result/bin/crun /crun
  file /crun
eof

FROM builder-base AS builder-releaser

FROM scratch AS releaser
COPY --link --from=builder /crun /crun-linux-amd64
