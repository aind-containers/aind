#!/bin/bash
set -eux -o pipefail
if [ $(id -u) != 0 ]; then
	echo >&2 "must be executed as root"
	exit 1
fi

# clean up orphan loop devices
if losetup | grep /aind-android.img; then
	losetup -J | jq -r '.loopdevices[] | select (."back-file" == "/aind-android.img") | .name' | xargs losetup -d
fi

# ashmem
/sbin/modprobe ashmem_linux
if [ ! -e /dev/ashmem ]; then
	mknod /dev/ashmem c 10 52
fi

# binder (newer kernel uses /dev/binderfs directory; older kernel uses /dev/binder file)
/sbin/modprobe binder_linux
if grep binder /proc/filesystems; then
	if [ ! -e /dev/binderfs/binder-control ]; then
		mkdir -p /dev/binderfs
		mount -t binder none /dev/binderfs
	fi
else
	if [ ! -e /dev/binder ]; then
		mknod /dev/binder c 10 59
	fi
fi
