#
# spec file for package mkinitrd (Version 1.0)
#
# Copyright (c) 2004 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Requires:     coreutils ash modutils util-linux grep e2fsprogs tar gzip sed gawk cpio udev
# bootsplash required only if creating splash initrd's.
Autoreqprov:  on
Version:      1.0
Release:      199
Summary:      Creates an initial ramdisk image for preloading modules
BuildRoot:    %{_tmppath}/%{name}-%{version}-build
Source:       mkinitrd
Source1:      installkernel
Source2:      new-kernel-pkg
Source3:      mkinitrd.8
Source10:     mkinitramfs
Source11:     mkinitramfs-kinit.sh
Source20:     module_upgrade
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
loaded by the operating system loader (normally LILO) and is available
to the kernel as soon as the ramdisk is loaded.  The ramdisk loads the
proper SCSI adapter and allows the kernel to mount the root filesystem.



Authors:
--------
    Steffen Winterfeldt <wfeldt@suse.de>
    Susanne Oberhauser <froh@suse.de>
    Bernhard Kaindl <bk@suse.de>
    Andreas Gruenbacher <agruen@suse.de>


%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/sbin
mkdir -p $RPM_BUILD_ROOT/%{_mandir}/man8
cp %SOURCE0 %SOURCE1 %SOURCE2 %SOURCE20 $RPM_BUILD_ROOT/sbin/
ln -s mkinitrd $RPM_BUILD_ROOT/sbin/mk_initrd
cp %SOURCE3 $RPM_BUILD_ROOT/%{_mandir}/man8
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd
cp -p %{S:11} $RPM_BUILD_ROOT/lib/mkinitrd/kinit.sh
%ifarch ppc ppc64
cp -p %{S:10} $RPM_BUILD_ROOT/sbin/mkinitrd
%else
cp -p %{S:10} $RPM_BUILD_ROOT/sbin/mkinitramfs
%endif

%files
%defattr(755,root,root)
/sbin/mkinitrd
/sbin/mk_initrd
/sbin/installkernel
/sbin/new-kernel-pkg
/sbin/module_upgrade
%{_mandir}/man8/mkinitrd.8.gz
/lib/mkinitrd
%ifnarch ppc ppc64
/sbin/mkinitramfs
%endif

