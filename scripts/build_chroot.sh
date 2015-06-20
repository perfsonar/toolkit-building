#!/bin/bash

CHROOT_DIR=$1
ARCHITECTURE=$2

#RPMS
CENTOS_RELEASE_RPM="http://mirror.centos.org/centos/6/os/i386/Packages/centos-release-6-6.el6.centos.12.2.i686.rpm"
EPEL_RELEASE_RPM="http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"
I2_REPO_RPM="http://software.internet2.edu/rpms/el6/x86_64/RPMS.main/Internet2-repo-0.6-1.noarch.rpm"

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

rpm -Uvh --nodeps --root=$CHROOT_DIR $CENTOS_RELEASE_RPM

setarch $ARCHITECTURE yum --installroot=$CHROOT_DIR install -y rpm-build yum anaconda anaconda-runtime createrepo mkisofs
setarch $ARCHITECTURE yum install -y --installroot=$CHROOT_DIR $EPEL_RELEASE_RPM $I2_REPO_RPM 

#make sure web100 is available
sed -i -e 's|enabled.*=.*|enabled = 1|' $CHROOT_DIR/etc/yum.repos.d/Internet2-web100_kernel.repo

# Mount the virtual file systems in the chroot so we can build things properly
mount --bind /proc $CHROOT_DIR/proc
mount --bind /dev $CHROOT_DIR/dev

# Allow us to resolve host names in the chroot jail
cp /etc/resolv.conf $CHROOT_DIR/etc/
