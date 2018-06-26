# perfSONAR Toolkit Building

This repository contains script to build the NetInstall and Full DVD ISOs of the Toolkit distribution.

## Quickstart
Run the following (replacing VERSION with the version number you want applied to the name of the generated ISOs):

```bash
vagrant up
vagrant ssh
cd /vagrant
./scripts/build_netinstall.sh --arch x86_64 --os-version 7 --ps-version VERSION
./scripts/build_fulldvd.sh --arch x86_64 --chroot /home/vagrant/chroot --os-version 7 --ps-version VERSION
```

## Setting Up Build Environment

The easiest way to create a build environment is using [Vagrant](https://www.vagrantup.com). The repo contains a Vagrantfile with a description of the virtual machine (VM) to create. You can build the VM as follows:

```bash
vagrant up
```

You may login to the VM with the following command:

```bash
vagrant ssh
```

The source gode of the git repo lives in a shared folder under `/vagrant`. It will also create a chroot environment at `/home/vagrant/chroot` on the VM.


## Building the NetInstall

The basic process is as follows:

```bash
./scripts/build_netinstall.sh --arch x86_64 --os-version <6|7> --ps-version VERSION
```

For more detailed instructions see https://github.com/perfsonar/project/wiki/CentOS-ISO-Build-Instructions#building-the-netinstall

## Building the Full DVD

The basic process is as follows:

```bash
./scripts/build_chroot.sh /path/to/chroot <i686|x86_64>
./scripts/build_full_dvd.sh --chroot /path/to/chroot --arch <i386|x86_64> --os-version <6|7> --ps-version VERSION
```

See https://github.com/perfsonar/project/wiki/CentOS-ISO-Build-Instructions

## Pre-releases (Alphas, Release Candidates, etc)
When preparing a pre-release, use the *pre-releases* branch. It is already setup to point at staging repositories. In some cases you may just need to change the version numbers in the following files:

* scripts/build_fulldvd.sh
* scripts/build_netinstall.sh

You should NEVER merge the pre-release branch into the master branch since it contains the staging repos, but you may want to do the reverse to ensure package lists and similar are in sync.


