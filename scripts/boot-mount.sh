#!/bin/bash
#
#%stage: filesystem
#%depends: resume
#
#%programs: fsck
#%programs: $rootfsck
#%programs: $usrfsck
#%programs: mkdir
#%programs: mount
#%programs: on_ac_power
#%programs: reboot
#%programs: showconsole
#%programs: sed
#%programs: udevadm
#%if: ! "$root_already_mounted"
#%dontshow
#
##### mounting of the root device
##
## When all the device drivers and other systems have been successfully
## activated and in case the root filesystem has not been mounted yet,
## this will do it and fsck it if neccessary.
##
## Command line parameters
## -----------------------
##
## ro           mount the root device read-only
##

discover_root() {
    local root devn
    case "$rootdev" in
        *:/*) root= ;;
        /dev/nfs) root= ;;
        /dev/*) root=${rootdev#/dev/} ;;
    esac
    if [ -z "$root" ]; then
        return 0
    fi
    if check_for_device $rootdev root ; then
        # Get major:minor number of the device node
        devn=$(devnumber $rootdev)
    fi
    if [ ! "$devn" ]; then
        if [ ! "$1" ]; then
            # try the stored fallback device
            echo \
"Could not find $rootdev.
Want me to fall back to $fallback_rootdev? (Y/n) "
            read y
            if [ "$y" = n ]; then
                return 1
            fi
            rootdev="$fallback_rootdev"
            if ! discover_root x ; then
                return 1
            fi
        else
            return 1
        fi
    fi
    return 0
}

read_only=${cmd_ro}

# And now for the real thing
if ! discover_root ; then
    emergency "not found"
fi

sysdev=$(udevadm info -q path -n $rootdev)
# Fallback if rootdev is not controlled by udev
if [ $? -ne 0 ] && [ -b "$rootdev" ] ; then
    devn=$(devnumber $rootdev)
    maj=$(devmajor $devn)
    min=$(devminor $devn)
    if [ -e /sys/dev/block/$maj:$min ] ; then
        sysdev=$(cd -P /sys/dev/block/$maj:$min ; echo $PWD)
    fi
    unset devn
    unset maj
    unset min
fi
if [ -z "$rootfstype" -a -n "$(type -p udevadm)" -a -n "$sysdev" ]; then
    eval $(udevadm info -q env -p $sysdev | sed -n '/ID_FS_TYPE/p')
    rootfstype=$ID_FS_TYPE
    [ -n "$rootfstype" ] && [ "$rootfstype" = "unknown" ] && rootfstype=
    ID_FS_TYPE=
fi

oacp=$(type -p on_ac_power)
# check filesystem if possible
if [ -z "$rootfstype" ]; then
    emergency "invalid root filesystem"
# skip fsck if running on battery                                                                                                                                         
elif [ -n "${oacp}" ] && ! ${oacp} -q ; then
    echo skipping fsck because running on batteries 
# don't run fsck in the kdump kernel
elif [ -x "$rootfsck" ] && ! [ -s /proc/vmcore ] ; then
    # fsck is unhappy without it
    echo "$rootdev / $rootfstype defaults 1 1" > /etc/fstab
    # Display progress bar if possible
    fsckopts="-V -a"
    [ "$forcefsck" ] && fsckopts="$fsckopts -f"
    console=`showconsole`
    [ "${console##*/}" = "tty1" ] && fsckopts="$fsckopts -C"
    # Check external journal for reiserfs
    [ "$rootfstype" = "reiserfs" -a -n "$journaldev" ] && fsckopts="-j $journaldev $fsckopts"
    fsck -t $rootfstype $fsckopts $rootdev
    # Return the fsck status
    ROOTFS_FSCK=$?
    export ROOTFS_FSCK
    mkdir /run/initramfs
    echo $ROOTFS_FSCK >/run/initramfs/root-fsck
    ROOTFS_FSTYPE=$rootfstype
    export ROOTFS_FSTYPE
    fsck_corrected=$(( $ROOTFS_FSCK & 1 ))
    fsck_reboot=$(( $ROOTFS_FSCK & 2 ))
    fsck_uncorrected=$(( $ROOTFS_FSCK & 4 ))
    fsck_other=$(( $ROOTFS_FSCK & (255 << 3) ))
    if [ $ROOTFS_FSCK -gt 1 ]; then
        if [ $fsck_other -gt 0 ]; then
            echo "fsck reported unhandled exit code: $ROOTFS_FSCK"
            echo "Mounting root device read-only."
            read_only=1
        fi
        if [ $fsck_corrected -gt 0 ]; then
            echo "Filesystem errors corrected."
        fi
        if [ $fsck_reboot -gt 0 ]; then
            echo "System should be rebooted."
        fi
        if [ $fsck_uncorrected -gt 0 ]; then
            emergency "Filesystem errors left uncorrected."
        fi
        if [ $fsck_reboot -gt 0 ]; then
            echo "Rebooting system."
            reboot -d -f
        fi
    else
        if [ "$read_only" ]; then
            echo "fsck succeeded. Mounting root device read-only."
        else
            echo "fsck succeeded. Mounting root device read-write."
        fi
    fi
fi

opt="-o rw"
[ "$read_only" ] && opt="-o ro"

# mount the actual root device on /root
echo "Mounting root $rootdev"
# check external journal
[ "$rootfstype" = "xfs" -a -n "$journaldev" ] && opt="${opt},logdev=$journaldev"
[ "$rootfstype" = "reiserfs" -a -n "$journaldev" ] && opt="${opt},jdev=$journaldev"

# use options from /etc/fstab but allow that to be overwritten by the
# "rootflags" command line
if [ -n "$rootflags" ] ; then
    opt="${opt},$rootflags"
fi
if [ -n "$rootfsopts" ] ; then
    opt="${opt},$rootfsopts"
fi

[ -n "$rootfstype" ] && opt="${opt} -t $rootfstype"
echo mount $opt $rootdev /root
mount $opt $rootdev /root
if [ $? -ne 0 ] ; then
    emergency "could not mount root filesystem"
fi

unset discover_root