%changelog -n mkinitrd
* Wed Apr 14 2004 - hare@suse.de
- Fixed loading of dasd module if no dasd= parameter is set.
- Configure dasd devices via sysfs for empty dasd= parameter.
* Sun Apr 04 2004 - agruen@suse.de
- Add a missing `fi'.
- Explicitly create udev2 device inodes (--mknodes).
* Sat Apr 03 2004 - agruen@suse.de
- #37290: Fix mkinitrd for root filesystem on lvm on software
  raid; add fallback to scan sysfs if udev fails.
* Fri Apr 02 2004 - hare@suse.de
- mkinitrd: Add support for large device numbers.
* Thu Apr 01 2004 - agruen@suse.de
- Report failure if binaries are not found.
- Add devnumber klibc binary.
- Actually include raidautorun in the initrd.
* Thu Apr 01 2004 - agruen@suse.de
- #32794: Run raidautorun also when the root filesystem is LVM but
  not a RAID, and there are RAIDs configured in the rest of the
  system: Otherwise lvm may wrongly think that the RAID is multipath
  attached storage, and corrupt data.
* Tue Mar 30 2004 - agruen@suse.de
- mkinitrd:
  + Dereference symbolic link in hex_dev_number (fehr@suse.de).
  + Get rid of static device numbers, clean up device number
  checking.
  + Remove -u option (to disable udev); it's mandatory now anyway.
  + Don't run createpartitiondevs (an ash extension) with udev.
  + Small fix for uml.
* Tue Mar 30 2004 - olh@suse.de
- mkinitramfs: add sr_mod to initrd as a workaround for #37943
  create /dev/shm earlier in /init
  copy rm binary and /etc/sysconfig/hardware to initramfs
* Sun Mar 28 2004 - agruen@suse.de
- Added support for S/390 zfcp disks with kernel 2.6
  (hare@suse.de).
- Fix syntax error checking for device mapper; cleanups.
* Thu Mar 25 2004 - agruen@suse.de
- Rework the entire nfs-root/dhcp/pivot-root logic.
- Fix two issues in iscsi support.
- Suport for device-mapper based root files (fehr@suse.de)
- Fix udev/lvm/device-mapper initialization order.
- Don't create static lvm/device-mapper inodes when using udev.
* Mon Mar 22 2004 - agruen@suse.de
- Copy the root filesystem device inode into the initrd only when
  not using udev.
- Don't leave DHCP mode when root=/dev/nfs. Add af_packet module
  that is apparently needed by DHCP.
- Don't use stat(1): it's missing on old distros.
* Fri Mar 19 2004 - hare@suse.de
- Update mkinitrd to use udev for creating device nodes.
- Update mkinitrd to pick up modular IDE drivers.
* Tue Mar 16 2004 - schwab@suse.de
- Fix quoting.
* Tue Mar 16 2004 - hare@suse.de
- Fixed new-kernel-pkg for correctly updating /etc/zipl.conf.
* Tue Mar 09 2004 - olh@suse.de
- mkinitramfs: create nodes for ppp and fb0, no sysfs support yet
* Tue Mar 09 2004 - olh@suse.de
- quote variables in mkinitramfs for here documents
* Tue Mar 09 2004 - olh@suse.de
- add mkinitramfs as mkinitrd on ppc
  mounts /dev as tmpfs, requires 2.6 kernel
* Wed Mar 03 2004 - agruen@suse.de
- A small cleanup in the mkinitrd script.
* Mon Mar 01 2004 - agruen@suse.de
- Clean up vga mode parsing for the boot splash.
- Mount /proc and /sys at the beginning of linuxrc, and unmount
  them at the end.
- Add iscsi support (patch from David Wysochanski
  <davidw@netapp.com> via Kurt Garloff <garloff@suse.de>).
- Update dasd configuration to kernel 2.6.
* Thu Feb 26 2004 - agruen@suse.de
- mkinitrd: Some more quoting fixes.
- new-kernel-pkg: Merging the lilo and elilo branches broke; lilo
  was accidentally invoked in both cases.
* Wed Feb 25 2004 - schwab@suse.de
- Fix syntax error in linuxrc.
* Tue Feb 24 2004 - agruen@suse.de
- mkinitrd: Too much quoting removed in last change.
* Tue Feb 24 2004 - agruen@suse.de
- Clean up the code in several places. Use $(..) instead of `..`.
- Add special case for /dev/cciss/* devices. A better solution is
  required; there are a lot more cases where there is no trivial
  mapping between the device inode under /dev and its sysfs entry.
* Mon Feb 23 2004 - agruen@suse.de
- mkinitrd:
  + Clean up some s390 specific stuff.
  + Add & use do_chroot function.
  + Instead of parsing /etc/modules.conf, parse the output of
  modprobe -c.
- new-kernel-pkg: Merge almost-identical lilo + elilo cases.
* Fri Feb 20 2004 - agruen@suse.de
- mkinitrd: Fix check parsing zipl.conf in s390_dasd().
* Fri Feb 20 2004 - agruen@suse.de
- #34736: Handle whitespace in zipl.conf correctly.
* Mon Feb 16 2004 - hare@suse.de
- Added S/390 zipl support in new-kernel-pkg.
* Mon Feb 02 2004 - agruen@suse.de
- Add device mapper / lvm2 support (from sbose@suse.de).
* Fri Jan 16 2004 - schwab@suse.de
- Run elilo in new-kernel-pkg.
* Fri Dec 05 2003 - hare@suse.de
- Checked out new version from CVS: Removed s390 special case
  for image selection.
* Thu Dec 04 2003 - ro@suse.de
- added manpage mkinitrd.8
* Wed Nov 26 2003 - agruen@suse.de
- Fix a syntax error and the module list info (don't show params).
* Sat Nov 22 2003 - agruen@suse.de
- Re-add patch from Carsten Grohmann (which was accidentally lost
  beacuse it was not committed to the CVS).
* Fri Nov 21 2003 - agruen@suse.de
- Update for 2.6 kernel on s390 and zSeries (hare@suse.de).
- Invoke /sbin/elilo to update the efi partition on ia64.
* Tue Nov 18 2003 - kukuk@suse.de
- Loading SELinux policy: Add patch from Carsten Grohmann for
  better output.
* Tue Nov 11 2003 - agruen@suse.de
- Scan kernel cmdline, and pass scsi parameters to scsi_mod:
  Otherwise no scsi params can be passed on the cmdline.
* Tue Oct 28 2003 - agruen@suse.de
- Add `-C /etc/modprobe.conf' only if this file actually exists:
  The modprobe for 2.6 kernels can also run without a config
  file.
