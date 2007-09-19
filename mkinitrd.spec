#
# spec file for package mkinitrd (Version 2.0)
#
# Copyright (c) 2007 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# norootforbuild

Name:           mkinitrd
License:        GNU General Public License (GPL)
Group:          System/Base
Provides:       aaa_base:/sbin/mk_initrd
#!BuildIgnore:  module-init-tools e2fsprogs udev pciutils reiserfs
Requires:       coreutils modutils util-linux grep gzip sed gawk cpio udev pciutils sysvinit file perl
Autoreqprov:    on
Version:        2.1
Release:        12
Summary:        Creates an Initial RAM Disk Image for Preloading Modules
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        mkinitrd.tgz

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
%setup

%build
gcc $RPM_OPT_FLAGS -Wall -Os -o lib/mkinitrd/bin/run-init src/run-init.c
sed -i "s/@BUILD_DAY@/`env LC_ALL=C date -ud yesterday '+%Y%m%d'`/" sbin/mkinitrd

%install
mkdir -p $RPM_BUILD_ROOT/usr/share/mkinitrd
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/dev
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/scripts
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/setup
mkdir -p $RPM_BUILD_ROOT/lib/mkinitrd/boot
cp -a scripts $RPM_BUILD_ROOT/lib/mkinitrd
cp -a lib/mkinitrd/bin $RPM_BUILD_ROOT/lib/mkinitrd/bin
make -C sbin DESTDIR=$RPM_BUILD_ROOT install
chmod -R 755 $RPM_BUILD_ROOT/lib/mkinitrd
install -D -m 644 man/mkinitrd.5 $RPM_BUILD_ROOT/%{_mandir}/man5/mkinitrd.5
install -D -m 644 man/mkinitrd.8 $RPM_BUILD_ROOT/%{_mandir}/man8/mkinitrd.8
ln -s mkinitrd $RPM_BUILD_ROOT/sbin/mk_initrd
mkdir -p $RPM_BUILD_ROOT/etc/rpm
cat > $RPM_BUILD_ROOT/etc/rpm/macros.mkinitrd <<EOF
#
# Update links for mkinitrd scripts
#
%install_mkinitrd   /usr/bin/perl /sbin/mkinitrd_setup
EOF

