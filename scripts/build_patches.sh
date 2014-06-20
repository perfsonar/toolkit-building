#!/bin/bash
EXT=".cfg"

# Assume we're running from the 'scripts' directory
SCRIPTS_DIRECTORY=`dirname $(readlink -f $0)`
KICKSTARTS_DIRECTORY=`readlink -m $SCRIPTS_DIRECTORY/../kickstarts`

BASE_KICKSTART=`find $KICKSTARTS_DIRECTORY -type f -name "*base$EXT" | head -1`
KICKSTARTS=`find $KICKSTARTS_DIRECTORY -type f -name "*$EXT" | grep -v "base$EXT"`

echo -e "\nCreating kickstart patches..."
echo "****************************************"
for KICKSTART in `echo "$KICKSTARTS"`; do
	NAME=${KICKSTART%\.*}
	echo "Creating patch for $(basename $KICKSTART)"
	diff -ur $BASE_KICKSTART $KICKSTART > $NAME.patch
done
echo "****************************************"
echo -e "Process completed, exiting...\n"