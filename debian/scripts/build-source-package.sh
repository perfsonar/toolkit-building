#!/bin/sh
# This scripts builds a perfSONAR Debian source package from a git repository checkout
# It uses git-buildpackage and its configuration for the package in debian/gbp.conf
# It is made to work with Jenkins, for that purpose the git repository need to be checked out
# in a sub-directory of the Jenkins workspace, per convention we call this sub-directory 'source'
# The build artefacts will be at the root level of the workspace
#
# It also uses the following environment variables (or Jenkins parameters)
#   tag: the git tag to build from (ex: 4.0-2.rc1-1)
#   branch: the git branch to build from (ex: debian/jessie)

# Configuration
SRC_DIR='source'
GIT_BUILDING_REPO='toolkit-building'

# Trick to enable the Git parameter plugin to work with the source directory where we checked out
# the source code. Otherwise, the Git parameter plugin cannot find the tags existing in the repository
ln -s ${SRC_DIR}/.git* .

# Check the tag parameter
DEBIAN_TAG=$tag
if [ -z $DEBIAN_TAG ]; then
    # If we don't have a tag, we use the branch parameter
    DEBIAN_BRANCH=${branch#refs/remotes/origin/}
else
    # If we have a tag we take the branch name from it
    DEBIAN_BRANCH=${tag%\/*}
fi

# In the checked out source directory we use the DEBIAN_BRANCH
cd ${SRC_DIR}
git checkout ${DEBIAN_BRANCH}

# Get upstream branch from gbp.conf and check it out so we can merge it later on
UPSTREAM_BRANCH=`awk '/^upstream-branch/ {print $3}' debian/gbp.conf`
PKG=`awk 'NR==1 {print $1}' ${SRC_DIR}/debian/changelog`
git checkout ${UPSTREAM_BRANCH}
git checkout ${DEBIAN_BRANCH}
if [ -z $DEBIAN_TAG ]; then
    echo -e "Building \033[1;32m${PKG}\033[0;37m from \033[1m${DEBIAN_BRANCH}\033[0m.\n"
else
    echo -e "Building \033[1;32m${PKG}\033[0;37m from \033[1m${DEBIAN_TAG}\033[0m.\n"
fi

# default gbp options
GBP_OPTS="-nc --git-force-create --git-ignore-new --git-ignore-branch -S -us -uc --git-verbose --git-builder=/bin/true --git-cleaner=/bin/true --git-export-dir="
if [ ${PKG} = "maddash" ]; then
    GBP_OPTS=$GBP_OPTS" --git-submodules"
fi

# We build the upstream sources (tarball) from git with git-buildpackage
if [ -z $DEBIAN_TAG ]; then
    # If we don't have a tag, we take the source from the current debian/branch and merge upstream in it so we have the latest changes, this will be a snapshot build
    git merge ${UPSTREAM_BRANCH}
    # We set the author of the Debian Changelog, only for snapshot builds
    export DEBEMAIL="perfsonar-debian Autobuilder <debian@perfsonar.net>"
    # And we generate the changelog ourselves, with a version number suitable for an upstream snapshot
    gbp dch -S --ignore-branch -a
    timestamp=`date +%Y%m%d%H%M%S`
    sed -i "1 s/\((.*\)\(-[0-9]\{1,\}\)\(.*\))/\1+${timestamp}\3\2)/" debian/changelog
    git-buildpackage $GBP_OPTS --git-upstream-tree=branch --git-upstream-branch=${UPSTREAM_BRANCH}
else
    # If we have a tag, we take the source from the git tag, this will be a release build
    MY_GBP_OPTS="--git-upstream-tree=tag"
    # We build the upstream tag from the Debian tag by:
    # - removing the leading debian/distro prefix
    # - removing the ending -1 debian-version field
    UPSTREAM_TAG=${tag##*\/}
    git-buildpackage $GBP_OPTS --git-upstream-tree=tag --git-upstream-tag=${UPSTREAM_TAG%-*}
fi

# Build the source package, but we remove ourselves first
rm -rf ${GIT_BUILDING_REPO}
dpkg-buildpackage -uc -us -nc -d -S -i -I --source-option=--unapply-patches

# Create lintian report in junit format, if jenkins-debian-glue is installed
cd ..
if [ -x /usr/bin/lintian-junit-report ]; then
    /usr/bin/lintian-junit-report *.dsc > lintian.xml
fi
