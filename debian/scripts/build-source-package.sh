#!/bin/sh
# This script builds a perfSONAR Debian source package from a git repository checkout.
# It uses git-buildpackage and its configuration for the package in debian/gbp.conf
# It is made to work with Jenkins, for that purpose the git repository need to be checked out
# in a sub-directory of the Jenkins workspace, per convention we call this sub-directory 'source'.
# The resulting artefacts will be at the root level of the workspace.
#
# It also uses the following environment variables (or Jenkins parameters)
#   tag: the git tag to build from (ex: 4.0-2.rc1-1)
#   branch: the git branch to build from (ex: debian/jessie)

# Configuration
SRC_DIR='source'
GIT_BUILDING_REPO='toolkit-building'

# Trick to enable the Git parameter plugin to work with the source directory where we checked out
# the source code. Otherwise, the Git parameter plugin cannot find the tags existing in the repository
# This is a bug in the git-parameter plugin, see https://issues.jenkins-ci.org/browse/JENKINS-27726
ln -s ${SRC_DIR}/.git* .

# We don't want to package any submodule
cd ${SRC_DIR}
git submodule deinit -f .

# Check the tag parameter, it has precedence over the branch parameter
DEBIAN_TAG=$tag
if [ -z $DEBIAN_TAG ]; then
    # If we don't have a tag, we look which branch we're on
    DEBIAN_BRANCH=`git branch --list | awk '/^\* .*$/ {print $2}'`
    if [ ! "${DEBIAN_BRANCH%%\/*}" = "debian" ]; then
        echo "This doesn't look like a Debian branch for me to build, I'll quit."
        exit 1
    fi
else
    # If we have a tag we check it out
    DEBIAN_BRANCH=${tag}
fi
# Make sure we use the desired repository checkout
git checkout ${DEBIAN_BRANCH}

# Get upstream branch from gbp.conf and making it a local branch so we can merge and build tarball from it
UPSTREAM_BRANCH=`awk '/^upstream-branch/ {print $3}' debian/gbp.conf`
PKG=`awk 'NR==1 {print $1}' debian/changelog`
git branch ${UPSTREAM_BRANCH} origin/${UPSTREAM_BRANCH}

# Our default gbp options
GBP_OPTS="-nc --git-force-create --git-ignore-new --git-ignore-branch -S -us -uc --git-verbose --git-builder=/bin/true --git-cleaner=/bin/true --git-export-dir="

# Special repositories/packages needs
if [ "${PKG}" = "maddash" ]; then
    # MaDDash has a submodule we want to package!
    GBP_OPTS=$GBP_OPTS" --git-submodules"
    git submodule update --init maddash-server/madalert
fi

# We package the upstream sources (tarball) from git with git-buildpackage
if [ -z $DEBIAN_TAG ]; then
    # If we don't have a tag, we take the source from the debian/branch and merge upstream in it so we have the latest changes
    echo "\nBuilding snapshot package of ${PKG} from ${DEBIAN_BRANCH}.\n"
    git merge ${UPSTREAM_BRANCH}
    # We set the author of the Debian Changelog, only for snapshot builds (this doesn't seem to be used by gbp dch :(
    export DEBEMAIL="perfsonar-debian Autobuilder <debian@perfsonar.net>"
    # We can ignore NMU related warnings from LINTIAN as this package is not to be posted to official Debian repo
    LINTIAN_ARGS="--suppress-tags changelog-should-mention-nmu,source-nmu-has-incorrect-version-number"
    # And we generate the changelog ourselves, with a version number suitable for an upstream snapshot
    gbp dch -S --ignore-branch -a
    timestamp=`date +%Y%m%d%H%M%S`
    sed -i "1 s/\((.*\)\(-[0-9]\{1,\}\)\(.*\))/\1+${timestamp}\3\2)/" debian/changelog
    git-buildpackage $GBP_OPTS --git-upstream-tree=branch --git-upstream-branch=${UPSTREAM_BRANCH}
else
    # If we have a tag, we take the source from the git tag
    echo "\nBuilding release package of ${PKG} from ${DEBIAN_TAG}.\n"
    # We build the upstream tag from the Debian tag by, see https://github.com/perfsonar/project/wiki/Versioning :
    # - removing the leading debian/distro prefix
    # - removing the ending -1 debian-version field
    UPSTREAM_TAG=${tag##*\/}
    git-buildpackage $GBP_OPTS --git-upstream-tree=tag --git-upstream-tag=${UPSTREAM_TAG%-*}
fi
[ $? -eq 0 ] || exit 1

# Remove the GIT_BUILDING_REPO in case it re-emerged (with the --git-submodules option)
git submodule deinit -f ${GIT_BUILDING_REPO}

# Build the source package
dpkg-buildpackage -uc -us -nc -d -S -i -I --source-option=--unapply-patches
[ $? -eq 0 ] || exit 1

# Run Lintian on built package
cd ..
# Create lintian report in junit format, if jenkins-debian-glue is installed
if [ -x /usr/bin/lintian-junit-report ]; then
    /usr/bin/lintian-junit-report ${PKG}*.dsc > lintian.xml
fi
lintian ${LINTIAN_ARGS} --show-overrides ${PKG}*.dsc

