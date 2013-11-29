#!/bin/bash
#
#%stage: boot
#%programs: usleep
# the following tools will be copied by other boot-*.sh scripts
# multipath
# vgchange
# vgscan
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
    local dm_major
    local udev_devn
    local udev_major
    local -i timeout

    let timeout=$udev_timeout\*40

    root=$1
    type=$2
    if [ "$type" = "root" ] ; then
        dm_major=$root_major
    elif [ "$type" = "resume" ] ; then
        dm_major=$resume_major
    else
        dm_major=
    fi
    if [ -n "$root" ]; then
        echo -n "Waiting for device $root to appear: "
        let halftime=$timeout/2
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
                    elif [ -n "$(type -p multipath)" -a -z "$cmd_root_no_mpath" ] ; then
                        if [ -n "$vg_root" -a -n "$vg_roots" ] ; then
                            vgchange --sysinit -a n
                        fi
                        echo -n "!"
                        multipath -v0
                        wait_for_events
                        usleep 25000
                        let timeout--
                        continue;
                    fi
                else
                    echo " ok"
                    retval=0
                    break;
                fi
            elif [ -x "$(type -p multipath)" -a -z "$cmd_root_no_mpath" ] ; then
                echo -n "!"
                multipath -v 0
                wait_for_events
            fi
            usleep 25000
            ((timeout % 40 == 1)) && echo -n "."
            let timeout--
            if [ "$need_mdadm" = "1" -a "$timeout" -eq "$halftime" ] ; then
                # time to start any newly-degraded md arrays
                mdadm -IRs
            fi
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
    if [ -n "$(type -p multipath)" ] && [ -n "$vg_root" -a -n "$vg_roots" ] ; then
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

