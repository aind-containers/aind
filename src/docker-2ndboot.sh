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

function waitUntil() {
    local message=$1
    local count=$2
    until $3; do
        echo "$message"
        count=$((count - 1))
        [ $count -lt 1 ] && return 1
        sleep 1
    done
    return 0
}

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
    
    if ! waitUntil "Waiting for ready X11 server" 10 "[ -e /tmp/.X11-unix/X0 ]"; then
      exit 1
    fi
    sleep 1
    x11vnc -usepw -ncache 10 -forever -bg

    fvwm &
fi

if ! systemctl is-system-running --wait; then
    systemctl status --no-pager -l anbox-container-manager
    journalctl -u anbox-container-manager --no-pager -l
    exit 1
fi
systemctl status --no-pager -l anbox-container-manager

if ! waitUntil "Waiting for ready /run/anbox-container.socket" 10 "[ -e /run/anbox-container.socket ]"; then
    exit 1
fi

anbox session-manager ${SESSION_MANAGER_ARGS:-} &
if ! waitUntil "Waiting for ready anbox" 60 "anbox wait-ready"; then
  exit 1
fi
anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity

adb wait-for-device

# install apk (pre-installed apps such as F-Droid)
for f in /apk-pre.d/*.apk; do adb install -r $f; done

# install apk
if ls /apk.d/*.apk; then
    for f in /apk.d/*.apk; do adb install -r $f; done
fi

[ -n "${POST_SESSION_SCRIPT:-}" ] && . $POST_SESSION_SCRIPT

if [ $WEBMODE = "1" ]; then
    echo "running websockify..."
    websockify -D --web /usr/share/novnc/ 0.0.0.0:8080 127.0.0.1:5900
    echo "websockify -> $?"
fi

# done
figlet "Ready"
echo "Hint: the password is stored in $HOME/.vnc/passwdfile"
exec sleep infinity
