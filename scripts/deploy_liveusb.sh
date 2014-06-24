#!/bin/bash

# Warning
if [ "$(id -u)" != 0 ]; then
	echo "Warning: SuperUser privileges required to use this script."
	read -p "Press [Enter] key to continue..."
fi

##############################
# Check For User Input
##############################
if [ -z "$1" ]; then
	echo "Usage: bash deploy_liveusb.sh [--arch <arch>] <device> [diskimage]"
	echo "E.g.: bash deploy_liveusb.sh /dev/sdb1 (to use flash drive partition)"
	echo "  or: bash deploy_liveusb.sh /dev/sdb (to wipe flash drive and create new partition)"
	echo "  or: bash deploy_liveusb.sh /dev/sdb1 image.iso (to specify ISO disk image)"
	exit -1
fi

##############################
# Process Arguments
##############################
while [ $# -gt 2 ]; do
    case $1 in
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

##############################
# Build Configuration
##############################
BUILD=pS-Performance_Toolkit
BUILD_SHORT=pS-Toolkit
BUILD_DATE=`date "+%Y-%m-%d"`
BUILD_VERSION="3.3.2"
BUILD_RELEASE=""
BUILD_TYPE=LiveUSB
if [ -z $BUILD_ARCH ]; then
	BUILD_ARCH=i386
fi

##############################
# Function Create ISO
##############################
function createISO()
{
	# Use existing or create new disk image
	if [ -s ../resources/$ISO ]; then
		echo "Using existing $ISO as disk image."
	else
		echo "Creating new disk image: $ISO."
		echo -e "\n******************************"
		bash build_`echo $BUILD_TYPE.sh | tr '[:upper:]' '[:lower:]'`
		local status=$?
		echo -e "******************************\n"
		if [ $status != 0 ]; then
			echo "Couldn't create new image: $ISO."
			exit -1
		fi
	fi
}

##############################
# Function Format Drive
##############################
function formatDrive()
{
	# Create new partition table and partition
	local drive=$1
	
	echo "Creating new partition table on $drive."
	echo -e "o\nn\np\n1\n\n\na\n1\nt\nc\nw" | /sbin/fdisk $drive > /dev/null 2>&1
	if [ $? -gt 1 ]; then
		echo "Couldn't partition $drive."
		return 1
	fi
	
	# Wait for vol_id process to finish
	local timeout=5
	sleep $timeout &
	local pid_sleep=$!
	local pid=`/sbin/pidof vol_id`
	while [ -n "$pid" ]; do
		pid=`/sbin/pidof vol_id`
		if ( ! ps | grep -q "$pid_sleep" ); then
			echo "Vol_ID process timeout, will continue."
			break
		fi
	done
	kill $pid_sleep 2> /dev/null & wait $pid_sleep 2> /dev/null
	
	# Format partition and add label
	echo "Formatting partition ${drive}1."
	/sbin/mkfs.vfat -F 32 -n $BUILD_SHORT ${drive}1 > /dev/null 2>&1
	if [ $? != 0 ]; then
		echo "Couldn't format ${drive}1."
		return 1
	fi
}

##############################
# Function Format Partition
##############################
function formatPartition()
{
	# Format partition and add label
	local partition=$1
	echo "Formatting partition $partition."
	/sbin/mkfs.vfat -F 32 -n $BUILD_SHORT ${partition} > /dev/null 2>&1
	if [ $? != 0 ]; then
		echo "Couldn't format $partition."
		exit -1
	fi
}

##############################
# Function Unmount Drive
##############################
function unmountDrive()
{
	# Unmount Drive
	local drive=$1
	
	echo "Unmounting drive $drive."
	umount -l $drive > /dev/null 2>&1
	if [ $? -gt 1 ]; then
		echo "Couldn't unmount $drive."
		exit -1
	fi
}

##############################
# Function Unmount Partition
##############################
function unmountPartition()
{
	# Unmount Partition
	local partition=$1
	
	echo "Unmounting partition $partition."
	umount -l $partition > /dev/null 2>&1
	if [ $? -gt 1 ]; then
		echo "Couldn't unmount $partition."
		exit -1
	fi
}

##############################
# ISO Configuration
##############################
# Check for valid disk image or create new one
ISO="../resources/${BUILD}-${BUILD_VERSION}${BUILD_RELEASE}-${BUILD_TYPE}-${BUILD_ARCH}.iso"
if [ -n "$2" ]; then
	if [ -s "$2" ]; then
		ISO=$2
	else
		echo "Couldn't find $2."
		createISO
	fi
else
	createISO
fi

PARTITION=$1
##############################
# Use Existing Partition
##############################
if ( echo ${1#${1%?}} | grep -q [0-9] ); then
	# Prompt
	echo "Warning this option will erase all data in the selected partition: $1."
	while true; do
	    read -p "Are you sure you want to continue (y/n)?: " option
	    case $option in
	        [Yy]* ) break;;
	        [Nn]* ) exit;;
	        * ) echo "Invalid option: Please choose y for yes or n for no.";;
	    esac
	done
	
	unmountPartition $1
	formatPartition $1
	PARTITION=$1
	
##############################
# Wipe Flash Drive and Make New Partition
##############################
else
	# Prompt
	echo "Warning this option will erase all data and partitions on the selected drive: $1."
	while true; do
	    read -p "Are you sure you want to continue (y/n)?: " option
	    case $option in
	        [Yy]* ) break;;
	        [Nn]* ) exit;;
	        * ) echo "Invalid option: Please choose y for yes or n for no.";;
	    esac
	done
	
	unmountDrive $1
	if ( ! formatDrive $1 ); then
		# Erase partition table
		echo "Erasing partition table."
		dd if=/dev/zero of=$1 bs=512 count=1 > /dev/null 2>&1
		if [ ! $? ]; then
			echo "Couldn't erase partition table."
			exit -1
		fi
		if ( ! formatDrive $1 ); then
			echo "Couldn't format and partition drive."
			exit -1
		fi
	fi
	PARTITION=${1}1
fi

##############################
# Copy Disk Image to Flash Drive
##############################
echo -e "\n" | livecd-iso-to-disk $ISO $PARTITION
if [ $? != 0 ]; then
	echo "Couldn't copy disk image to $PARTITION."
	echo "Either livecd-tools isn't installed or is not up to date."
	exit -1
	# if ( ! echo ${1#${1%?}} | grep -q [0-9] ); then
		# echo "Trying alternative method. Warning this method may not function properly."
		# dd if=../resources/$ISO of=$1 bs=4096
		# if [ $? != 0 ]; then
			# echo "Couldn't copy disk image to $1."
			# exit -1
		# fi
	# else
		# exit -1
	# fi
fi
echo "LiveUSB created successfully. Exiting..."
