# Define the kmod package name here.
%define kmod_name aufs

# If kversion isn't defined on the rpmbuild line, define it here.
%{!?kversion: %define kversion 2.6.32-358.18.1.el6.aufs.web100.%{_target_cpu}}

Name:			%{kmod_name}-kmod
Version:		2.2
Release:		9%{?dist}.aufs.web100
Group:			System Environment/Kernel
License:		GNUv2
Summary:		%{kmod_name} kernel module(s)
URL:			http://aufs.sourceforge.net/
Source0:		%{kmod_name}-%{version}.tar.gz
Source10:		kmodtool-%{kmod_name}-el6.sh
Patch0:			%{kmod_name}-%{version}.patch
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildRequires:	kernel-devel
BuildRequires:	kernel-headers
BuildRequires:	redhat-rpm-config
Requires:		kernel-headers

# Magic hidden here.
%{expand:%(sh %{SOURCE10} rpmtemplate %{kmod_name} %{kversion} "")}

# Disable the building of the debug package(s).
%define debug_package %{nil}

# Define the filter.
%define __find_requires sh %{_builddir}/%{buildsubdir}/filter-requires.sh

%description
This package provides the %{kmod_name} kernel module(s) for aufs. It is built
to depend upon the specific ABI provided by a range of releases of the same
variant of the Linux kernel and not on any one specific build.

Warning this package requires a custom aufs patched kernel and will not work
without it. Do not install on an unpatched kernel it quite possibly will
cause your system to not boot.

%prep
%setup -q -n %{kmod_name}-%{version}
%patch0 -p1
echo "override %{kmod_name} * weak-updates/%{kmod_name}" > kmod-%{kmod_name}.conf
echo "/usr/lib/rpm/redhat/find-requires | %{__sed} -e '/^kernel.*/d'" > filter-requires.sh

%build
KSRC=%{_usrsrc}/kernels/%{kversion}
%{__make} %{?_smp_mflags} KDIR="${KSRC}"

%install
export INSTALL_MOD_PATH=%{buildroot}
export INSTALL_MOD_DIR=kernel/fs/%{kmod_name}
KSRC=%{_usrsrc}/kernels/%{kversion}
%{__make} install KDIR="${KSRC}"
%{__install} -d %{buildroot}%{_includedir}/linux/
%{__make} install_header KDIR="${KSRC}" DESTDIR="%{buildroot}"
%{__install} -d %{buildroot}%{_sysconfdir}/depmod.d/
%{__install} kmod-%{kmod_name}.conf %{buildroot}%{_sysconfdir}/depmod.d/
%{__install} -d %{buildroot}%{_defaultdocdir}/kmod-%{kmod_name}-%{version}/
%{__install} COPYING %{buildroot}%{_defaultdocdir}/kmod-%{kmod_name}-%{version}/
%{__install} README %{buildroot}%{_defaultdocdir}/kmod-%{kmod_name}-%{version}/
# Set the module(s) to be executable, so that they will be stripped when packaged.
find %{buildroot} -type f -name \*.ko -exec %{__chmod} u+x \{\} \;
# Remove the unrequired files.
%{__rm} -f %{buildroot}/lib/modules/%{kversion}/modules.*

%clean
%{__rm} -rf %{buildroot}

%changelog
* Mon Jul 16 2012 Andrew Sides <asides@es.net> - 2.2-1
- Initial el6 build of the kmod package.