%post
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
/lib/mkinitrd/scripts/*
/lib/mkinitrd/bin/*
/sbin/mkinitrd
/sbin/mk_initrd
/sbin/mkinitrd_setup
/sbin/module_upgrade
/sbin/installkernel
%doc %{_mandir}/man5/mkinitrd.5.gz
%doc %{_mandir}/man8/mkinitrd.8.gz

%changelog
* Tue May 29 2007 - agraf@suse.de
- Include optional busybox support (activate with -f busybox)
  (#276555)
- Suppress useless warnings in resume features
* Thu May 24 2007 - agraf@suse.de
- Resolve persistent device names for non-root-devices
- Split resume into userspace and kernel resume
- Proper error handling if anything goes wrong
* Tue May 22 2007 - agraf@suse.de
- Fixed sysconfig/kernel support again
- Made mkinitrd abort more often if anything goes wrong
- Always set md's start_ro flag to 1
* Mon May 21 2007 - agraf@suse.de
- Added a warning if fsck was not found
- Fixed to load sysconfig/kernel modules
* Mon May 21 2007 - agraf@suse.de
- Beautified the initrd boot output
- Removed unused modules when using IDE / SCSI
- Minor variable escaping fixes
* Mon May 21 2007 - agraf@suse.de
- added missing shebang entries
* Fri May 11 2007 - agraf@suse.de
- Modularize mkinitrd (FATE #302106)
- Partly rewrite to create a slick and clean structure
  (FATE #302106)
- Include storage device layering detection to resolve device
  dependencies (FATE #302106)
- Uses persistent device names internally (FATE #302106)
- Add LUKS support (FATE #301182)
- Add USB support (incl. HID)
- Add Firewire support
- Netconsole support (#162494)
- Add support for a "monster"-initrd which includes all features
  available
- Add verbose output switch
* Fri Mar 23 2007 - hare@suse.de
- Create module path if it doesn't exist (#255816)
- Do not parse options for filesystem modules (#246524)
- Support resume from LVM2 (#249460)
- Support resume from EVMS2 (#246494)
* Wed Mar 21 2007 - hare@suse.de
- Call evms with -b to omit error messages (#246631)
- Enable asynchronous target scan again after initrd is finished
- Detect LVM2 volume group correctly (#256285)
* Mon Mar 19 2007 - hare@suse.de
- Fixup regex for block_driver (#255384)
- Login into all iSCSI ports (#248495)
- Disable asynchronous target scan for FC (#241945)
* Mon Mar 12 2007 - hare@suse.de
- Do not use /usr/bin/tail for the block_driver function (#244148)
* Mon Mar 12 2007 - hare@suse.de
- Rewrite EVMS handling to fix initialisation errors (#244148)
* Mon Mar 05 2007 - hare@suse.de
- Include dasdinfo and new DASD udev rules (#222326, #245342)
* Fri Feb 23 2007 - hare@suse.de
- Sync with fixes from SLES10 SP1.
* Mon Feb 12 2007 - uli@suse.de
- worked around what appears to be a shell bug (bug #244554)
* Wed Jan 31 2007 - olh@suse.de
- fix lib/lib64 detection on ia64/alpha
* Fri Jan 19 2007 - hare@suse.de
- Obey settings from /etc/sysconfig/bootsplash (#230839)
* Fri Nov 24 2006 - olh@suse.de
- declare variables as local in udev_discover_root/udev_discover_resume
* Fri Nov 24 2006 - olh@suse.de
- nfsroot must be passed as root=server:/directory, either via
  cmdline or fstab. Just *:* as rootdev match string does not mean
  nfsroot, it will also trigger for /dev/disk/ symlinks
  update udev_discover_root and the root= parser to look at *:/*
* Fri Nov 24 2006 - olh@suse.de
- remove real-root-dev usage, it came back with the sles10 merge
  its a writeonly variable for unused prepare_namespace()
* Fri Nov 24 2006 - olh@suse.de
- remove the /dev/root case from udev_discover_root again (#215240)
  udev_check_for_device must be called always. sbp2 and usb-storage
  have async probing.
* Thu Nov 23 2006 - hare@suse.de
- Fixup EVMS detection.
* Thu Nov 16 2006 - olh@suse.de
- use BuildIgnore to reduce build requires
* Thu Nov 16 2006 - hare@suse.de
- Update iscsi boot support
* Thu Nov 16 2006 - olh@suse.de
- declare loop variable i as local in mkinitrd_kernel
  otherwise the global loop variable i used for the list of
  available kernels/initrds gets overwritten (#221288)
* Thu Nov 16 2006 - hare@suse.de
- Removed rootmd feature again. Wrong approach
- Fixed dmraid detection (#220765)
* Mon Nov 13 2006 - bwalle@suse.de
- added rootmd in feature list (-f), fixes #218167
* Fri Nov 10 2006 - bwalle@suse.de
- fixed mkinitrd uml hostfs support (#215240)
* Tue Nov 07 2006 - bwalle@suse.de
- porting changes from SLES 10 branch to HEAD:
- Add multipath compat rules for udev (#218172)
- Really fix SCSI device ordering (#213641)
- Fixup DASD device ordering (#202182)
- Check return values from lspci (#213400)
- Properly check for whitespaces in output of 'lvs' (#216117)
- Include all multipath prio callout programs (#211863)
- Fixup zfcp device ordering (#213641)
- Enable md detection when booting from lilo (#211089)
- Fixup netmask generation for static IP setup.
- Strip duplicate md devices (#192039)
- fixed #218116 - mkinitrd broke root=/dev/disk/by-*/* on LVM
- fixed #218119 - mkinitrd requires a parameter for -P (contrary to help text)
* Sat Nov 04 2006 - olh@suse.de
- keep local modifications to mkinitrd/ipconfig scripts (#113539)
* Sat Nov 04 2006 - olh@suse.de
- skip resume of resumedev is empty
* Thu Nov 02 2006 - trenn@suse.de
- Also allow SSDT[0-9]?.aml files to be placed to initrd root dir
  to let the BIOS provided ones be overridden
* Tue Oct 31 2006 - olh@suse.de
- require file for elf detection
* Tue Oct 31 2006 - olh@suse.de
- use RPM_OPT_FLAGS
* Tue Oct 31 2006 - olh@suse.de
- reduce build requires
* Sat Oct 28 2006 - olh@suse.de
- ldd exits early if ld.so fails on one of the passed binaries
* Thu Oct 26 2006 - olh@suse.de
- use ELF type for lib/lib64 decision
* Thu Oct 26 2006 - olh@suse.de
- do the chmod 755 in cp_bin to fix suid binaries early
* Mon Oct 16 2006 - hare@suse.de
- Escape 'mdadm' to avoid error messages
- Only use '-C' for fsck if we're on the console (#121946)
* Mon Oct 16 2006 - agruen@suse.de
- Make sure to always include the module for the root filesystem
  if the root filesystem is modularized.
* Sun Oct 15 2006 - olh@suse.de
- handle LABEL=/UUID= from fstab correctly with empty /proc/cmdline
* Tue Oct 10 2006 - olh@suse.de
- /sys/power/resume is optional
* Tue Oct 10 2006 - olh@suse.de
- -M needs an argument, broken by IDE scan changes
* Thu Oct 05 2006 - hare@suse.de
- Include all executables from /lib/mkinitrd/bin
  (FATE 300884)
* Fri Sep 29 2006 - aj@suse.de
- Copy libgcc_s into the lib directory and not to /
* Thu Sep 28 2006 - hare@suse.de
- Fix detection of LVM devices (208417)
- Do not include md modules if not required.
- Don't print annoying 'File descriptor XX left open' messages
* Tue Sep 26 2006 - seife@suse.de
- Update userspace suspend support.
- Protect calls to hwinfo and kpartx (206423)
- Add '-C' to fsck options (121946)
- Hardcode libgcc_s.so.1 (204930)
* Wed Sep 20 2006 - schwab@suse.de
- Fix dmraid detection.
* Tue Sep 19 2006 - hare@suse.de
- Only enable dmraid when the respective binaries are installed.
* Sun Sep 17 2006 - seife@suse.de
- add missing double quotes in the detection of the userspace
  resume device (found by Robert Schiele, bug #206368.
- correct the major/minor numbers for /dev/{u,}random.
* Wed Sep 13 2006 - seife@suse.de
- add the possibility to resume from userspace suspend.
* Wed Sep 13 2006 - aj@suse.de
- Add requirement on hwinfo.
* Wed Sep 06 2006 - hare@suse.de
- Make IDE scan configurable; defaults to off
* Thu Aug 31 2006 - hare@suse.de
- Detect dmraid devices
- Do not call kpartx directly, called via udev now
* Thu Aug 24 2006 - olh@suse.de
- add code to detect if system time is older than build time
* Thu Aug 24 2006 - olh@suse.de
- remove udev version requirement to keep mkinitrd sles10 compatible
* Wed Aug 23 2006 - olh@suse.de
- remove static binary handling. ash can not deal with added array
  usage and static module-init-tools are larger than shared ones.
* Wed Aug 23 2006 - olh@suse.de
- remove readlink function, binary exists since 8.2 and it breaks
  syntax highlighting in vim
* Wed Aug 23 2006 - olh@suse.de
- remove special handling for init args, use the kernel provided args
* Fri Aug 11 2006 - fink@suse.de
- Run blogd within initramfs
* Tue Aug 08 2006 - hare@suse.de
- Always load all md modules if md is activated
- Detect EVMS volumes correctly (#188511)
* Wed Aug 02 2006 - hare@suse.de
- Fixup boot from md. Do not rely on the on-disk
  mdadm.conf as the information might be errorneous.
  Better create an internal one based upon the current
  settings (#178199)
- Fixup booting from lvm on top of md (#192039)
* Wed Aug 02 2006 - olh@suse.de
- remove redundant output in /init script
* Thu Jul 27 2006 - hare@suse.de
- Fix cut&paste error in UUID= rules.
* Wed Jul 26 2006 - hare@suse.de
- Add udev requirement for correct update (#189713)
- Fixup udev rules for lilo etc. (#192725)
* Fri Jul 14 2006 - olh@suse.de
- remove real-root-dev usage
  its a writeonly variable for unused prepare_namespace()
* Tue Jun 27 2006 - hare@suse.de
- Check for nfs last; persistent device names might
  contain ':'.
- Use 'module' link to get the correct module name for
  network modules
- Fixup detection of EVMS installations (#188511)
* Tue Jun 13 2006 - hare@suse.de
- Get correct network parameter during installation
  of root on iSCSI (#184393)
* Tue Jun 13 2006 - hare@suse.de
- Fixup path names for udev helper binaries.
* Wed Jun 07 2006 - hare@suse.de
- Revert changes for kdump; broke default installation
  (#182341)
* Thu Jun 01 2006 - hare@suse.de
- Fix script error for root on iSCSI (#178054)
- Build additional initrds for kdump (#176908)
- Do not pass xfs quota options on remount (#177096)
- Fix syntax error in parsing of udev_timeout (#178106)
- Fix spelling errors (#177918)
- Enable DHCP mode for root on iSCSI.
- Include 64bit EVMS modules, too (#179860)
- Add 64-device-mapper.rules for udev (#175972)
* Tue May 30 2006 - hare@suse.de
- Overhaul root on multipath (#176818)
* Mon May 22 2006 - hare@suse.de
- Add dm-mod to domu-modules if required (#177467)
- Parse 'ro' commandline option (#177599)
* Mon May 22 2006 - hare@suse.de
- Handle persistent device names correctly if
  LVM is activated (#175972)
* Fri May 19 2006 - hare@suse.de
- Configure network interfaces automatically if
  root device is an iSCSI device (#176804)
* Thu May 18 2006 - hare@suse.de
- Configure S/390 CTC devices properly.
- Start iSCSI connections properly (#176804)
* Tue May 16 2006 - hare@suse.de
- Fix iSCSI root (#175191)
- Fix feature list expansion (#175602)
* Mon May 15 2006 - hare@suse.de
- Fix improper condition in mkinitrd (#94586).
* Mon May 08 2006 - garloff@suse.de
- Add option u: also to the getopts call (#166921).
* Sun May 07 2006 - olh@suse.de
- add some hints about nfsroot to the manpage
* Sun May 07 2006 - olh@suse.de
- update the description of mkinitrd in the man page
* Sun May 07 2006 - olh@suse.de
- update -k and -i description in manpage
* Sun May 07 2006 - olh@suse.de
- use the sysfs modalias file when looking for a network driver
  the driver symlink does not always match the kernel module name
* Sun May 07 2006 - olh@suse.de
- add nfs module if nfsroot is detected
* Tue Apr 25 2006 - olh@suse.de
- add more raid personalities based on mdstat and mdadm.conf
  (#168518, #166239)
* Mon Apr 24 2006 - hare@suse.de
- Generate correct initrd for Xen (#168115)
* Sat Apr 22 2006 - olh@suse.de
- remove the requirement for expr, except for evms, bash does math
* Sat Apr 22 2006 - olh@suse.de
- mkinitrd does not work if /usr is unavailable, exit early
* Fri Apr 21 2006 - olh@suse.de
- remove selinux support, it references non-existant files in /usr
* Fri Apr 21 2006 - olh@suse.de
- remove +s bits from mount to allow mkinitrd as unprivileged user
* Fri Apr 21 2006 - olh@suse.de
- include fsck binary if fstab root mountpoint contains colons
* Fri Apr 21 2006 - olh@suse.de
- consider bootsplash only on DOS compatibles
* Thu Apr 20 2006 - olh@suse.de
- remove dead code in /init script, rootdevn serves no purpose
* Thu Apr 20 2006 - olh@suse.de
- fix typo in lvm2 detection, better lvdisplay output parsing
* Thu Apr 20 2006 - olh@suse.de
- remove hardcoded /dev/md0 to allow root on md1 and above (#164600)
* Wed Apr 19 2006 - olh@suse.de
- escape udev_timeout variable
* Wed Apr 19 2006 - olh@suse.de
- use correct udevsettle option syntax
* Tue Apr 18 2006 - olh@suse.de
- handle unexpected mdadm -Db /dev/md0 output correctly for raid5 (#164600)
* Thu Apr 13 2006 - trenn@suse.de
- added sysvinit and reiserfs to "Requires" packages
* Wed Apr 12 2006 - hare@suse.de
- consistent usage of iscsi_root (#165456)
* Tue Apr 11 2006 - hare@suse.de
- Increase udev timeout to 30 seconds.
* Fri Apr 07 2006 - hare@suse.de
- Use the udevsettle program instead of shell scripts (#163010)
* Wed Apr 05 2006 - hare@suse.de
- Fixed typo in s390_dasd_sysfs (#156152)
* Tue Apr 04 2006 - garloff@suse.de
- Put DOMU_INITRD_MODULES into xen initrds and load them rather
  than driver_modules in a Xen domU.
* Fri Mar 31 2006 - hare@suse.de
- Get splash sizes from framebuffer, too (#141098)
* Thu Mar 23 2006 - hare@suse.de
- Always check for mounted /proc and /sys (#151879)
* Wed Mar 22 2006 - hare@suse.de
- Display correct DASD discipline (#156152 - LTC22264)
- Include correct udev rule.
* Mon Mar 20 2006 - hare@suse.de
- Add '-f' option to enable additional features
  (#157678 - LTC22362, #130696)
* Fri Mar 17 2006 - hare@suse.de
- use /sbin/udevtrigger instead of shell logic (#148043)
* Tue Mar 14 2006 - hare@suse.de
- Check for the rootfstype to select which fsck to include
- Unset CDPATH for compability with old installation.
* Thu Mar 09 2006 - hare@suse.de
- Add mpath_id program for multipathing (#149995 - LTC21557)
- Dropping into a shell if the rootfstype is invalid (#154284)
- Fix booting from USB devices (#155857)
* Wed Mar 01 2006 - hare@suse.de
- Fix boot from LVM over software RAID (#152237)
- Fixup LVM default settings (#152790)
* Tue Feb 28 2006 - hare@suse.de
- Do not try to kill iscsid if it's not running (#153374)
* Tue Feb 21 2006 - hare@suse.de
- Fix remount call (#151424)
* Sun Feb 19 2006 - agruen@suse.de
- Use new options of /sbin/update-bootloader. This updates the
  bootloader for us, so no need to call /sbin/new-kernel-pkg
  anymore.
- /sbin/new-kernel-pkg is now obsolete; drop it (#148393)
* Fri Feb 17 2006 - hare@suse.de
- Update root on iSCSI handling for open-iscsi (#146890)
- Load network module automatically.
* Thu Feb 16 2006 - hare@suse.de
- Rewrote static device configuration (#147882)
- Added documentation for all kernel commandline parameter.
* Sun Feb 12 2006 - cthiel@suse.de
- link run-init dynamically, because glibc is in initrd anyway
* Wed Feb 08 2006 - hare@suse.de
- Add 05-udev-early.rules (#148818)
- Fix parsing of dasd= parameter (#145198 - LTC20909)
- Fix journal handling (#148474)
* Mon Feb 06 2006 - hare@suse.de
- corrected an error for invalid rootfstype (#142847)
- Rewrote md activation (#147795)
- Parse /etc/fstab to update mount parameters.
* Fri Feb 03 2006 - agruen@suse.de
- Never add a bootsplash for kernel flavors kdump, um, xen*.
* Thu Feb 02 2006 - hare@suse.de
- Wrong initialisation for LVM (#147415)
* Wed Feb 01 2006 - hare@suse.de
- Do not try to rewrite symlink if mkinitrd fails (#145888)
- Clean up all directories on failure
- Rewrite '-b' and '-a' arguments as run_init would otherwise
  try to interpret them.
* Mon Jan 30 2006 - hare@suse.de
- Try for mdadm first as raidstart is deprecated (#146304)
* Mon Jan 30 2006 - hare@suse.de
- Do not use read() on /proc/devices (#146095).
- LVM2 also requires a call to vgchange (#146095).
* Wed Jan 25 2006 - mls@suse.de
- converted neededforbuild to BuildRequires
* Wed Jan 25 2006 - hare@suse.de
- new-kernel-pkg: Remove code for updating zipl.conf,
  is now handled by the new perl-bootloader.
- mkinitrd: Remove udevstart reference.
* Tue Jan 24 2006 - hare@suse.de
- Fix journal handling
- Copy QLogic firmware into the initramfs
* Mon Jan 23 2006 - hare@suse.de
- Update iscsi handling.
* Thu Jan 19 2006 - hare@suse.de
- Add handling of external journal (Feature ID #300179).
* Fri Jan 13 2006 - hare@suse.de
- Rework device detection.
  We're now waiting for udev to settle before checking for rootfs.
- MD Integration. Should now work properly with md.
* Fri Dec 23 2005 - kay.sievers@suse.de
- don't mount /dev "noexec", X can't mmap() video BIOS with /dev/mem
* Mon Dec 19 2005 - hare@suse.de
- Add '-V' to fsck (#121946)
- Enable 'start_ro' for md devices (#
- Pass all arguments to init (#132122)
* Fri Dec 16 2005 - hare@suse.de
- Run udevd within initramfs
- Set the correct mode for /dev/shm (#138451)
- Implement root on multipath (Feature ID #235, #110256).
* Mon Dec 05 2005 - hare@suse.de
- Add '-M' to specify non-standard System.map file (#118554)
* Mon Dec 05 2005 - kay.sievers@vrfy.org
- Remove klibc support; glibc is now mandatory
- Fix udev support
* Fri Nov 18 2005 - hare@suse.de
- Removed initrd support; initramfs is now mandatory
- Removed pivot_root, unneccessary now
- Fixed spec file and manpage
* Fri Nov 11 2005 - hare@suse.de
- Fix mount --move to really have /dev on tmpfs
- Add devnumber script as we're now having bash.
* Mon Nov 07 2005 - hare@suse.de
- Default to glibc binaries
- udev is now mandatory
- Add run-init program
- events are not stored anymore
* Mon Oct 17 2005 - fehr@suse.de
- fix problem handling devices in subdir of /dev in fstab when
  root fs is on evms (#119140)
* Mon Sep 12 2005 - agruen@suse.de
- Also include and load kernel modules for additional storage
  controllers other than the last (115930). This affects multi-
  controller systems when upgrading only.
* Fri Sep 09 2005 - hare@suse.de
- Raise device timeout to 10 secs (#116101).
* Thu Sep 08 2005 - hare@suse.de
- Fixed installation permissions (#114849).
* Wed Sep 07 2005 - agruen@suse.de
- Consolidate the code that copies modules into the initrd.
- modprobe unresolved instead of resolved modules so that modprobe
  will go through the usual rules when loading.
- Add $module.* parameters from the kernel command line for
  filesystem modules, too.
* Wed Sep 07 2005 - agruen@suse.de
- Switch from using insmod to modprobe: modprobe will
  fetch module parameters from modprobe.conf, so we don't need to
  add them by hand.
- Add a version of /bin/true: modprobe.conf might use it.
* Wed Sep 07 2005 - hare@suse.de
- Re-enable scan for IDE devices (#114511)
- Return proper error codes (#115374)
- Fix NFS-root (#87351)
* Mon Sep 05 2005 - hare@suse.de
- Do not run udev rules for which no binaries are present (#115133)
* Mon Sep 05 2005 - agruen@suse.de
- Some modules we generally include in initrds do not exist
  with every kernel configuration. Only try to include modules
  that actually exist.
* Mon Sep 05 2005 - hare@suse.de
- Properly (re-)set $uld_modules (#115217)
- Add comments to mkinitrd.
* Sun Sep 04 2005 - schwab@suse.de
- Filter out empty lines in resolve_modules.
* Sat Sep 03 2005 - agruen@suse.de
- Fix module parameter handling (broken with the #71218 fix).
* Fri Sep 02 2005 - kasievers@suse.de
- read DEV_ON_TMPFS from /etc/sysconfig/kernel (#114400)
  with default yes.
* Sat Aug 27 2005 - cthiel@suse.de
- Fix splash size autodetection (#113573)
* Fri Aug 26 2005 - hare@suse.de
- Add modprobe and modules.dep for proper handling of modules
- Fix mount permissions (#112765)
- Switch off binaries not available during boot (#112820)
* Wed Aug 17 2005 - hare@suse.de
- Pass only valid parameters to init (#104984).
- Remove ROOT= parameter parsing
- Do not evaluate IDE modules if network interface is set (#83782).
* Tue Aug 16 2005 - agruen@suse.de
- Revert change that was meant for the perl-Bootloader code, which
  we are not currently using (fixes 104956).
* Fri Aug 05 2005 - hare@suse.de
- Fix booting with lilo (#100492)
* Mon Jul 25 2005 - hare@suse.de
- Fix booting with dynamic /dev.
- Add udev db directory.
- Make software suspend working again (#97875, #95601)
* Fri Jul 08 2005 - hare@suse.de
- Update to match latest udev program locations.
- Fix nfsroot.
* Tue Jun 21 2005 - agruen@suse.de
- vga mode recognition: during initial installation, mkinitrd is
  called before the bootloader config (e.g., /boot/grub/menu.lst)
  is written. IN that case, also parse the vga= mode setting out
  of /proc/cmdline (91259).
* Fri Jun 17 2005 - hare@suse.de
- Fix even more locations.
- Parse nfsroot= parameter.
* Wed Jun 15 2005 - hare@suse.de
- Fix locations for udev_volume_id and devnumber.
* Wed Jun 15 2005 - hare@suse.de
- Fix locations for hotplugeventrecorder and run_init.
* Tue Jun 14 2005 - hare@suse.de
- Update for new udev program locations.
* Mon May 09 2005 - agruen@suse.de
- module_upgrade: Add script for renaming modules in all system
  config files. This is invoked from the kernel post-install
  script (#47755).
* Mon May 02 2005 - schwab@suse.de
- Initialize fs_modules and drv_modules in each round.
* Thu Mar 31 2005 - hare@suse.de
- Fix booting from DASD on S/390.
* Mon Mar 21 2005 - agruen@suse.de
- Back out unnecessary change "Include boot-time udev rules if
  present (#74013)".
- Fix check for "unknown volume type" result of udev.
- Re-add support for multiple splash images in the same initrd
  (mostly from Michael Schroeder <mls@suse.de>).
* Mon Mar 21 2005 - hare@suse.de
- Include boot-time udev rules if present (#74013).
* Mon Mar 21 2005 - hare@suse.de
- Fix passing of command-line options to the ide driver (#72454)
- Export rootfs filesystem type in ROOTFS_FSTYPE.
* Wed Mar 16 2005 - hare@suse.de
- Check for invalid fs-types
- Add check for root=0xXXX type boot parameter.
* Mon Mar 14 2005 - schwab@suse.de
- Make emergency shell interactive.
* Mon Mar 14 2005 - hare@suse.de
- Fix booting on SCSI machines.
* Mon Mar 14 2005 - hare@suse.de
- Fix glibc usage (#71941)
* Fri Mar 11 2005 - hare@suse.de
- Fix nfs-root.
- Fix rootfs detection for LVM1.
* Fri Mar 11 2005 - agruen@suse.de
- Fix stripping .o and .ko extensions from module names.
* Thu Mar 10 2005 - ro@suse.de
- typo fix "rootfstype" -> "$rootfstype"
* Thu Mar 10 2005 - hare@suse.de
- Fixed dynamic /dev generation.
  If disabled, dynamic devs will be mounted on
  /lib/klibc/dev.
- Separate driver and fs module for clean resume (#71218).
- Attempt fsck of the rootfs if possible.
* Thu Mar 10 2005 - hare@suse.de
- Fix mount by label properly (#65886).
* Wed Mar 09 2005 - hare@suse.de
- Always mount rootfs read-write when using jfs (#67328).
- Ignore modprobe 'install' lines (#71758).
- Update nfs-root.
- Include ahci driver for ICH6 boards (#71758).
- Really fix booting from LVM2.
* Mon Mar 07 2005 - hare@suse.de
- Fixed booting on LVM2 (#67221).
- Try to make umount /dev work.
  (Disabled for now, doesn't work).
* Fri Mar 04 2005 - hare@suse.de
- Added /dev/mdX device nodes (#67221)
* Fri Mar 04 2005 - hare@suse.de
- Export ROOTFS_BLKDEV for boot scripts.
* Thu Mar 03 2005 - hare@suse.de
- Do not load ide-floppy by default.
* Mon Feb 28 2005 - hare@suse.de
- Add device /dev/isdninfo as no-one seems to create it (#66745).
* Mon Feb 28 2005 - hare@suse.de
- Add links to /dev/stdin, /dev/stdout and /dev/stderr (#66841).
* Sun Feb 27 2005 - trenn@suse.de
- correctly add dsdt to initramfs
- corrected manpage -> initramfs default -> -R use initrd
* Wed Feb 23 2005 - hare@suse.de
- Make root=0304 style parameters working again (#66023)
* Mon Feb 21 2005 - agruen@suse.de
- Fix check_ide_modules_pcimap.
* Wed Feb 16 2005 - agruen@suse.de
- Change default to create an initramfs instead of an initrd.
* Mon Feb 14 2005 - agruen@suse.de
- udev_discover_root got broken for root=XXXX and root=XXX
  boot command line parameters as generated by lilo.
- Fix mount by label (#49246).
* Fri Feb 11 2005 - hare@suse.de
- Call hwinfo to find IDE modules.
* Tue Feb 08 2005 - fehr@suse.de
- fix handling of unstable EVMS minor device numbers in initrd (#49277)
* Fri Feb 04 2005 - hare@suse.de
- Add -I for static ethernet configuration.
* Fri Feb 04 2005 - hare@suse.de
- Make initramfs to accept init= parameter (#50455).
* Mon Jan 31 2005 - hare@suse.de
- Remove mkinitramfs symlinks (#50301)
- Add -V for vendor-specific scripts (#50302)
* Mon Jan 31 2005 - hare@suse.de
- Update udev support
- Fix support for custom ACPI DSDT.
* Fri Jan 28 2005 - schwab@suse.de
- make package noarch
* Thu Jan 27 2005 - agruen@suse.de
- Bump version number so that we can require a recent-enough
  version of mkinitrd in kernel-$FLAVOR.rpm.
* Thu Jan 27 2005 - hare@suse.de
- Relax check for DSDT.
* Fri Jan 21 2005 - hare@suse.de
- Make root device discovery by udev optional again as it
  breaks nfs-root.
- Fix module enabling for modularized IDE subsystem.
* Thu Jan 20 2005 - hare@suse.de
- Rearrange dhcp sections to make nfs-root work again.
- Actually include udev as it's always needed.
- Re-add hotplug.sh which is needed for initramfs.
* Sun Dec 12 2004 - olh@suse.de
- drop mkinitramfs
* Mon Nov 08 2004 - agruen@suse.de
- Recognize the sysrq={yes|1} kernel command-line option for
  switching on sysrq earlier during boot-up.
* Mon Nov 08 2004 - olh@suse.de
- mkinitramfs: Fix ldd output parsing
* Thu Oct 28 2004 - olh@suse.de
- mkinitramfs: create /var/run (#34258 - LTC6040)
* Wed Oct 27 2004 - olh@suse.de
- mkinitramfs: fix iscsi root, move udevstart (#34258 - LTC6040)
* Tue Oct 26 2004 - agruen@suse.de
- Fix ldd output parsing (last change was still broken in some
  cases).
- /sbin/udevstart now is a symlink to udev. Copy udev binaries
  so that the symlink will still work.
- Allow to pivot-root mount by UUID (UUID=* was missing in case
  statement).
* Mon Oct 18 2004 - olh@suse.de
- fix syntax error in mkinitramfs-kinit.sh, in nfsroot path
* Mon Oct 18 2004 - agruen@suse.de
- Adapt the regexp for parsing the ldd output to recent changes.
- Add missing s390 case to installkernel.
- Clean up architecture tests. A few other cleanups.
* Sat Oct 16 2004 - olh@suse.de
- use either vmlinux or vmlinuz in installkernel (#39427 - LTC7872)
* Tue Oct 12 2004 - agruen@suse.de
- Revert the last change: It is cleaner to create an empty
  /etc/mtab instead.
* Sun Oct 03 2004 - agruen@suse.de
- Add missing -n options to a few umount invocations.
* Thu Sep 09 2004 - agruen@suse.de
- Create missing /dev/shm directory.
* Fri Sep 03 2004 - olh@suse.de
- mkinitramfs: bind mount /etc/mtab to /proc/1/mounts
* Fri Sep 03 2004 - olh@suse.de
- mkinitramfs: copy the /tmp/net-*.conf files to /dev/nfsroot/
* Fri Sep 03 2004 - olh@suse.de
- mkinitramfs: set the hostname from dhcp reply
* Fri Sep 03 2004 - olh@suse.de
- mkinitramfs: ipconfig writes a /tmp/net-$interface.conf
  source the first one found to fill enviroment with dhcp reply
* Fri Aug 27 2004 - olh@suse.de
- mkinitramfs: create /dev/std{in,out,err} symlinks (#43338)
* Tue Aug 24 2004 - agruen@suse.de
- Remove support for the root_dir parameter: The same effect can
  be achieved by running mkinitrd with chroot inside the real
  root directory.
- Add missing -p flags to mkdirs.
* Sun Aug 22 2004 - olh@suse.de
- mkinitramfs: move mount $udev_root to avoid duplicate entries
  in /proc/self/mounts
* Sun Aug 22 2004 - olh@suse.de
- mkinitramfs: if nfsroot= is given, force root=/dev/nfs
* Sun Aug 22 2004 - olh@suse.de
- mkinitramfs: rearrange the kinit.sh code, mount /dev earlier,
  run mknod earlier, run udev on asynchronous events
  run debug shell before vendor script
* Sun Aug 22 2004 - olh@suse.de
- mkinitramfs: handle ip=*:* case, ipconfig is fixed
* Sun Aug 22 2004 - olh@suse.de
- mkinitramfs: get debug=true from enviroment
* Sat Aug 21 2004 - olh@suse.de
- mkinitramfs: fix typo in help text output
* Sat Aug 21 2004 - olh@suse.de
- mkinitramfs: check if lilo.conf is readable to avoid warning
* Fri Aug 20 2004 - olh@suse.de
- mkinitrd: /run_init must be s static binary because /lib is
  already gone when it runs, take the klibc version
* Fri Aug 20 2004 - olh@suse.de
- mkinitrd: udevinfo.static is in /sbin again
* Thu Aug 12 2004 - hare@suse.de
- Added -g for including glibc binaries instead of klibc ones.
* Mon Aug 02 2004 - hare@suse.de
  Initial update for SL9.2
- Added '-r' to mkinitrd to build initramfs instead of initrd.
- Removed 2.4.X code.
- Enabled udev as default for all modes.
* Mon Aug 02 2004 - hare@suse.de
- #43406: Fix modules loading error on SATA-only machines.
* Wed Jul 28 2004 - olh@suse.de
- mkinitramfs: (#42940 - LTC9911)
  all dev nodes belong to root, according to udev.permissions
  but some may be owned by a group other than root
* Wed Jul 28 2004 - hare@suse.de
- #42958: /sbin/MAKEDEV must be linked into /dev if
  existing.
* Wed Jul 28 2004 - hare@suse.de
- #43352: dasdview was not copied into the initrd;
  scsi modules were copied with no SCSI device present on S/390,
  and a symlink to sed were created with sed already present.
* Thu Jul 01 2004 - agruen@suse.de
- #42696: Lilo passes the root device number as three to four-digit
  hex number. Make mkinitrd recognize the dree-digit case
  correctly.
* Wed Jun 23 2004 - fehr@suse.de
- Add code that makes root filesystem on EVMS possible (#41198)
* Mon Jun 21 2004 - agruen@suse.de
- The udev helper scripts use /lib/klibc/bin/sh as their shell, so
  leave the shell where it comes from, and make /bin/sh a symlink
  to that location.
- Add a number of binaries the used scripts are using.
- Temporarily mount /dev/shm for the udev scripts.
* Sun Jun 20 2004 - agruen@suse.de
- #42250: Fix race when using lvm2 / device mapper / evms root
  file system in combination with udev: Need to wait for udev to
  create /dev/mapper/control.
- Add initrd=trace kernel command line option: turns on command
  tracing in linuxrc start-up script (set -x).
* Fri Jun 18 2004 - agruen@suse.de
- #42171: Always create an initrd. Not having one may create all
  sorts of problems: Bad boot configurations, udev device
  discovery will be missing, and maybe more.
* Fri Jun 18 2004 - agruen@suse.de
- With multiple root= kernel command line options, the last one is
  supposed to count.
- Lilo tries to be clever and strips off the /dev/ prefix from
  device names. Check and fix; this is needed for EVMS root.
- Convert some back-tick quoting to $() quoting.
* Mon Jun 14 2004 - olh@suse.de
- mkinitramfs: mount /proc correctly
* Thu Jun 10 2004 - agruen@suse.de
- #41896: Fix do_chroot.
* Wed Jun 09 2004 - agruen@suse.de
- #41821: mkinitrd / mkiniramfs vga mode scanning bug.
* Tue Jun 08 2004 - hare@suse.de
- Use IFS in a subshell to avoid errors.
* Tue Jun 08 2004 - agruen@suse.de
- #41765: Reset IFS to original value in one place.
- Reset initrd_bins between creating multiple initrds.
* Mon Jun 07 2004 - hare@suse.de
- mkinitrd: add sed to initrd if S/390 zfcp is used (#41484).
* Sat Jun 05 2004 - olh@suse.de
- mkinitramfs: create 32 mdN nodes, create isdninfo,
  remove sleep 3 in nfsmount
* Wed Jun 02 2004 - bk@suse.de
- mkinitrd: write commandline as command line in warning (#41542)
* Wed Jun 02 2004 - hare@suse.de
- mkinitrd: Emit warning if no disks are found (#41542).
* Wed Jun 02 2004 - hare@suse.de
- mkinitrd: Always activate all disks (#41484).
* Wed Jun 02 2004 - olh@suse.de
- mkinitramfs: add raid/lvm support if raid or dm-mod given with -m
* Tue Jun 01 2004 - hare@suse.de
- mkinitrd: Fix EVMS handling on S/390 (#40857).
* Mon May 31 2004 - olh@suse.de
- mkinitramfs: disable 'debug' per default in kinit.sh
* Mon May 31 2004 - olh@suse.de
- mkinitramfs: use modprobe.conf from -b <dir>/etc, if it exits
* Sun May 30 2004 - olh@suse.de
- mkinitramfs: if -m is given, expect that ALL required modules
  are given on cmdline, dont do autodetection for root filesystem
  type and lvm/md/dm in this case
  check also if /proc is mounted, do not fail if not
  this is required if the initrd is built for another host as user
* Sat May 29 2004 - olh@suse.de
- mkinitramfs: remove <() process substitution,
  doesnt work without proc. use 'here document' instead
* Sat May 29 2004 - olh@suse.de
- mkinitramfs: use -b dir in default_kernel_images()
* Sat May 29 2004 - olh@suse.de
- mkinitramfs-kinit.sh:
  remove hardcoded unconditional 42 panic timeout
* Wed May 26 2004 - agruen@suse.de
- #41225: vga mode parsing bug.
* Wed May 26 2004 - olh@suse.de
- mkinitramfs: remove misleading error message. (#39625)
* Tue May 25 2004 - garloff@suse.de
- mkinitrd and mkinitramfs: Find iscsid in either /usr/sbin or
  /sbin.
* Mon May 24 2004 - olh@suse.de
- mkinitramfs: fix nfsroot to take nfsroot=server:/dir
* Mon May 24 2004 - hare@suse.de
- Call devmap_mknod.sh if no udev is running
* Mon May 24 2004 - fehr@suse.de
- load dm-snapshot additionally to dm-mod it is needed for some
  configurations (#41022)
* Mon May 24 2004 - hare@suse.de
- add support for LVM2 as root filesystem for S/390.
* Sun May 23 2004 - olh@suse.de
- mkinitramfs: fix parsing of nfsroot=
* Wed May 19 2004 - garloff@suse.de
- Remove iSCSI TODO comments.
- BLIST_NOREPORTLUN has changed its value in the kernel.
* Thu May 13 2004 - fehr@suse.de
- add support for EVMS volume as root filesystem
* Thu May 13 2004 - hare@suse.de
- new-kernel-pkg: Only call zipl on S/390 if corresponding
  configuration file exists.
* Tue May 11 2004 - agruen@suse.de
- Install Kerntypes in /sbin/installkernel instead of in the
  kernel makefiles: installkernel knows about /boot.
* Sun May 09 2004 - olh@suse.de
- mkinitramfs: guess if root is on lvm
  remove root_dir support. doesnt work as user because chroot
  is required, and root can chroot anyway
  doesnt need any hacks, just write a /bootsplash file (#39902)
* Wed May 05 2004 - agruen@suse.de
- #39824: Fix bootsplash for non-standard resolutions.
- #39893: Remove working directory and its contents.
- Fix for lvm root with grub.
* Mon May 03 2004 - hare@suse.de
- new-kernel-pkg: Fixed embarrasing bug in call to zipl
  (called with -v instead of -V)
* Thu Apr 29 2004 - olh@suse.de
- mkinitramfs:
  handle root on jfs
  put the fs driver for the root filesystem in the initrd, even
  if it is not listed in INITRD_MODULES
* Tue Apr 27 2004 - fehr@suse.de
- mkinitrd: add code to only activate the LVM VG that contains the
  root fs to prevent problems as described in bug #32794
* Fri Apr 23 2004 - garloff@suse.de
- mkinitrd: Add support for new syntax of passing scsi_mod params
  with scsi_mod. prefix. Translate old options, where possible.
* Tue Apr 20 2004 - olh@suse.de
- mkinitramfs changes:
  copy raidautorun
* Mon Apr 19 2004 - olh@suse.de
- mkinitramfs changes:
  detect root on raid correctly
* Sun Apr 18 2004 - olh@suse.de
- mkinitramfs changes:
  workaround chicken/egg bug in mdadm and raidautorun
  they do the ioctl on the not yet existing device node...
* Sat Apr 17 2004 - olh@suse.de
- mkinitramfs changes:
  remove files in initramfs to release memory
  print hint if booted with 'debug'
  be less verbose in mkinitramfs
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
