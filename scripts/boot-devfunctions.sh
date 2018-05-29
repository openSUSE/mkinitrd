#!/bin/bash
#
#%stage: boot
#
#%dontshow
#
##### Device functions
##
## This script provides helper functions for major/minor analyzation.
## Usually this should not have to be changed in any way and only exists
## here because I have not found any better place to put it to.
##
## Command line parameters
## -----------------------
##

# Convert a major:minor pair into a device number
# See /usr/src/linux/include/linux/kdev_t.h
mkdevn() {
    local major=$1 minor=$2
    echo $(( ($major * 0x100000) + $minor))  # 0x100000 == 2**20
}

# Extract the major part from a device number
devmajor() {
    local devn=$1
    echo $(( $devn / 0x100000 ))
}

# Extract the minor part from a device number
devminor() {
    local devn=${1:-0}
    echo $(( $devn % 0x100000 ))
}

# (We are using a devnumber binary inside the initrd.)
devnumber() {
    set -- $(ls -lL $1)
    mkdevn ${5%,} $6
}

# Waiting for a device to appear
# device node will be created by udev
check_for_device() {
    local root
    local type
    local retval=1
    local timeout=$udev_timeout
    local dm_major
    local udev_devn
    local udev_major

    root=$1
    type=$2
    if [ "$type" = "root" ] ; then
        dm_major=$root_major
    elif [ "$type" = "resume" ] ; then
        dm_major=$resume_major
    else
        dm_major=
    fi
    # Only do major number matches for udev-managed symlinks
    case "$root" in
	*/disk/by-id/*|*/disk/by-uuid/*|*/disk/by-label/*|*/mapper/*) ;;
	*) dm_major= ;;
    esac
    if [ -n "$root" ]; then
        echo -n "Waiting for device $root to appear: "
        while [ $timeout -gt 0 ]; do
            if [ -e "$root" ]; then
                udev_devn=$(devnumber $root)
                udev_major=$(devmajor $udev_devn)
                if [ -n "$md_major" -a "$udev_major" = "$md_major" ] ; then
                    echo " ok"
                    retval=0
                    break;
                fi
                # Do not wait for dm or mpath if root_no_(dm|mpath)=1 is
                # passed on the kernel commandline (bnc#815185)
                if [ -n "$dm_major" -a -z "$cmd_root_no_dm" ] ; then
                    if [ "$udev_major" == "$dm_major" ] ; then
                        echo " ok"
                        retval=0
                        break;
                    elif [ -x /sbin/multipath -a -z "$cmd_root_no_mpath" ] ; then
                        if [ -n "$vg_root" -a -n "$vg_roots" ] ; then
                            vgchange --sysinit -a n
                        fi
                        echo -n "!"
                        multipath -v0
                        wait_for_events
                        sleep 1
                        timeout=$(( $timeout - 1 ))
                        continue;
                    fi
                else
                    echo " ok"
                    retval=0
                    break;
                fi  
	    elif [ -x /sbin/multipath -a -z "$cmd_root_no_mpath" ] ; then
		echo -n "!"
		multipath -v 0
		wait_for_events
            fi
            sleep 1
            echo -n "."
            timeout=$(( $timeout - 1 ))
            # Recheck for LVM volumes
            if [ -n "$vg_root" -a -n "$vg_roots" ] ; then
                vgscan
                
                for vgr in $vg_root $vg_roots; do
                    vgchange -a y --partial --sysinit $vgr
                done
                wait_for_events
            fi
        done
    fi
    if [ -x /sbin/multipath ] && [ -n "$vg_root" -a -n "$vg_roots" ] ; then
        echo "Resetting LVM for multipath"
        vgchange --sysinit -a n
        multipath -v 0
        wait_for_events
        vgscan
        for vgr in $vg_root $vg_roots; do
            vgchange -a y --partial --sysinit $vgr
        done
        wait_for_events
    fi
    return $retval;
}

