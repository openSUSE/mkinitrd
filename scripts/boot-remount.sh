#!/bin/bash
#
#%stage: filesystem
#%depends: mount
#%programs: mount
#
#%dontshow
#
##### remount root fs if neccessary
##
## This script will search for an init script, parse the
## fstab of the target root filesystem and remount it
## if neccessary
##
## Command line parameters
## -----------------------
##
## init=...             use this file instead of the normal init binary
##

# Look for an init binary on the root filesystem
if [ -n "$init" ] ; then
    if [ ! -x "/root$init" -a ! -L "/root$init" ]; then
        init=
    fi
fi

if [ -z "$init" ] ; then
    for i in /sbin/init /etc/init /bin/init /bin/sh ; do
        if [ ! -x "/root$i" -a ! -L "/root$i" ]; then continue; fi
        init="$i"
        break
    done
fi

if [ -z "$init" ] ; then
    echo "No init found. Try passing init= option to the kernel."
    die 1
fi

function get_options_from_fstab() {
    local fsoptions=$(while read d m f o r; do if [ "$m" == "$1" ] ; then echo $o; fi; done < <(sed -e '/^[ \t]*#/d' < /root/etc/fstab))
    set -- $(IFS=,; echo $fsoptions)
    fsoptions=
    if [ "$read_only" ]; then
        fsoptions=ro
    fi
    while [ "$1" ] ; do
        case $1 in
        *quota)
             if [ "$rootfstype" != "xfs" ] ; then
                if [ "$fsoptions" ] ; then
                    fsoptions="$fsoptions,$1"
                else
                    fsoptions="$1"
                fi
             fi
             ;;
        defaults) ;;
        rw) ;;
        *)
            if [ "$fsoptions" ] ; then
                fsoptions="$fsoptions,$1"
            else
                fsoptions="$1"
            fi
            ;;
        esac
        shift
    done
    echo "$fsoptions"
}


# Parse root mount options
if [ -f /root/etc/fstab ] ; then
    fsoptions=$(get_options_from_fstab "/")
    if [ "$fsoptions" ] ; then
        mount -o remount,$fsoptions $rootdev /root
    fi
fi
