ARG BASE=ubuntu:20.04

# Apr 7, 2020
ARG ANBOX_COMMIT=6d9ada9d10348589a03d8101e7cb9f50d6d0b5fb

# Apr 7, 2020
# NOTE: we can't use lxc 4.0.1 dpkg because of https://github.com/lxc/lxc/issues/3363
ARG LXC_COMMIT=7672d4083f9a75cb72c0f914e1444200dd67ce15

# ARG ANDROID_IMAGE=https://build.anbox.io/android-images/2018/07/19/android_amd64.img
# Mirror
ARG ANDROID_IMAGE=https://github.com/AkihiroSuda/anbox-android-images-mirror/releases/download/snapshot-20180719/android_amd64.img

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
  python2
RUN git clone https://github.com/anbox/anbox /anbox
WORKDIR /anbox
ARG ANBOX_COMMIT
RUN git pull && git checkout ${ANBOX_COMMIT}
RUN mkdir build && \
  cd build && \
  cmake .. && \
  make -j10 anbox

FROM ${BASE} AS android-img
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
  ca-certificates curl
ARG ANDROID_IMAGE
RUN curl --retry 10 -L -o /android.img $ANDROID_IMAGE

FROM ${BASE} AS lxc
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y autoconf automake build-essential libtool git libapparmor-dev libcap-dev libgnutls28-dev libpam0g-dev libseccomp-dev libselinux1-dev linux-libc-dev pkg-config
RUN git clone https://github.com/lxc/lxc.git /lxc
WORKDIR /lxc
ARG LXC_COMMIT
RUN git pull && git checkout ${LXC_COMMIT}
RUN ./autogen.sh && ./configure || (cat config.log; exit 1)
RUN make && make install

FROM ${BASE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
# base system
  ca-certificates curl iproute2 kmod \
# lxc deps
  iptables libcap2 libseccomp2 libselinux1 \
# anbox deps
  libboost-log1.71.0  libboost-thread1.71.0 libboost-program-options1.71.0 libboost-iostreams1.71.0 libboost-filesystem1.71.0 libegl1-mesa libgles2-mesa libprotobuf-lite17 libsdl2-2.0-0 libsdl2-image-2.0-0 \
# adb
  adb \
# systemd
  dbus dbus-user-session systemd systemd-container systemd-sysv \
# X11
  xvfb x11vnc \
# WM
  fvwm xterm \
# debug utilities
  busybox figlet file strace less && \
# ...
  useradd --create-home --home-dir /home/user --uid 1000 -G systemd-journal user  && \
  curl -L -o /docker-entrypoint.sh https://raw.githubusercontent.com/AkihiroSuda/containerized-systemd/6ced78a9df65c13399ef1ce41c0bedc194d7cff6/docker-entrypoint.sh && \
  chmod +x /docker-entrypoint.sh
COPY --from=lxc /usr/local /usr/local/
COPY --from=android-img /android.img /android.img
COPY --from=anbox /anbox/build/src/anbox /usr/local/bin/anbox
COPY --from=anbox /anbox/scripts/anbox-bridge.sh /usr/local/share/anbox/anbox-bridge.sh
COPY --from=anbox /anbox/data/ui /usr/local/share/anbox/ui
RUN ldconfig
ADD src/anbox-container-manager.service /lib/systemd/system/anbox-container-manager.service
RUN systemctl enable anbox-container-manager
ADD src/unsudo /usr/local/bin
ADD src/docker-2ndboot.sh  /home/user
# apk-pre.d is for pre-installed apks, /apk.d for the mountpoint for user-specific apks
RUN mkdir -p /apk-pre.d /apk.d
ADD https://f-droid.org/FDroid.apk /apk-pre.d
ADD https://ftp.mozilla.org/pub/mobile/releases/68.7.0/android-x86_64/en-US/fennec-68.7.0.en-US.android-x86_64.apk /apk-pre.d
RUN chmod 444 /apk-pre.d/*
VOLUME /var/lib/anbox
ENTRYPOINT ["/docker-entrypoint.sh", "unsudo"]
EXPOSE 5900
CMD ["/home/user/docker-2ndboot.sh"]
