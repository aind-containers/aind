#!/bin/bash
# Install ashmem and binder kernel modules from https://github.com/anbox/anbox-modules .
# Must be executed on the host.
set -eux -o pipefail
if [ $(id -u) != 0 ]; then
	echo >&2 "must be executed as root"
	exit 1
fi
if [ -e /dev/ashmem ]; then
	if grep binder /proc/filesystems; then
		echo "ashmem and binderfs are already enabled. Skipping installing modules."
		exit 0
	fi
	if [ -e /dev/binder ]; then
		echo "ashmem and binder (classic) are already enabled. Skipping installing modules."
		exit 0
	fi
fi
# TODO: support non-Ubuntu
apt-get update
apt-get install -q -y dkms git linux-headers-generic
tmp=$(mktemp -d aind-kmod-install.XXXXXXXXXX --tmpdir)
git clone https://github.com/anbox/anbox-modules $tmp/anbox-modules
(
	cd $tmp/anbox-modules
	cp -f anbox.conf /etc/modules-load.d/
	cp -f 99-anbox.rules /lib/udev/rules.d/
	cp -rTf ashmem /usr/src/anbox-ashmem-1
	cp -rTf binder /usr/src/anbox-binder-1
	dkms install anbox-ashmem/1
	dkms install anbox-binder/1
	modprobe ashmem_linux
	modprobe binder_linux
)
rm -rf $tmp
