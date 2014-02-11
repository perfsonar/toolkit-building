# $Id: aufs.spec 335 2010-05-27 20:13:36Z throck $
# $URL: https://buildhost.eng.mcnc.org/svn/packages/aufs-0.20090202.cvs/aufs.spec $
# -------------------------------------------------------------------------------------------
#
# How to build for normal kernel
#
#  rpmbuild -ba --target i686   --define 'kernel 2.6.18-92.el5' aufs.spec
#  rpmbuild -ba --target x86_64 --define 'kernel 2.6.18-92.el5' aufs.spec
#
# How to build for normal kernel and XEN kernel
#
#  rpmbuild -ba --target i686   --define 'kernel 2.6.18-92.el5' --define 'buildxen 1' aufs.spec
#  rpmbuild -ba --target x86_64 --define 'kernel 2.6.18-92.el5' --define 'buildxen 1' aufs.spec
#
# How to build for normal kernel and PAE kernel
#
#  rpmbuild -ba --target i686   --define 'kernel 2.6.18-92.el5' --define 'buildPAE 1' aufs.spec
#  rpmbuild -ba --target x86_64 --define 'kernel 2.6.18-92.el5' --define 'buildPAE 1' aufs.spec
#
# How to build for all kernel (normal, xen, PAE)
#
#  rpmbuild -ba --target i686   --define 'kernel 2.6.18-92.el5' --define 'buildall 1' aufs.spec
#  rpmbuild -ba --target x86_64 --define 'kernel 2.6.18-92.el5' --define 'buildall 1' aufs.spec
#
#
# How to build for the running kernel:
#
#  rpmbuild -ba --target i686   aufs.spec
#  rpmbuild -ba --target x86_64 aufs.spec
#
# -------------------------------------------------------------------------------------------


#
%define buildall 1

%{!?buildxen:%define buildxen 0}
%{!?buildPAE:%define buildPAE 0}

%{?buildall:%define buildxen 1}
%{?buildall:%define buildPAE 1}

%ifarch x86_64
%define buildPAE 0
%endif

%{?!kernel:%define kernel %(rpm -q kernel-devel | tail -1 | sed -e 's|kernel-devel-||')}

%define kversion %(echo "%{kernel}" | sed -e 's|-.*||')
%define krelease %(echo "%{kernel}" | sed -e 's|.*-||')

%define kernel_src_path %{_usrsrc}/kernels/%{kernel}-%{_target_cpu}
%define kernel_xen_src_path %{_usrsrc}/kernels/%{kernel}-xen-%{_target_cpu}
%define kernel_PAE_src_path %{_usrsrc}/kernels/%{kernel}-PAE-%{_target_cpu}

%define kernel_moduledir /lib/modules/%{kernel}
%define kernel_xen_moduledir /lib/modules/%{kernel}xen
%define kernel_PAE_moduledir /lib/modules/%{kernel}PAE

%define pkg_name aufs
%define kmdl_name kernel-module-%{pkg_name}-%{kernel}

# -------------------------------------------------------------------------------------------

### CVS Download
# cvs -d :pserver:anonymous@aufs.cvs.sourceforge.net:/cvsroot/aufs login   (empty password)
# cvs -z3 -d :pserver:anonymous@aufs.cvs.sourceforge.net:/cvsroot/aufs co -P aufs
# find aufs -name "CVS" | xargs rm -rf
#
# CVS checkout date

%define		cvs_date	20090202

