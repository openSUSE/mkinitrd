#
# spec file for package mkinitrd (Version 2.4)
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# norootforbuild


Name:           mkinitrd
License:        GPL v2 or later
Group:          System/Base
#!BuildIgnore:  module-init-tools e2fsprogs udev reiserfs fop
BuildRequires:  asciidoc
Requires:       coreutils util-linux grep gzip sed cpio udev sysvinit file perl-Bootloader
Requires:       xz
# needed for modprobe --resolve-alias
Requires:       module-init-tools >= 3.11
AutoReqProv:    on
Version:        2.4.2
Release:        1
Conflicts:      udev < 147
Requires:       dhcpcd
Summary:        Creates an Initial RAM Disk Image for Preloading Modules
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        mkinitrd.tar.bz2
Url:            https://github.com/openSUSE/mkinitrd

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
mkdir -p $RPM_BUILD_ROOT/etc/init.d
cp -a scripts $RPM_BUILD_ROOT/lib/mkinitrd
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
install -m 755 etc/purge-kernels.init $RPM_BUILD_ROOT/etc/init.d/purge-kernels

%post
%{fillup_and_insserv -f -Y purge-kernels}

%postun
%insserv_cleanup
if test $1 -eq 0; then
	# Remove the boot and setup symlinks (bnc#892507)
	rm -rf /lib/mkinitrd/{boot,setup}
fi

%posttrans
/sbin/mkinitrd_setup
/sbin/mkinitrd

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
/lib/mkinitrd/scripts/*
/etc/init.d/purge-kernels
/lib/mkinitrd/bin/*
/sbin/mkinitrd
/sbin/mkinitrd_setup
/sbin/lsinitrd
/sbin/module_upgrade
/sbin/installkernel
/sbin/purge-kernels
%doc %{_mandir}/man5/mkinitrd.5.gz
%doc %{_mandir}/man8/mkinitrd.8.gz
%doc %{_mandir}/man8/lsinitrd.8.gz

%changelog
