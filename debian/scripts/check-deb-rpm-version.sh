#!/bin/bash
# Script to check that the version of Debian packages is the same as the RPM version.
# Versions in .spec file and in the debian/changelog files are compared.

# Parameter is the name of the package to check
if [ $# -ne 1 ]; then
    echo "This script needs the name of the package to check version numbers."
    exit 1
else
    pkg=${1%%\/*}
fi

# Check the package is actually existing
if [ ! -d $pkg ]; then
    echo "It doesn't seem a package by the name of $pkg is existing in the current repository."
    exit 1
fi

# Special packages
if [ "$pkg" = "pscheduler-rpm" ]; then
    echo "$pkg doesn't have a Debian form, we skip it."
    exit
fi

# Getting RPM version number
if [ -f $pkg/$pkg.spec ]; then
    specfile=$pkg/$pkg.spec
elif [ -f $pkg/$pkg.spec-top ]; then
    specfile=$pkg/$pkg.spec-top
else
    echo "No specfile found for $pkg at $pkg/$pkg.spec"
    exit 1
fi
RPM_VERSION=`awk '/^Version:/ {print $2}' $specfile`

# Getting DEB version number
if [ -f $pkg/debian/changelog ]; then
    changelog=$pkg/debian/changelog
elif [ -f $pkg/*/debian/changelog ]; then
    changelog=$pkg/*/debian/changelog
else
    echo "No changelog file for $pkg found at $pkg/debian/changelog nor at $pkg/$pkg/debian/changelog"
    exit 1
fi
DEBIAN_VERSION=`perl -pe 's/^.* \(([0-9\.]+)(|\+20[0-9]+|~[0-9]+\.rc[0-9]+)-[0-9]+(~bpo[0-9]+\+[0-9]+)?(\+20[0-9]+)?\) .*$/$1/; last if $. > 1' < $changelog`

# Comparing
if [ "$RPM_VERSION" != "$DEBIAN_VERSION" ]; then
    echo "Versions of package $pkg differ: (rpm) $RPM_VERSION ≠ $DEBIAN_VERSION (deb)"
    exit 1
fi

