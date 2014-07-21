#
# spec file for package mkinitrd
#
# Copyright (c) 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Version:        2.8.1
Release:        0
Summary:        Creates an Initial RAM Disk Image for Preloading Modules
License:        GPL-2.0+
Group:          System/Base
# Note: the whole package is maintained in this git repository, please
# don't change it in the build service without sending the author a
# pull request or patch first. Otherwise, you risk that your changes will be
# silently overwritten by the next submission.
Url:            https://github.com/openSUSE/mkinitrd
Source0:        %{name}.tar.bz2
#!BuildIgnore:  module-init-tools e2fsprogs udev reiserfs fop
BuildRequires:  asciidoc
BuildRequires:  libxslt
Requires:       coreutils
Requires:       cpio
Requires:       dhcpcd
Requires:       file
Requires:       grep
Requires:       gzip
Requires:       modutils
Requires:       perl-Bootloader
Requires:       sed
Requires:       udev
Requires:       util-linux
Requires:       xz
PreReq:         %fillup_prereq
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Conflicts:      udev < 118
Conflicts:      mdadm < 3.3
%if 0%{?suse_version} >= 1210
BuildRequires:  systemd
%{?systemd_requires}
%endif
%if 0%{?suse_version} > 1120
Requires:       sbin_init
Requires:       sysvinit-tools
%else
Requires:       sysvinit
%endif

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
%setup -q

%build
gcc %{optflags} -Wall -Os -o lib/%{name}/bin/run-init src/run-init.c
gcc %{optflags} -Wall -Os -o lib/%{name}/bin/warpclock src/warpclock.c
make -C man %{?_smp_mflags}
sed -i "s/@BUILD_DAY@/`env LC_ALL=C date -ud yesterday '+%Y%m%d'`/" sbin/%{name}
echo "Checking scripts:"
if ! bash -n sbin/%{name}; then
    exit 1
fi
for script in scripts/*.sh; do
    if ! bash -n $script; then
        exit 1;
        break;
    fi
done

%install
## create folders
mkdir -p %{buildroot}%{_datadir}/%{name}
mkdir -p %{buildroot}/lib/%{name}/{bin,boot,dev,scripts,setup}
cp -a scripts/*.sh %{buildroot}/lib/%{name}/scripts/
for i in lib/%{name}/bin/*
do
    n=`echo $i | sed 's@.sh$@@'`
    cp -a $i %{buildroot}/$n
done
make -C sbin DESTDIR=%{buildroot} install
chmod -R 755 %{buildroot}/lib/%{name}
install -D -m 644 man/%{name}.5 %{buildroot}/%{_mandir}/man5/%{name}.5
install -D -m 644 man/cmdinitrd.8 %{buildroot}/%{_mandir}/man8/cmdinitrd.8
install -D -m 644 man/lsinitrd.8 %{buildroot}/%{_mandir}/man8/lsinitrd.8
install -D -m 644 man/%{name}.8 %{buildroot}/%{_mandir}/man8/%{name}.8
## create folder
mkdir -p %{buildroot}%{_sysconfdir}/rpm
cat > %{buildroot}%{_sysconfdir}/rpm/macros.%{name} <<EOF
#
# Update links for mkinitrd scripts
#
%install_mkinitrd   %{_bindir}/perl /sbin/%{name}_setup
EOF
%if 0%{?suse_version} < 1230
## create folder
mkdir -p %{buildroot}%{_sysconfdir}/init.d
%if 0%{?suse_version} > 1140
# This file is in aaa_base in older versions
install -m 755 etc/boot.loadmodules %{buildroot}%{_initddir}/
%endif
install -m 755 etc/purge-kernels.init %{buildroot}%{_initddir}/purge-kernels
%endif
## create folder
mkdir -p %{buildroot}%{_localstatedir}/adm/fillup-templates
install -m 644 etc/sysconfig.kernel-%{name} %{buildroot}%{_localstatedir}/adm/fillup-templates/

%if 0%{?suse_version} >= 1210
## create folder
mkdir -p %{buildroot}/%{_unitdir}/
install -m 644 etc/purge-kernels.service %{buildroot}/%{_unitdir}/
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
%{insserv_force_if_yast %{_initddir}/boot.loadmodules}
%endif
%{fillup_and_insserv -f -Y purge-kernels}
%endif
%if 0%{?suse_version} >= 1230
%{remove_and_set -n kernel MODULES_LOADED_ON_BOOT}
if test -n "${MODULES_LOADED_ON_BOOT}" -a "${MODULES_LOADED_ON_BOOT}" != "no"
then
	mkdir -vp %{_sysconfdir}/modules-load.d/
	f=%{_sysconfdir}/modules-load.d/MODULES_LOADED_ON_BOOT.conf
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
/sbin/%{name}_setup
/sbin/%{name}

%files
%defattr(-,root,root)
%dir %{_sysconfdir}/rpm
%dir %{_datadir}/%{name}
%dir /lib/%{name}
%dir /lib/%{name}/dev
%dir /lib/%{name}/bin
%dir /lib/%{name}/scripts
%dir /lib/%{name}/boot
%dir /lib/%{name}/setup
%config %{_sysconfdir}/rpm/macros.%{name}
%if 0%{?suse_version} < 1230
%if 0%{?suse_version} > 1140
%{_initddir}/boot.loadmodules
%endif
%{_initddir}/purge-kernels
%endif
%if 0%{?suse_version} >= 1210
%{_unitdir}/purge-kernels.service
%endif
/lib/%{name}/scripts/*.sh
/lib/%{name}/bin/*
/bin/cmdinitrd
/bin/lsinitrd
/sbin/%{name}
/sbin/%{name}_setup
/sbin/module_upgrade
/sbin/installkernel
/sbin/purge-kernels
%{_localstatedir}/adm/fillup-templates/sysconfig.kernel-%{name}
%doc %{_mandir}/man5/%{name}.5.gz
%doc %{_mandir}/man8/cmdinitrd.8.gz
%doc %{_mandir}/man8/lsinitrd.8.gz
%doc %{_mandir}/man8/%{name}.8.gz

%changelog
