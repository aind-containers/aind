#!/bin/bash
# docker-2ndboot.sh is executed as a non-root user via `unsudo`.

function finish {
    figlet ERROR
    echo "ERROR: failed!"
    : FIXME: the container should shutdown automatically here
}
trap finish EXIT

cd $(realpath $(dirname $0)/..)
set -eux
Xvfb &
export DISPLAY=:0

until [ -e /tmp/.X11-unix/X0 ]; do sleep 1; done
: FIXME: remove this sleep
sleep 1
x11vnc &
: FIXME: remove this sleep
sleep 1
fvwm &
if ! systemctl is-system-running --wait; then
    systemctl status anbox-container-manager --no-pager
    exit 1
fi
systemctl status anbox-container-manager --no-pager

anbox session-manager &
until anbox wait-ready; do sleep 1; done
anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity

adb wait-for-device

# install apk (pre-installed apps such as F-Droid)
for f in /apk-pre.d/*.apk; do adb install $f; done

# install apk
if ls /apk.d/*.apk; then
    for f in /apk.d/*.apk; do adb install $f; done
fi

# done
figlet "Ready"
ps -ef
exec sleep infinity
