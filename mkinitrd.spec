#
# spec file for package mkinitrd (Version 2.5.10)
#
# Copyright (c) 2009 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# norootforbuild


Name:           mkinitrd
License:        GPL v2 or later
Group:          System/Base
#!BuildIgnore:  module-init-tools e2fsprogs udev reiserfs fop
BuildRequires:  asciidoc libxslt
Requires:       coreutils modutils util-linux grep gzip sed cpio udev sysvinit-tools sbin_init file perl-Bootloader
AutoReqProv:    on
Version:        @@VERSION@@
Release:        3
Conflicts:      udev < 118
Requires:       dhcpcd
Summary:        Creates an Initial RAM Disk Image for Preloading Modules
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        mkinitrd.tar.bz2
Url:            http://gitorious.org/opensuse/mkinitrd

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
    Alexander Graf <agraf@suse.de>

%prep
%setup

%build
gcc $RPM_OPT_FLAGS -Wall -Os -o lib/mkinitrd/bin/run-init src/run-init.c
gcc $RPM_OPT_FLAGS -Wall -Os -o lib/mkinitrd/bin/warpclock src/warpclock.c
make -C man
sed -i "s/@BUILD_DAY@/`env LC_ALL=C date -ud yesterday '+%Y%m%d'`/" sbin/mkinitrd
echo "Checking scripts:"
if ! bash -n sbin/mkinitrd; then
    exit 1
fi
for script in scripts/*.sh; do
    if ! bash -n $script; then
        exit 1;
	break;
    fi
done

%install
mkdir -p $RPM_BUILD_ROOT/usr/share/mkinitrd
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/dev
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/scripts
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/setup
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/boot
cp -a scripts/*.sh $RPM_BUILD_ROOT/lib/mkinitrd/scripts/
cp -a lib/mkinitrd/bin $RPM_BUILD_ROOT/lib/mkinitrd/bin
make -C sbin DESTDIR=$RPM_BUILD_ROOT install
chmod -R 755 $RPM_BUILD_ROOT/lib/mkinitrd
install -D -m 644 man/mkinitrd.5 $RPM_BUILD_ROOT/%{_mandir}/man5/mkinitrd.5
install -D -m 644 man/mkinitrd.8 $RPM_BUILD_ROOT/%{_mandir}/man8/mkinitrd.8
install -D -m 644 man/lsinitrd.8 $RPM_BUILD_ROOT/%{_mandir}/man8/lsinitrd.8
mkdir -p $RPM_BUILD_ROOT/etc/rpm
cat > $RPM_BUILD_ROOT/etc/rpm/macros.mkinitrd <<EOF
#
# Update links for mkinitrd scripts
#
%install_mkinitrd   /usr/bin/perl /sbin/mkinitrd_setup
EOF

%posttrans
/sbin/mkinitrd_setup

%files
%defattr(-,root,root)
%dir /etc/rpm
%dir /usr/share/mkinitrd
%dir /lib/mkinitrd
%dir /lib/mkinitrd/dev
%dir /lib/mkinitrd/bin
%dir /lib/mkinitrd/scripts
%dir /lib/mkinitrd/boot
%dir /lib/mkinitrd/setup
%config /etc/rpm/macros.mkinitrd
/lib/mkinitrd/scripts/*.sh
/lib/mkinitrd/bin/*
/sbin/mkinitrd
/sbin/mkinitrd_setup
/sbin/lsinitrd
/sbin/module_upgrade
/sbin/installkernel
%doc %{_mandir}/man5/mkinitrd.5.gz
%doc %{_mandir}/man8/mkinitrd.8.gz
%doc %{_mandir}/man8/lsinitrd.8.gz

%changelog
