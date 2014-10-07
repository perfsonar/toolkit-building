#!/bin/bash

# Warning
if [ "$(id -u)" != 0 ]; then
	echo "Error: SuperUser privileges required to use this script."
	exit -1
fi

CHROOT=
BUILD_CHROOT=0

##############################
# Process Arguments
##############################
while [ $# -gt 0 ]; do
    case $1 in
        --build-chroot)
			BUILD_CHROOT=1
			shift
			;;


        --chroot)
			CHROOT=$2
			shift
			shift
			;;

        --arch)
			BUILD_ARCH=$2
			if [ -z $BUILD_ARCH ]; then
				echo "No architecture specified, exiting..."
				exit 1
			fi
			if [ ! $BUILD_ARCH = "i386" -a ! $BUILD_ARCH = "x86_64" ]; then
				echo "Invalid architecture specified, exiting..."
				exit 1
			fi
			shift
			shift
			;;
	-*)
			echo "Invalid arg: $1"
			exit 1
			;;
        *)
			break
			;;
    esac
done

ARCH=`arch`
if [ "$BUILD_ARCH" != "$ARCH" -a -z "$CHROOT" -a -z "$BUILD_CHROOT" ]; then
    echo "You need to build the DVD on a host with the same architecture (i386 or x86-64) as the DVD itself, or to specify a 'chroot' jail"
    exit -1
fi

##############################
BUILD="perfSONAR Toolkit"
BUILD_SHORT="pS-Toolkit"
BUILD_DATE=`date "+%Y-%m-%d"`
BUILD_VERSION="3.4"
BUILD_RELEASE=""
BUILD_OS="CentOS6"
BUILD_TYPE=FullInstall
if [ -z $BUILD_ARCH ]; then
	BUILD_ARCH=i386
fi

BUILD_OS_LOWER=`echo $BUILD_OS | tr '[:upper:]' '[:lower:]'`
BUILD_TYPE_LOWER=`echo $BUILD_TYPE | tr '[:upper:]' '[:lower:]'`
# Assume we're running from the 'scripts' directory
SCRIPTS_DIRECTORY=`dirname $(readlink -f $0)`

REVISOR_CONF_DIRECTORY=$SCRIPTS_DIRECTORY/../revisor

##############################
# Kickstart Configuration
##############################
KICKSTARTS_DIRECTORY=$SCRIPTS_DIRECTORY/../kickstarts
KICKSTART_FILE=$BUILD_OS_LOWER-base.cfg
KICKSTART_PATCH=$BUILD_OS_LOWER-$BUILD_TYPE_LOWER.patch
TEMP_KICKSTART_PATCH=`mktemp`
PATCHED_KICKSTART=`mktemp`

##############################
# Apply Patch
##############################
echo "Applying $KICKSTART_PATCH to $KICKSTART_FILE."
pushd $KICKSTARTS_DIRECTORY > /dev/null 2>&1

cp $KICKSTART_PATCH $TEMP_KICKSTART_PATCH
sed -i "s/\[BUILD_ARCH\]/$BUILD_ARCH/g" $TEMP_KICKSTART_PATCH
#uncomment arch specific lines
sed -i "s/#$BUILD_ARCH//g" $TEMP_KICKSTART_PATCH

if [ -s "$KICKSTART_PATCH" ]; then
	patch -i $TEMP_KICKSTART_PATCH -p0 $KICKSTART_FILE -o $PATCHED_KICKSTART
else
	cp $KICKSTART_FILE $PATCHED_KICKSTART
	sed -i "s/\[BUILD_ARCH\]/$BUILD_ARCH/g" $PATCHED_KICKSTART
fi
popd > /dev/null 2>&1

if [ "$BUILD_CHROOT" == "1" ]; then
    if [ ! -x $SCRIPTS_DIRECTORY/build_revisor_chroot.sh ]; then
        echo "The script to build a chroot is missing"
        exit -1
    fi

    CHROOT=`mktemp -d`
    $SCRIPTS_DIRECTORY/build_revisor_chroot.sh $CHROOT $BUILD_ARCH
fi

if [ -z "$CHROOT" ]; then
    CHROOT="/"
fi

REVISOR_BUILD=/tmp/revisor_build
CHROOT_REVISOR_BUILD=$CHROOT/$REVISOR_BUILD

mkdir -p $CHROOT_REVISOR_BUILD

cp $REVISOR_CONF_DIRECTORY/*conf $CHROOT_REVISOR_BUILD
mv $PATCHED_KICKSTART $CHROOT_REVISOR_BUILD

PATCHED_KICKSTART=`basename $PATCHED_KICKSTART`

cat > $CHROOT_REVISOR_BUILD/build_dvd.sh <<EOF
#!/bin/bash
pushd $REVISOR_BUILD
revisor --cli --respin --model pspt-$BUILD_ARCH --product-version "$BUILD_VERSION" --iso-basename "$BUILD_SHORT" --iso-label "$BUILD_SHORT" --product-name "$BUILD" --kickstart $PATCHED_KICKSTART --kickstart-include --kickstart-default --install-dvd --usb-size 1G --debug 9 --config revisor.conf --destination-directory \`pwd\`
popd
EOF

chmod +x $CHROOT_REVISOR_BUILD/build_dvd.sh

setarch $BUILD_ARCH chroot $CHROOT $REVISOR_BUILD/build_dvd.sh

for ISO in $CHROOT_REVISOR_BUILD/pspt-$BUILD_ARCH/iso/*iso; do
#for ISO in *iso; do
    TEMP_ISO_MNT=`mktemp -d`
    TEMP_NEW_ISO_MNT=`mktemp -d`

    echo "Placing kickstart into initrd.img"
    mount -o loop $ISO $TEMP_ISO_MNT

    rmdir $TEMP_NEW_ISO_MNT

    cp -Ra $TEMP_ISO_MNT $TEMP_NEW_ISO_MNT

    umount $TEMP_ISO_MNT

    cp $TEMP_NEW_ISO_MNT/ks.cfg $TEMP_NEW_ISO_MNT/isolinux/ks.cfg

    pushd $TEMP_NEW_ISO_MNT/isolinux
    mv initrd.img initrd.img.xz
    xz --format=lzma initrd.img.xz --decompress
    echo ks.cfg | cpio -c -o -A -F initrd.img
    xz --format=lzma initrd.img
    mv initrd.img.lzma initrd.img
    rm ks.cfg
    popd

    echo "Updating isolinux configuration."
    sed -i "s|cdrom:/|file:///|g" $TEMP_NEW_ISO_MNT/isolinux/isolinux.cfg

    mkisofs -r -R -J -T -v -no-emul-boot -boot-load-size 4 -boot-info-table -input-charset UTF-8 -V "$BUILD_SHORT" -p "$0" -A "$BUILD" -b isolinux/isolinux.bin -c isolinux/boot.cat -x “lost+found” -o $ISO $TEMP_NEW_ISO_MNT

    echo "Implanting MD5 in ISO."
    if [ -a /usr/bin/implantisomd5 ]; then
        /usr/bin/implantisomd5 $ISO
    elif [ -a /usr/lib/anaconda-runtime/implantisomd5 ]; then
        /usr/lib/anaconda-runtime/implantisomd5 $ISO
    else
        echo "Package isomd5 not installed."
    fi

    echo "Running isohbyrid on ISO."
    isohybrid $ISO
done

mv $CHROOT_REVISOR_BUILD/pspt-$BUILD_ARCH/iso/* .

rm -rfv $CHROOT_REVISOR_BUILD
