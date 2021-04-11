#!/bin/bash
# docker-2ndboot.sh is executed as a non-root user via `unsudo`.

if [ -z "${INHERIT_DISPLAY:-}" ]; then
    INHERIT_DISPLAY=0
    [ -n "${DISPLAY:-}" ] && INHERIT_DISPLAY=1
fi

function finish {
    set +x
    figlet ERROR
    : FIXME: the container should shutdown automatically here
}
trap finish EXIT

cd $(realpath $(dirname $0)/..)
set -eux

export EGL_PLATFORM=x11

if [ $INHERIT_DISPLAY -eq 0 ]; then
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
elif [ "${CUSTOM_DISPLAY_SCRIPT:-}" ]; then
    . $CUSTOM_DISPLAY_SCRIPT
fi

env

if ! systemctl is-system-running --wait; then
    systemctl status --no-pager -l anbox-container-manager
    journalctl -u anbox-container-manager --no-pager -l
    exit 1
fi
systemctl status --no-pager -l anbox-container-manager

${SESSION_MANAGER_WRAPPER:-} anbox session-manager ${SESSION_MANAGER_ARGS:-} &
until anbox wait-ready; do sleep 1; done
anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity

adb wait-for-device

# install apk (pre-installed apps such as F-Droid)
for f in /apk-pre.d/*.apk; do adb install $f; done

# install apk
if ls /apk.d/*.apk; then
    for f in /apk.d/*.apk; do adb install $f; done
fi

[ -n "${POST_SESSION_SCRIPT:-}" ] && . $POST_SESSION_SCRIPT

# done
figlet "Ready"
echo "Hint: the password is stored in $HOME/.vnc/passwdfile"
exec sleep infinity
