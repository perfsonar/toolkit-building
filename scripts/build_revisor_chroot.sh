#!/bin/bash

CHROOT_DIR=$1
ARCHITECTURE=$2

if [ "$(id -u)" != 0 ]; then
	echo "Error: SuperUser privileges required to use this script."
	exit -1
fi

if [ -z "$CHROOT_DIR" ]; then
    echo "Need to specify the directory to use for building the chroot"
    exit -1
fi

if [ -z "$ARCHITECTURE" ]; then
    echo "Need to specify the architecture to use for building the chroot"
    exit -1
fi


mkdir -p $CHROOT_DIR
mkdir -p $CHROOT_DIR/var/lib/rpm
rpm --rebuilddb --root=$CHROOT_DIR

rpm -Uvh --nodeps --root=$CHROOT_DIR http://mirror.centos.org/centos/6/os/i386/Packages/centos-release-6-6.el6.centos.12.2.i686.rpm 

setarch $ARCHITECTURE yum --installroot=$CHROOT_DIR install -y rpm-build yum

setarch $ARCHITECTURE yum install -y --installroot=$CHROOT_DIR http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
setarch $ARCHITECTURE yum install -y --installroot=$CHROOT_DIR http://ftp.scientificlinux.org/linux/scientific/6.4/x86_64/addons/revisor/revisor-cli-2.2-4.sl6_3.noarch.rpm http://ftp.scientificlinux.org/linux/scientific/6.4/x86_64/addons/revisor/sl-revisor-configs-1-6.3.4.noarch.rpm

# Mount the virtual file systems in the chroot so we can build things properly
mount --bind /proc $CHROOT_DIR/proc
mount --bind /dev $CHROOT_DIR/dev

# Allow us to resolve host names in the chroot jail
cp /etc/resolv.conf $CHROOT_DIR/etc/
