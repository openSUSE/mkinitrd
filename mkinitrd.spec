#
# spec file for package mkinitrd (Version 1.2)
#
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://www.suse.de/feedback/
#

# norootforbuild

Name:         mkinitrd
License:      GPL
Group:        System/Base
Provides:     aaa_base:/sbin/mk_initrd
Requires:     coreutils modutils util-linux grep e2fsprogs gzip sed gawk cpio udev pciutils
# bootsplash required only if creating splash initrd's.
Autoreqprov:  on
Version:      1.2
Release:      0
Summary:      Creates an initial ramdisk image for preloading modules
BuildRoot:    %{_tmppath}/%{name}-%{version}-build
Source0:      mkinitrd
Source1:      installkernel
Source2:      new-kernel-pkg
Source3:      mkinitrd.8
Source4:      hotplug.sh
Source10:     run-init.c
Source20:     module_upgrade

%description
Mkinitrd creates filesystem images for use as initial ramdisk (initrd)
images.  These ramdisk images are often used to preload the block
device modules (SCSI or RAID) needed to access the root filesystem.

In other words, generic kernels can be built without drivers for any
SCSI adapters which load the SCSI driver as a module.  Since the kernel
needs to read those modules, but in this case it isn't able to address
the SCSI adapter, an initial ramdisk is used.  The initial ramdisk is
loaded by the operating system loader (normally LILO) and is available
to the kernel as soon as the ramdisk is loaded.  The ramdisk loads the
proper SCSI adapter and allows the kernel to mount the root filesystem.



Authors:
--------
    Steffen Winterfeldt <wfeldt@suse.de>
    Susanne Oberhauser <froh@suse.de>
    Bernhard Kaindl <bk@suse.de>
    Andreas Gruenbacher <agruen@suse.de>
    Hannes Reinecke <hare@suse.de>

%prep
cp %{S:10} .

%build
gcc -Wall -Os --static -o run-init run-init.c

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/dev
install -D -m 755 run-init $RPM_BUILD_ROOT/lib/mkinitrd/bin/run-init
install -D -m 755 %{S:0} $RPM_BUILD_ROOT/sbin/mkinitrd
install -D -m 755 %{S:1} $RPM_BUILD_ROOT/sbin/installkernel
install -D -m 755 %{S:2} $RPM_BUILD_ROOT/sbin/new-kernel-pkg
install -D -m 755 %{S:20} $RPM_BUILD_ROOT/sbin/module_upgrade
install -D -m 755 %{S:4} $RPM_BUILD_ROOT/usr/share/mkinitrd/hotplug.sh
ln -s mkinitrd $RPM_BUILD_ROOT/sbin/mk_initrd
install -D -m 644 %{S:3} $RPM_BUILD_ROOT/%{_mandir}/man8/mkinitrd.8

%files
%defattr(-,root,root)
%dir /usr/share/mkinitrd
%dir /lib/mkinitrd
%dir /lib/mkinitrd/dev
%dir /lib/mkinitrd/bin
/lib/mkinitrd/bin/run-init
/sbin/*
/usr/share/mkinitrd/hotplug.sh
%doc %{_mandir}/man8/mkinitrd.8.gz

%changelog -n mkinitrd
