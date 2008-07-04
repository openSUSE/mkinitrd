#!/bin/bash
#
#%stage: setup
#%depends: prepare
#
shebang=/bin/bash

is_xen_kernel() {
    local kversion=$1
    local cfg

    for cfg in ${root_dir}/boot/config-$kversion $root_dir/lib/modules/$kversion/build/.config
    do
	test -r $cfg || continue
	grep -q "^CONFIG_XEN=y\$" $cfg
	return
    done
    test $kversion != "${kversion%-xen*}"
    return 
}

# Check if module $1 is listed in $modules.
has_module() {
    case " $modules " in
	*" $1 "*)   return 0 ;;
    esac
    return 1
}

# Set in the mkinitrd script
save_var build_day
save_var cont
save_var current_day
save_var debug_linuxrc
save_var dev
save_var devflags
save_var devn
save_var devpts
save_var DHCPSIADDR
save_var DHCPSNAME
save_var dmdevs
save_var DNS
save_var DOMAIN
save_var driver
save_var dumpdev
save_var evms_cmd
save_var evms_cont
save_var evmsnum
save_var evms_reg
save_var evms_seg
save_var fbnum
save_var fsckopts
save_var fsoptions
save_var init
save_var interface.info
save_var interface
save_var iSCSI_INITIATOR_NAME
save_var iscsi_pid
save_var iscsiport
save_var iscsiserver
save_var iSCSI_TARGET_IPADDR
save_var iscsitarget
save_var iSCSI_TARGET_NAME
save_var iSCSI_TARGET_PORT
save_var iscsi_tgts
save_var is_kdump
save_var journaldev
save_var kdump_kernel
save_var kernel_cmdline
save_var label
save_var link
save_var macaddress
save_var maj
save_var major
save_var md_dev
save_var md_minor
save_var md_uuid
save_var min
save_var minorhi
save_var minor
save_var mpath_list
save_var mpath_status
save_var need_dmraid
save_var need_mdadm
save_var need_raidstart
save_var node
save_var ns
save_var num
save_var oifs
save_var opt
save_var read_only
save_var read_write
save_var REDIRECT
save_var reg
save_var resumedev
save_var resume_minor
save_var resume_mode
save_var retval
save_var rootdevid
save_var realrootdev
save_var ROOTFS_FSCK
save_var rootfstype
save_var ROOTPATH
save_var root
save_var seg
save_var tblfile
save_var tgt
save_var timeout
save_var tty_driver
save_var uuid

if [ -z "$modules_set" ]; then
    # get INITRD_MODULES from system configuration
    . $root_dir/etc/sysconfig/kernel
    modules="$INITRD_MODULES"
fi

if [ -z "$domu_modules_set" ]; then
    # get DOMU_INITRD_MODULES from system configuration
    . $root_dir/etc/sysconfig/kernel
    domu_modules="$DOMU_INITRD_MODULES"
fi

# Activate features which are eqivalent to modules
if has_module dm-multipath; then
    ADDITIONAL_FEATURES="$ADDITIONAL_FEATURES multipath"
fi

save_var rootdev
root="$rootdev"
save_var root

if is_xen_kernel $kernel_version; then
    RESOLVED_INITRD_MODULES="$modules $domu_modules"
else
    RESOLVED_INITRD_MODULES="$modules"
fi
save_var RESOLVED_INITRD_MODULES
