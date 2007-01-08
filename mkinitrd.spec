#
# spec file for package mkinitrd (Version 1.2)
#
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# norootforbuild

Name:           mkinitrd
License:        GPL
Group:          System/Base
Provides:       aaa_base:/sbin/mk_initrd
Requires:       coreutils modutils util-linux grep e2fsprogs gzip sed gawk cpio udev pciutils sysvinit reiserfs xfsprogs
# bootsplash required only if creating splash initrd's.
Autoreqprov:    on
Version:        1.2
Release:        0
Summary:        Creates an Initial RAM Disk Image for Preloading Modules
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        mkinitrd
Source1:        installkernel
Source3:        mkinitrd.8
Source4:        hotplug.sh
Source5:        ipconfig.sh
Source10:       run-init.c
Source20:       module_upgrade

%description
Mkinitrd creates file system images for use as initial RAM disk
(initrd) images.  These RAM disk images are often used to preload the
block device modules (SCSI or RAID) needed to access the root file
system.

In other words, generic kernels can be built without drivers for any
SCSI adapters that load the SCSI driver as a module.  Because the
kernel needs to read those modules, but in this case is not able to
address the SCSI adapter, an initial RAM disk is used.	The initial RAM
disk is loaded by the operating system loader (normally LILO) and is
available to the kernel as soon as the RAM disk is loaded.  The RAM
disk loads the proper SCSI adapter and allows the kernel to mount the
root file system.



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
gcc -Wall -Os -o run-init run-init.c

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/dev
install -D -m 755 run-init $RPM_BUILD_ROOT/lib/mkinitrd/bin/run-init
install -D -m 755 %{S:0} $RPM_BUILD_ROOT/sbin/mkinitrd
install -D -m 755 %{S:1} $RPM_BUILD_ROOT/sbin/installkernel
install -D -m 755 %{S:20} $RPM_BUILD_ROOT/sbin/module_upgrade
install -D -m 755 %{S:4} $RPM_BUILD_ROOT/usr/share/mkinitrd/hotplug.sh
install -D -m 755 %{S:5} $RPM_BUILD_ROOT/lib/mkinitrd/bin/ipconfig.sh
ln -s mkinitrd $RPM_BUILD_ROOT/sbin/mk_initrd
install -D -m 644 %{S:3} $RPM_BUILD_ROOT/%{_mandir}/man8/mkinitrd.8

%files
%defattr(-,root,root)
%dir /usr/share/mkinitrd
%dir /lib/mkinitrd
%dir /lib/mkinitrd/dev
%dir /lib/mkinitrd/bin
/lib/mkinitrd/bin/run-init
/lib/mkinitrd/bin/ipconfig.sh
/sbin/*
/usr/share/mkinitrd/hotplug.sh
%doc %{_mandir}/man8/mkinitrd.8.gz

%changelog -n mkinitrd
