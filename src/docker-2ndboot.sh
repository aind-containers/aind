#!/bin/bash
# docker-2ndboot.sh is executed as a non-root user via `unsudo`.

function finish {
    set +x
    figlet ERROR
    : FIXME: the container should shutdown automatically here
}
trap finish EXIT

cd $(realpath $(dirname $0)/..)
set -eux

mkdir -p ~/.vnc
if [ ! -e ~/.vnc/passwdfile ]; then
    set +x
    echo $(head /dev/urandom | tr -dc a-z0-9 | head -c 32) > ~/.vnc/passwdfile
    set -x
fi

Xvfb &
export DISPLAY=:0

until [ -e /tmp/.X11-unix/X0 ]; do sleep 1; done
: FIXME: remove this sleep
sleep 1
x11vnc -usepw -ncache 10 -forever -bg

fvwm &
if ! systemctl is-system-running --wait; then
    systemctl status --no-pager -l anbox-container-manager
    journalctl -u anbox-container-manager --no-pager -l
    exit 1
fi
systemctl status --no-pager -l anbox-container-manager

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

if [ $(cat /novnc_enabled) = "1" ]; then
    echo "running websockify..."
    websockify -D --web /usr/share/novnc/ 0.0.0.0:8080 127.0.0.1:5900
    echo "websockify -> $?"
fi

# done
figlet "Ready"
echo "Hint: the password is stored in $HOME/.vnc/passwdfile"
exec sleep infinity
