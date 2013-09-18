#
# spec file for package mkinitrd
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
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


Name:           mkinitrd
#!BuildIgnore:  module-init-tools e2fsprogs udev reiserfs fop
BuildRequires:  asciidoc
BuildRequires:  libxslt
%if 0%{?suse_version} >= 1210
BuildRequires:  systemd
%{?systemd_requires}
%endif
Requires:       coreutils
Requires:       cpio
Requires:       file
Requires:       grep
Requires:       gzip
Requires:       modutils
Requires:       perl-Bootloader
Requires:       sed
Requires:       udev
Requires:       util-linux
Requires:       xz
%if 0%{?suse_version} > 1120
Requires:       sbin_init
Requires:       sysvinit-tools
%else
Requires:       sysvinit
%endif
Version:        @@VERSION@@
Release:        0
Conflicts:      udev < 118
Conflicts:      mdadm < 3.3
Requires:       dhcpcd
PreReq:         %fillup_prereq
Summary:        Creates an Initial RAM Disk Image for Preloading Modules
License:        GPL-2.0+
Group:          System/Base
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        mkinitrd.tar.bz2
# Note: the whole package is maintained in this git repository, please
# don't change it in the build service without sending the author a
# pull request or patch first. Otherwise, you risk that your changes will be
# silently overwritten by the next submission.
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
%__cc $RPM_OPT_FLAGS -Wall -Os -o lib/mkinitrd/bin/run-init src/run-init.c
%__cc $RPM_OPT_FLAGS -Wall -Os -o lib/mkinitrd/bin/warpclock src/warpclock.c
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
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/bin
cp -a scripts/*.sh $RPM_BUILD_ROOT/lib/mkinitrd/scripts/
for i in lib/mkinitrd/bin/*
do
    n=`echo $i | sed 's@.sh$@@'`
    cp -a $i $RPM_BUILD_ROOT/$n
done
make -C sbin DESTDIR=$RPM_BUILD_ROOT install
chmod -R 755 $RPM_BUILD_ROOT/lib/mkinitrd
install -D -m 644 man/mkinitrd.5 $RPM_BUILD_ROOT/%{_mandir}/man5/mkinitrd.5
install -D -m 644 man/cmdinitrd.8 $RPM_BUILD_ROOT/%{_mandir}/man8/cmdinitrd.8
install -D -m 644 man/lsinitrd.8 $RPM_BUILD_ROOT/%{_mandir}/man8/lsinitrd.8
install -D -m 644 man/mkinitrd.8 $RPM_BUILD_ROOT/%{_mandir}/man8/mkinitrd.8
mkdir -p $RPM_BUILD_ROOT/etc/rpm
cat > $RPM_BUILD_ROOT/etc/rpm/macros.mkinitrd <<EOF
#
# Update links for mkinitrd scripts
#
%install_mkinitrd   /usr/bin/perl /sbin/mkinitrd_setup
EOF
%if 0%{?suse_version} < 1230
mkdir -p $RPM_BUILD_ROOT/etc/init.d
%if 0%{?suse_version} > 1140
# This file is in aaa_base in older versions
install -m 755 etc/boot.loadmodules $RPM_BUILD_ROOT/etc/init.d/
%endif
install -m 755 etc/purge-kernels.init $RPM_BUILD_ROOT/etc/init.d/purge-kernels
%endif
mkdir -p $RPM_BUILD_ROOT/var/adm/fillup-templates
install -m 644 etc/sysconfig.kernel-mkinitrd $RPM_BUILD_ROOT/var/adm/fillup-templates/

%if 0%{?suse_version} >= 1210
mkdir -p $RPM_BUILD_ROOT/%{_unitdir}/
install -m 644 etc/purge-kernels.service $RPM_BUILD_ROOT/%{_unitdir}/
%endif

%pre
%if 0%{?suse_version} >= 1210
%service_add_pre purge-kernels.service
%endif

%preun
%if 0%{?suse_version} >= 1210
%service_del_preun purge-kernels.service
%endif

%post
%{fillup_only -an kernel}
%if 0%{?suse_version} < 1230
%if 0%{?suse_version} > 1140
%{insserv_force_if_yast /etc/init.d/boot.loadmodules}
%endif
%{fillup_and_insserv -f -Y purge-kernels}
%endif
%if 0%{?suse_version} >= 1230
%{remove_and_set -n kernel MODULES_LOADED_ON_BOOT}
if test -n "${MODULES_LOADED_ON_BOOT}" -a "${MODULES_LOADED_ON_BOOT}" != "no"
then
	mkdir -vp /etc/modules-load.d/
	f=/etc/modules-load.d/MODULES_LOADED_ON_BOOT.conf
	if test -f "${f}"
	then
		echo "${f} already exists. Module list: '${MODULES_LOADED_ON_BOOT}'"
	else
		for mod in ${MODULES_LOADED_ON_BOOT}
		do
			echo "${mod}"
		done > "${f}"
	fi
fi
%endif
%if 0%{?suse_version} >= 1210
%service_add_post purge-kernels.service
%endif

%postun
%insserv_cleanup
%if 0%{?suse_version} >= 1210
%service_del_postun purge-kernels.service
%endif

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
%if 0%{?suse_version} < 1230
%if 0%{?suse_version} > 1140
/etc/init.d/boot.loadmodules
%endif
/etc/init.d/purge-kernels
%endif
%if 0%{?suse_version} >= 1210
%_unitdir/purge-kernels.service
%endif
/lib/mkinitrd/scripts/*.sh
/lib/mkinitrd/bin/*
/bin/cmdinitrd
/bin/lsinitrd
/sbin/mkinitrd
/sbin/mkinitrd_setup
/sbin/module_upgrade
/sbin/installkernel
/sbin/purge-kernels
/var/adm/fillup-templates/sysconfig.kernel-%name
%doc %{_mandir}/man5/mkinitrd.5.gz
%doc %{_mandir}/man8/cmdinitrd.8.gz
%doc %{_mandir}/man8/lsinitrd.8.gz
%doc %{_mandir}/man8/mkinitrd.8.gz

%changelog