* Mon Oct 27 2003 - agruen@suse.de
- Increase the initial initrd image size: 10000 1k blocks
  is too small for the k_debug kernel.
* Thu Oct 23 2003 - agruen@suse.de
- Fix for #32625: mkinitrd handles `-b /' incorrectly.
- Handle use_selinux like all other flags.
- From snwint@suse.de (+changes from me): Fix bootsplash on SLES8.
- From bk@suse.de: Some zfcp fixes.
* Wed Oct 15 2003 - kukuk@suse.de
- Fix selinux support
- Always use mount/umount -n in initrd
- Always create initrd if selinux support is requested
* Wed Oct 15 2003 - kukuk@suse.de
- Add optional selinux support
* Fri Oct 10 2003 - schwab@suse.de
- Fix typo.
* Fri Oct 10 2003 - agruen@suse.de
- Skip over linux-gate.so.1, which is a library mapped into the
  process by 2.6 kernels.
* Thu Oct 09 2003 - agruen@suse.de
- Fix vga mode parsing (wrongly was taking "ex" for a hex number).
- Use generic versions of libraries: On some systems we have
  generic as well as optimized libraries, but the optimized
  libraries may not work with all kernel versions.
* Thu Oct 02 2003 - bk@suse.de
- fix initrd creation on S/390(only tested w/ dasd, not with zfcp!)
- pass module parameters from /etc/modules.conf to linuxrc
* Wed Oct 01 2003 - schwab@suse.de
- new-kernel-pkg: handle elilo.
* Mon Sep 29 2003 - kukuk@suse.de
- Add %%defattr
* Mon Sep 29 2003 - agruen@suse.de
- There is no mkdir in the initrd: Create all needed directories
  when creating the initrd.  Use `mkdir -p' instead of `mkdir'.
- A minor cleanup.
* Tue Sep 23 2003 - agruen@suse.de
- The previous change from using killall to kill was incomplete
  (kill is located in /bin; killall is in /usr/bin).
