#
# spec file for package mkinitrd (Version 1.1)
#
# Copyright (c) 2004 SUSE LINUX AG, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://www.suse.de/feedback/
#

# norootforbuild
# neededforbuild  

BuildRequires: aaa_base acl attr bash bind-utils bison bzip2 coreutils cpio cpp cracklib cvs cyrus-sasl db devs diffutils e2fsprogs file filesystem fillup findutils flex gawk gdbm-devel glibc glibc-devel glibc-locale gpm grep groff gzip info insserv kbd less libacl libattr libgcc libselinux libstdc++ libxcrypt m4 make man mktemp module-init-tools ncurses ncurses-devel net-tools netcfg openldap2-client openssl pam pam-modules patch permissions popt procinfo procps psmisc pwdutils rcs readline sed strace syslogd sysvinit tar tcpd texinfo timezone unzip util-linux vim zlib zlib-devel autoconf automake binutils gcc gdbm gettext libtool perl rpm

Name:         mkinitrd
License:      GPL
Group:        System/Base
Provides:     aaa_base:/sbin/mk_initrd
Requires:     coreutils ash modutils util-linux grep e2fsprogs tar gzip sed gawk cpio udev pciutils
# bootsplash required only if creating splash initrd's.
Autoreqprov:  on
Version:      1.1
Release:      0
Summary:      Creates an initial ramdisk image for preloading modules
BuildRoot:    %{_tmppath}/%{name}-%{version}-build
Source:       mkinitrd
Source1:      installkernel
Source2:      new-kernel-pkg
Source3:      mkinitrd.8
Source4:      hotplug.sh

#
# Missing: man page for mkinitrd etc.
#
#

%description
Mkinitrd creates filesystem images for use as initial ramdisk (initrd)
images.  These ramdisk images are often used to preload the block
device modules (SCSI or RAID) needed to access the root filesystem.

In other words, generic kernels can be built without drivers for any
SCSI adapters which load the SCSI driver as a module.  Since the kernel
needs to read those modules, but in this case it isn't able to address
the SCSI adapter, an initial ramdisk is used.  The initial ramdisk is
loaded by the operating system loader (e.g. LILO) and is available
to the kernel as soon as the ramdisk is loaded.  The ramdisk loads the
proper SCSI adapter and allows the kernel to mount the root filesystem.



Authors:
--------
    Steffen Winterfeldt <wfeldt@suse.de>
    Susanne Oberhauser <froh@suse.de>
    Bernhard Kaindl <bk@suse.de>
    Andreas Gruenbacher <agruen@suse.de>
    Hannes Reinecke <hare@suse.de>


%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/sbin
mkdir -p $RPM_BUILD_ROOT/%{_mandir}/man8
cp %SOURCE0 %SOURCE1 %SOURCE2 $RPM_BUILD_ROOT/sbin/
mkdir -p $RPM_BUILD_ROOT/usr/share/mkinitrd
cp %SOURCE4 $RPM_BUILD_ROOT/usr/share/mkinitrd/hotplug.sh
ln -s mkinitrd $RPM_BUILD_ROOT/sbin/mk_initrd
ln -sf mkinitramfs $RPM_BUILD_ROOT/sbin/mkinitramfs
cp %SOURCE3 $RPM_BUILD_ROOT/%{_mandir}/man8

%files
%defattr(755,root,root)
%dir /usr/share/mkinitrd
/sbin/mkinitrd
/sbin/mkinitramfs
/sbin/mk_initrd
/sbin/installkernel
/sbin/new-kernel-pkg
/usr/share/mkinitrd/hotplug.sh
%{_mandir}/man8/mkinitrd.8.gz

%changelog -n mkinitrd
