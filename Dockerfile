# this dockerfile can be translated to `docker/dockerfile:1-experimental` syntax for enabling cache mounts:
# $ ./hack/translate-dockerfile-runopt-directive.sh < Dockerfile | DOCKER_BUILDKIT=1 docker build -f -  .

ARG BASE=ubuntu:20.04

# Sep 26, 2020
ARG ANBOX_COMMIT=c898810050df67adccd64a84b2d763250a42e722

# ARG ANDROID_IMAGE=https://build.anbox.io/android-images/2018/07/19/android_amd64.img
# Mirror
ARG ANDROID_IMAGE=https://github.com/AkihiroSuda/anbox-android-images-mirror/releases/download/snapshot-20180719/android_amd64.img
# https://build.anbox.io/android-images/2018/07/19/android_amd64.img.sha256sum
ARG ANDROID_IMAGE_SHA256=6b04cd33d157814deaf92dccf8a23da4dc00b05ca6ce982a03830381896a8cca

FROM ${BASE} AS anbox
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
  build-essential \
  ca-certificates \
  cmake \
  cmake-data \
  cmake-extras \
  debhelper \
  dbus \
  git \
  google-mock \
  libboost-dev \
  libboost-filesystem-dev \
  libboost-log-dev \
  libboost-iostreams-dev \
  libboost-program-options-dev \
  libboost-system-dev \
  libboost-test-dev \
  libboost-thread-dev \
  libcap-dev \
  libegl1-mesa-dev \
  libexpat1-dev \
  libgles2-mesa-dev \
  libglm-dev \
  libgtest-dev \
  liblxc1 \
  libproperties-cpp-dev \
  libprotobuf-dev \
  libsdl2-dev \
  libsdl2-image-dev \
  libsystemd-dev \
  lxc-dev \
  pkg-config \
  protobuf-compiler \
  python2 \
  cmake-extras \
  google-mock \
  libgmock-dev python2
RUN git clone --recursive https://github.com/anbox/anbox /anbox
WORKDIR /anbox
ARG ANBOX_COMMIT
RUN git pull && git checkout -f ${ANBOX_COMMIT} && git submodule update --recursive
COPY ./src/patches/anbox /patches
# `git am` requires user info to be set
RUN git config user.email "nobody@example.com" && \
  git config user.name "AinD Build Script" && \
  if [ -f /patches/*.patch ]; then git am /patches/*.patch && git show --summary; fi
# runopt = --mount=type=cache,id=aind-anbox,target=/build
RUN mkdir -p /anbox/build && \
    cd /anbox/build && \
    cmake .. && \
    make -j4
RUN cp -f /anbox/build/src/anbox /anbox-binary

FROM ${BASE} AS swiftshader
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -qq -y \
  ca-certificates bash tar \
  git build-essential cmake python3 libx11-dev libxext-dev

RUN git clone https://swiftshader.googlesource.com/SwiftShader /swiftshader && \
    cd /swiftshader && \
    git checkout -f b6e8c3f0f4830887d69ba765a922ac3c40e81dd9
RUN mkdir -p /swiftshader/build && \
    cd /swiftshader/build && \
    cmake .. && \
    make -j4

FROM ${BASE} AS android-img
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
  ca-certificates curl
ARG ANDROID_IMAGE
ARG ANDROID_IMAGE_SHA256
RUN curl --retry 10 -L -o /android.img $ANDROID_IMAGE \
    && echo $ANDROID_IMAGE_SHA256 /android.img | sha256sum --check

FROM ${BASE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
# base system
  ca-certificates curl iproute2 jq kmod socat \
# lxc
  iptables lxc \
# anbox deps
  libboost-log1.71.0  libboost-thread1.71.0 libboost-program-options1.71.0 libboost-iostreams1.71.0 libboost-filesystem1.71.0 libegl1-mesa libgles2-mesa libprotobuf-lite17 libsdl2-2.0-0 libsdl2-image-2.0-0 \
# squashfuse
  squashfuse fuse3 \
# adb
  adb \
# systemd
  dbus dbus-user-session systemd systemd-container systemd-sysv \
# X11
  libx11-6 libx11-data libxext6 \
  xvfb x11vnc \
# WM
  fvwm xterm \
# debug utilities
  busybox figlet file strace less && \
# ...
  useradd --create-home --home-dir /home/user --uid 1000 -G systemd-journal user  && \
  curl -L -o /docker-entrypoint.sh https://raw.githubusercontent.com/AkihiroSuda/containerized-systemd/6ced78a9df65c13399ef1ce41c0bedc194d7cff6/docker-entrypoint.sh && \
  chmod +x /docker-entrypoint.sh
# apk-pre.d is for pre-installed apks, /apk.d for the mountpoint for user-specific apks
RUN mkdir -p /apk-pre.d /apk.d && \
  curl -L -o /apk-pre.d/FDroid.apk https://f-droid.org/FDroid.apk && \
  curl -L -o /apk-pre.d/firefox.apk https://ftp.mozilla.org/pub/mobile/releases/68.9.0/android-x86_64/en-US/fennec-68.9.0.en-US.android-x86_64.apk && \
  chmod 444 /apk-pre.d/*
RUN mkdir -p /lib/anbox/swiftshader
COPY --from=android-img /android.img /aind-android.img
COPY --from=swiftshader /swiftshader/build/libEGL.so /swiftshader/build/libGLES_CM.so /swiftshader/build/libGLESv2.so /lib/anbox/swiftshader/
COPY --from=anbox /anbox-binary /usr/local/bin/anbox
COPY --from=anbox /anbox/scripts/anbox-bridge.sh /usr/local/share/anbox/anbox-bridge.sh
COPY --from=anbox /anbox/data/ui /usr/local/share/anbox/ui
RUN ldconfig
ADD src/anbox-container-manager-pre.sh /usr/local/bin/anbox-container-manager-pre.sh
ADD src/anbox-container-manager.service /lib/systemd/system/anbox-container-manager.service
RUN systemctl enable anbox-container-manager
ADD src/unsudo /usr/local/bin
ADD src/docker-2ndboot.sh  /home/user
# Usage: docker run --rm --privileged -v /:/host --entrypoint bash aind/aind -exc "cp -f /install-kmod.sh /host/aind-install-kmod.sh && cd /host && chroot . /aind-install-kmod.sh"
ADD hack/install-kmod.sh /
VOLUME /var/lib/anbox
ENTRYPOINT ["/docker-entrypoint.sh", "unsudo"]
EXPOSE 5900
HEALTHCHECK --interval=15s --timeout=10s --start-period=60s --retries=5 \
  CMD ["pgrep", "-f", "org.anbox.appmgr"]
CMD ["/home/user/docker-2ndboot.sh"]