- Temporary mount shm to /etc/lvmtab.d to create space for lvm
  commands (#26073).
- Add some changes that got lost with the previous update.
* Fri Sep 19 2003 - agruen@suse.de
- new-kernel-pkg: Change /dev/stderr to &2 -- otherwise it fails
  in build envs.
* Thu Sep 18 2003 - kraxel@suse.de
- linuxrc does rootfs device scan via sysfs after loading the
  modules.  2.6.x kernels only, fixes bug #30771.
* Tue Sep 16 2003 - agruen@suse.de
- Add missing $root_dir prefixes, and replace some remaining
  occurrences of `/boot' with $boot_dir.
- Prevent readlink macro from printing an error message for missing
  files (the "real" readlink also fails without messages).
- Add xfs_dmapi and xfs_support to the list of modules that may
  be missing without causing an error (they no longer exist).
- Add md to list of introduced modules.
- temporarly mount shm to /etc in the linuxrc script to have more
  space available for lvm commands (#26073).
* Thu Sep 04 2003 - agruen@suse.de
- Add xfs_dmapi and xfs_support to the list of modules that may
  be missing without causing an error (they no longer exist).
- Fix typo, add md to list of introduced modules, minor clean-ups.
* Mon Sep 01 2003 - agruen@suse.de
- Put mkinird script under cvs control, and remove the inconsistent
  change log that used to be part of the script. The repository
  location is: /suse/yast2/cvsroot/mkinitrd/.
- Remove now-obsolete oem resize support.
* Mon Sep 01 2003 - mls@suse.de
- dhcp: allow servername in rootpath (#29791)
* Sun Aug 31 2003 - agruen@suse.de
- Fix broken check: mount, umount and the surrounding files were
  missing in initrd's.
* Wed Aug 27 2003 - agruen@suse.de
- Prevent mkinitrd warnings for scsi_mod and sd_mod, which may
  have been added to INITRD_MODULES implicitly after a kernel
  update.
- Another minor fix in the ACPI DSDT code.
* Tue Aug 26 2003 - agruen@suse.de
- Clean up ACPI DSDT code.
- Add internal option use_static_binaries than can be turned off
  to use dynamically linked binaries (for bug hunting).
- Fix for systems that don't have a modprobe.old binary.
* Mon Aug 25 2003 - ro@suse.de
- fix syntax error in last change
* Fri Aug 22 2003 - trenn@suse.de
- Added support to attach an DSDT (acpi) to the initrd
  there will exist a kernel option soon, to load a DSDT from
  the initrd and substitute the DSDT from the BIOS.
  The compiled DSDT can be indicated either in /etc/sysconfig/kernel for permanent
  load or the path to the DSDT can be given to mkinitrd  via the -a parameter
* Thu Aug 14 2003 - agruen@suse.de
- Don't depend on /usr/bin/readlink utility: it is not present
  on older distributions.
* Fri Aug 08 2003 - agruen@suse.de
- Automatically also require sd_mod (SCSI disk) if scsi_mod is
  required: It is reasonable to assume that the root file system
  is on a SCSI disk in that case.
* Fri Aug 08 2003 - agruen@suse.de
- Fix a check in mkinird script: No need to invoke initrd on
  /boot/vmlinuz if that file is a symlink.
- Update mkinitrd help text.
* Tue Aug 05 2003 - agruen@suse.de
- Don't call rpm from inside mkinitrd: mkinitrd is itself called
  from rpm in the binary kernel packages; recursive rpm is not
  possible.
- Fix bugs if mkinitrd is called with a different root directory.
- Unclutter mkinitrd's output.
- #28484: Use kill instead of killall in the initrd in the dhcp
  specific code: killall apparently would require an additional
  shared library.
* Thu Jul 31 2003 - agruen@suse.de
- Fix heuristic for recognizing installed kernel RPMs and their
  binary image files.
- If /boot/vmlinuz is a symlink to /boot/vmlinuz-$VERSION and
  /boot/initrd is a regular file, replace /boot/initrd with a
  symbolic link to /boot/initrd-$VERSION when creating that
  initrd image. This ensures that /boot/vmlinuz and /boot/initrd
  belong to the same kernel.
* Mon Jul 28 2003 - agruen@suse.de
- Fix test which version of modprobe to use (was testing
  for 2.5.*).
* Wed Jul 16 2003 - kraxel@suse.de
- fix creation of mk_initrd link.
* Wed Jul 02 2003 - kraxel@suse.de
- build initrds for all installed kernel rpms.
- fix 2.5.x issues.
* Fri Jun 06 2003 - agruen@suse.de
- new-kernel-pkg was in DOS file format: How did *that* happen ??
- mkinitrd:
  + Recognize correctly if no modules are being used.
  + Pipe config file to depmod via stdin so chroot doesn't matter.
* Fri Jun 06 2003 - schwab@suse.de
- Handle LOADER_TYPE elilo.
- Fix syntax errors.
* Wed Jun 04 2003 - agruen@suse.de
- Merge in improved mkinitrd script. There are a number of
  comments tagged with FIXME that seem unclear to me.
* Tue Jun 03 2003 - stepan@suse.de
- Get bootsplash theme name dynamically from sysconfig file.
  This obsoletes SuSEconfig.bootsplash
* Mon May 26 2003 - agruen@suse.de
- Remove initial install vs. upgrade logic from new-kernel-pkg
  script. This is better dealt with in the k_* spec files. Invoke
  new-kernel-pkg script with the version of the kernel as $1
  (e.g., "2.4.20-99-default").
- Adjust installkernel script to new-kernel-pkg changes.
* Thu May 22 2003 - agruen@suse.de
- Split /sbin/mk_initrd from aaa_base.
- New /sbin/installkernel that is used be `make install' in the
  kernel sources.
- New /sbin/new-kernel-pkg scripts that kicks the boot loader
  (mainly lilo) after the kernel/initrd image has changed.