Summary: 	Another Unionfs
Name: 		%{pkg_name}
Version: 	0.%{cvs_date}.cvs
Release: 	9%{?dist}
Epoch: 		0
License: 	GPL
Group: 		System Environment/Kernel
Source0: 	aufs-cvs-%{cvs_date}.tar.gz
Source1:	aufs-unionctl.static
# el5 kernel knows cpup_blksize, like kernel >= 2.6.19
Patch0:	        aufs-cpup_blksize_2.patch
# el5 kernel knows struct_path , like kernel >= 2.6.20
Patch1:		aufs-struct_path.patch
URL: 		http://aufs.sourceforge.net
BuildRoot: 	%{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires:       kernel-module-%{pkg_name} >= %{version}-%{release}
BuildRequires: 	kernel-devel = %{kernel}
%if %{buildxen}
BuildRequires: 	kernel-xen-devel = %{kernel}
%endif
%if %{buildPAE}
BuildRequires: 	kernel-PAE-devel = %{kernel}
%endif

%description
Aufs is a stackable unification filesystem such as Unionfs, 
which unifies several directories and provides a merged single 
directory. Aufs was entirely re-designed and re-implemented 
Unionfs. After many original ideas, approaches and improvements, 
it becomes totally different from Unionfs while keeping the 
basic features. See Unionfs for the basic features.

Kernel modules for aufs are in kernel-module-%{pkg_name} rpms.

%package -n 	%{kmdl_name}
Summary:        kernel modules for %{name}.
Group:          System Environment/Kernel
License:        GPL
Provides:       kernel-module-%{pkg_name} = %{epoch}:%{version}-%{release}
Requires:       %{pkg_name}

%description -n %{kmdl_name}
Kernel modules for %{name}.

%if %{buildxen}
%package -n 	%{kmdl_name}xen
Summary: 	xen kernel modules for %{name}.
Group: 		System Environment/Kernel
License: 	GPL
Provides:	kernel-module-%{pkg_name} = %{epoch}:%{version}-%{release}
Requires:	%{pkg_name}

%description -n %{kmdl_name}xen
XEN kernel modules for %{name}.
%endif

%if %{buildPAE}
%package -n 	%{kmdl_name}PAE
Summary: 	PAE kernel modules for %{name}.
Group: 		System Environment/Kernel
License: 	GPL
Provides:	kernel-module-%{pkg_name} = %{epoch}:%{version}-%{release}
Requires:	%{pkg_name}

%description -n %{kmdl_name}PAE
PAE kernel modules for %{name}.
%endif

%prep
%setup -q -n aufs-cvs-%{cvs_date}

%patch0 -p1 -b .cpup.h
%patch1 -p1 -b .vfsub.h

%build
echo -e "\nDriver version: %{version}\nKernel version: %{kernel}\n"

### kernel
make clean KDIR=%{kernel_src_path} -f local.mk
make KDIR=%{kernel_src_path} -f local.mk
INST_MODLIB="${RPM_BUILD_ROOT}/lib/modules/%{kernel}/kernel"
mkdir -p "${INST_MODLIB}/fs/aufs"
install -p -m 744 fs/aufs/aufs.ko "${INST_MODLIB}/fs/aufs/"

### install util and man page
mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/sbin
mkdir -p ${RPM_BUILD_ROOT}/%{_mandir}/man5

cp -a util/aufind.sh   ${RPM_BUILD_ROOT}/%{_prefix}/sbin
cp -a util/aulchown    ${RPM_BUILD_ROOT}/%{_prefix}/sbin
cp -a util/auplink     ${RPM_BUILD_ROOT}/%{_prefix}/sbin
cp -a util/mount.aufs  ${RPM_BUILD_ROOT}/%{_prefix}/sbin
cp -a util/umount.aufs ${RPM_BUILD_ROOT}/%{_prefix}/sbin
# cp -a util/unionctl    ${RPM_BUILD_ROOT}/%{_prefix}/sbin

cp -a util/aufs.5      ${RPM_BUILD_ROOT}/%{_mandir}/man5


### XEN kernel
%if %{buildxen}

make clean KDIR=%{kernel_src_path} -f local.mk
make KDIR=%{kernel_xen_src_path} -f local.mk
INST_MODLIB="${RPM_BUILD_ROOT}/lib/modules/%{kernel}xen/kernel"
mkdir -p "${INST_MODLIB}/fs/aufs"
install -p -m 744 fs/aufs/aufs.ko "${INST_MODLIB}/fs/aufs/"

%endif

### PAE kernel
%if %{buildPAE}

make clean KDIR=%{kernel_src_path} -f local.mk
make KDIR=%{kernel_PAE_src_path} -f local.mk
INST_MODLIB="${RPM_BUILD_ROOT}/lib/modules/%{kernel}PAE/kernel"
mkdir -p "${INST_MODLIB}/fs/aufs"
install -p -m 744 fs/aufs/aufs.ko "${INST_MODLIB}/fs/aufs/"

%endif

### build statically linked unionctl (for LiveCD with busybox)
#    unionctl is a script - no statically linked version needed
#    re-wrote unionctl in order that it works in busybox
#    command rev is needed

cp -a %{SOURCE1} ${RPM_BUILD_ROOT}/%{_prefix}/sbin/unionctl.static


%install
echo


%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%postun -n %{kmdl_name}
depmod -a %{kernel} >/dev/null 2>&1 || :	

%post -n %{kmdl_name}
depmod -a %{kernel} >/dev/null 2>&1 || :

%if %{buildxen}
%postun -n %{kmdl_name}xen
depmod -a %{kernel}xen >/dev/null 2>&1 || :

%post -n %{kmdl_name}xen
depmod -a %{kernel}xen >/dev/null 2>&1 || :
%endif

%if %{buildPAE}
%postun -n %{kmdl_name}PAE
depmod -a %{kernel}PAE >/dev/null 2>&1 || :

%post -n %{kmdl_name}PAE
depmod -a %{kernel}PAE >/dev/null 2>&1 || :
%endif


%files 
%defattr(-,root,root,-)
%doc COPYING History README
%{_prefix}/sbin/*
%{_mandir}/man5/*

%files -n %{kmdl_name}
%defattr(-,root,root,-)
/lib/modules/%{kernel}/kernel/fs/aufs

%if %{buildxen}
%files -n %{kmdl_name}xen
%defattr(-,root,root,-)
/lib/modules/%{kernel}xen/kernel/fs/aufs
%endif

%if %{buildPAE}
%files -n %{kmdl_name}PAE
%defattr(-,root,root,-)
/lib/modules/%{kernel}PAE/kernel/fs/aufs
%endif


%changelog
* Thu Sep 23 2010 Tom Throckmorton <throck@mcnc.org> - 0.20090202.cvs-9
- rebuild for 2.6.18-194-11.4

* Sun Aug 15 2010 Tom Throckmorton <throck@mcnc.org - 0.20090202.cvs-8
- rebuild for 2.6.18-194-11.1

* Thu May 27 2010 Tom Throckmorton <throck@mcnc.org> - 0.20090202.cvs-8
- clean up spec for rebuilding via mock

* Mon Feb 02 2009 Urs Beyerle <urs.beyerle@env.ethz.ch>  0.20090202.cvs-6
- update to latest CVS version 2009-02-02
- add aufs-struct_path.patch

* Thu Jun 05 2008 Urs Beyerle <urs.beyerle@psi.ch>  0.20080605.cvs-5
- update to CVS version 2008-06-05

* Mon Apr 14 2008 Urs Beyerle <urs.beyerle@psi.ch>  0.20080414.cvs-5
- update to CVS version 2008-04-14

* Mon Oct 01 2007 Urs Beyerle <urs.beyerle@psi.ch>  0.20070210.cvs-4
- fix make clean to allow building for another kernel than the running kernel

* Wed Apr 25 2007 Urs Beyerle <urs.beyerle@psi.ch>  0.20070210.cvs-3.slp5
- do not build PAE kernel module on x86_64

* Mon Feb 12 2007 Urs Beyerle <urs.beyerle@psi.ch>  0.20070210.cvs-2.slp5
- add unionctl.static as SOURCE2
  unionctl which runs inside busybox

* Sat Feb 10 2007 Urs Beyerle <urs.beyerle@psi.ch>  0.20070210.cvs-1.sl5.psi
- intial build
