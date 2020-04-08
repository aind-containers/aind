#!/bin/bash
# docker-2ndboot.sh is executed as a non-root user via `unsudo`.

cd $(realpath $(dirname $0)/..)
set -eux
Xvfb &
export DISPLAY=:0

: FIXME
sleep 5
x11vnc &

: FIXME
sleep 5
anbox session-manager &

: FIXME
sleep 5
anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity

sleep infinity
