#!/bin/bash
#
#%stage: filesystem
#%param_j: "Journal device" device journaldev
#
# usage: update_list <id> <list>
update_list() {
    local elem=$1

    shift
    case " $@ " in
        *" $elem "*)
            echo "$@"
            return 0;;
    esac
    echo "$@ $elem"
}

# usage: block_driver <major id>
block_driver() {
    sed -n "/^Block devices:/{n;: n;s/^[ ]*$1 \(.*\)/\1/p;n;b n}" < /proc/devices
}

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

# usage         majorminor <major> <minor>
# returns       the block device name
majorminor2blockdev() {
        local major=${1:-0} minor=$2

        if [ ! "$minor" ]; then
                minor=$(IFS=: ; set -- $major ; echo $2)
                major=$(IFS=: ; set -- $major ; echo $1)
        fi
        if [ $major -lt 0 ] ; then
            return
        fi
        local retval=$(cat /proc/partitions | egrep "^[ ]*$major[ ]*$minor ")
        if [ -z "$retval" ]; then
            echo "WARNING: Partition $major:$minor not available" >&2
            return
        fi
        echo /dev/${retval##* }
}

beautify_blockdev() {
        local olddev="$1" udevdevs dev

        case "$olddev" in
        /dev/md*)
                # setup-md.sh doesn't understand the md-uuid-* symlinks
                echo "$olddev"
                return
        esac
        # search for udev information
        udevdevs=$(udevadm info -q symlink --name=$olddev)
        #   look up ata device links
        for dev in $udevdevs; do
                if [ "$(echo $dev | grep /ata-)" ] ; then
                        echo "/dev/$dev"
                        return
                fi
        done
        #   look up scsi device links
        for dev in $udevdevs; do
                if [ "$(echo $dev | grep /scsi-)" ] ; then
                        echo "/dev/$dev"
                        return
                fi
        done
        #   take the first guess
        for dev in $udevdevs; do
                case "$dev" in
                block/* | root)
                        continue
                        ;;
                *)
                        echo "/dev/$dev"
                        return
                esac
        done

        # get pretty name from device-mapper
        if [ -n "$(type -p dmsetup)" -a "$blockdriver" = "device-mapper" ]; then
            dm_name=$(dmsetup info -c --noheadings -o name -j $blockmajor -m $blockminor)
            if [ "$dm_name" ] ; then
                echo "/dev/mapper/$dm_name"
                return
            fi
        fi

        echo $olddev
}

dm_resolvedeps() {
        local dm_deps dm_dep bd
        local bds="$@"
        [ ! "$bds" ] && bds=$blockdev
        # resolve dependencies
        for bd in $bds ; do
                update_blockdev $bd >&2
                if [ "$blockdriver" = device-mapper ]; then
                        root_dm=1
                        dm_deps=$(dmsetup deps -j $blockmajor -m $blockminor 2> /dev/null)
                        dm_deps=${dm_deps#*: }
                        dm_deps=${dm_deps//, /:}
                        dm_deps=${dm_deps//(/}
                        dm_deps=${dm_deps//)/}
                        for dm_dep in $dm_deps; do
                                majorminor2blockdev $dm_dep
                        done
                else
                        echo -n "$bd "
                fi
        done
        return 0
}

dm_resolvedeps_recursive() {
        local dm_uuid dm_deps dm_dep dm_dep_name bd
        local bds="$@"
        [ ! "$bds" ] && bds=$blockdev
        # resolve dependencies
        for bd in $bds ; do
                update_blockdev $bd >&2
                if [ "$blockdriver" = device-mapper ]; then
                        root_dm=1
                        dm_deps=$(dmsetup deps -j $blockmajor -m $blockminor 2> /dev/null)
                        dm_deps=${dm_deps#*: }
                        dm_deps=${dm_deps//, /:}
                        dm_deps=${dm_deps//(/}
                        dm_deps=${dm_deps//)/}
                        for dm_dep in $dm_deps; do
                                dm_dep_name=$(majorminor2blockdev $dm_dep)
                                if [ -n "$dm_dep_name" ]; then
                                        dm_resolvedeps "$dm_dep_name"
                                fi
                        done
                else
                        echo -n "$bd "
                fi
        done
        [ "$root_dm" = 1 ]
}

# this receives information about the current blockdev so each storage layer has access to it for its current blockdev
update_blockdev() {
        local curblockdev=$1
        [ "$curblockdev" ] || curblockdev=$blockdev
        # no blockdevs
        [ "$curblockdev" ] || return

        blockmajor=-1
        blockminor=-1
        if [ -e "$root_dir/${curblockdev#/}" ]; then
                blockdevn="$(devnumber $root_dir/${curblockdev#/})"
                blockmajor="$(devmajor $blockdevn)"
                if [ ! "$blockmajor" ]; then
                        error 1 "Fatal storage error. Device $curblockdev could not be analyzed."
                fi
                blockminor="$(devminor $blockdevn)"
                blockdriver="$(block_driver $blockmajor)"
                if [ ! "$blockdriver" ]; then
                        error 1 "Fatal storage error. Device $curblockdev does not have a driver."
                fi

                # temporary hack to have devicemapper activated whenever a dm device was found
                if [ "$blockdriver" = device-mapper ]; then
                        tmp_root_dm=1
                fi
        fi

        if false; then
                echo ""
                echo "$curblockdev"
                echo "===================="
                echo ""
                echo "bdev: $blockdev"
                echo "devn: $blockdevn"
                echo "majo: $blockmajor"
                echo "mino: $blockminor"
                echo "driv: $blockdriver"
                echo ""
        fi
}

# usage: resolve_device <device label> <device node>
resolve_device() {
    local type="$1"
    local x="$2"
    local realrootdev="$2"

    case "$realrootdev" in
      LABEL=*|UUID=*)
        # get real root via fsck hack
        realrootdev=$(fsck -N "$realrootdev" \
                      | sed -ne '2s/.* \/dev/\/dev/p' \
                      | sed -e 's/  *//g')
        if [ -z "$realrootdev"  -o ! -b "$realrootdev" ] ; then
            echo "Could not expand $x to real device" >&2
            exit 1
        fi
        realrootdev=$(readlink -m $realrootdev)
        ;;
      /dev/disk/*)
        realrootdev=$(readlink -m $realrootdev)
        ;;
      /dev/md/*)
        realrootdev=$(readlink -m $realrootdev)
        ;;
      *:*|//*)
        [ "$type" = "Root" ] && x="$rootfstype-root"
        ;;
    esac

    # root device was already checked and non-existing
    # non-root device is not fatal, but may not be
    # shown to the following block resolver modules
    [ -b "$realrootdev" ] || exit 0

    [ "$x" != "$realrootdev" ] && x="$x ($realrootdev)"

    # FIXME: we should really print this to stdout
    echo -en "$type device:\t$x" >&2
    if [ "$type" = "Root" ]; then
        echo " (mounted on ${root_dir:-/} as $rootfstype)" >&2
    elif [ "$type" = "/usr" ]; then
        echo " (mounted on ${root_dir:-/}usr as $usrfstype)" >&2
    else
        echo >&2
    fi
    echo $realrootdev
}

##############################################################################

# usage: resolve_mountpoint name path
resolve_mountpoint()
{
    local name=$1 mountpoint=$2
    local var_dev=${name}dev var_fstype=${name}fstype var_fsopts=${name}fsopts
    local var_major=${name}major var_minor=${name}minor
    local dev fstype fsopts mod
    local cpio major minor x1
    local fstab_device fstab_mountpoint fstab_type fstab_options dummy

    cpio=`echo "$mountpoint" | cpio --quiet -o -H newc`
    major="$(echo $(( 0x${cpio:62:8} )) )"
    minor="$(echo $(( 0x${cpio:70:8} )) )"

    if [ -z "${!var_dev}" ] ; then
        # no dev specified, get current opts from /etc/fstab and device from stat

	# check if /usr is part of /
        if test "$name" = "usr" -a "$major:$minor" = "$rootmajor:$rootminor"; then
            return
        fi

        # get opts from fstab and device too if stat failed
        sed -e '/^[ \t]*#/d' < $root_dir/etc/fstab >"$work_dir/pipe"
        while read fstab_device fstab_mountpoint fstab_type fstab_options dummy ; do
          if [ "$fstab_mountpoint" = "$mountpoint" ]; then
            update_blockdev "$fstab_device" # get major and minor
            # let's see if the stat device is the same as the fstab device
            if [ "$major" -eq 0 ] || [ "$blockmajor" -eq "$major" -a "$blockminor" -eq "$minor" ]; then # if both match
              dev="$fstab_device" # use the fstab device so the user can decide
                                  # how to access the device
            fi
            fstype="$fstab_type"
            fsopts="$fstab_options"
            break
          fi
        done < "$work_dir/pipe"

        if [ $((major)) -gt 0 -a -z "$dev" ] ; then
            # don't check for non-device mounts
            dev="$(majorminor2blockdev $major $minor)"
            if [ -z "$dev" ]; then
                error 1 "Cannot determine the $name device"
            fi
            update_blockdev $dev
            dev="$(beautify_blockdev $dev)"
        fi
    else
        dev="${!var_dev}"
    fi

    #if any of the above fails, use whats currently in use for the mountpoint
    if [ -z "$fstype" -a -z "$dev" ] ; then
        grep -E "^[^[:space:]]+ $mountpoint " < /proc/mounts | tail -n 1 > "$work_dir/pipe"
        # get device, type and options from current state
        read dev dummy fstype fsopts dummy < "$work_dir/pipe"
    fi

    #if we don't know where the device belongs to
    if [ -z "$fstype" ] ; then
      # get type from /etc/fstab or /proc/mounts (actually not needed)
      x1=$(cat $root_dir/etc/fstab /proc/mounts 2>/dev/null \
           | grep -E "$dev[[:space:]]" | tail -n 1)
      fstype=$(echo $x1 | cut -f 3 -d " ")
    fi

    # check for journal device
    if [ "$fsopts" -a -z "$journaldev" ] ; then
        jdev=${fsopts#*,jdev=}
        if [ "$jdev" != "$fsopts" ] ; then
            journaldev=${jdev%%,*}
        fi
        logdev=${fsopts#*,logdev=}
        if [ "$logdev" != "$fsopts" ] ; then
            journaldev=${logdev%%,*}
        fi
    fi

    # check for nfs root and set the fstype accordingly
    case "$dev" in
        /dev/nfs)
            fstype=nfs
            ;;
        /dev/*)
            if [ ! -e "$dev" ]; then
                error 1 "$name device ($dev) not found"
            fi
            ;;
        *://*) # URL type
            fstype=${dev%%://*}
            interface=${interface:-default}
            ;;
        scsi:*)
            ;;
        *:*)
            fstype=nfs
            interface=${interface:-default}
            ;;
    esac

    if [ -z "$fstype" ]; then
        eval $(udevadm info -q env -n $dev | sed -n '/ID_FS_TYPE/p' )
        fstype=$ID_FS_TYPE
        [ $? -ne 0 ] && fstype=
        [ "$fstype" = "unknown" ] && $fstype=
        ID_FS_TYPE=
    fi

    if [ ! "$fstype" ]; then
        error 1 "Could not find the filesystem type for $name device $dev

    Currently available -d parameters are:
            Block devices   /dev/<device>
            NFS             <server>:<path>
            URL             <protocol>://<path>"
    fi

    # We assume that we always have to load a module for the fs
    mod=$fstype

    # Check if we have to load a module for the fs type
    # XXX: This check should happen more generically for all modules
    if [ ! "$(find $root_dir/lib/modules/$kernel_version/ -name $fstype.ko -o -name $fstype.ko.gz)" ]; then
        if grep -q ${fstype}_fs_type $map ; then
            # No need to load a module, since this is compiled in
            mod=
        fi
    fi
    # Now save the rootXXX or usrXXX variables

    read $var_dev < <(echo "$dev")
    read $var_fstype < <(echo "$fstype")
    read $var_fsopts < <(echo "$fsopts")
    read $var_major < <(echo "$major")
    read $var_minor < <(echo "$minor")
    rootfsmod="$rootfsmod $mod"
}

resolve_mountpoint root /
resolve_mountpoint usr /usr

# WARNING: dirty hack to get the resume device of the current system
for o in $(cat /proc/cmdline); do
    case "$o" in
    resume=*)
        resumedev=${o##resume=}
        ;;
    esac
done

# blockdev is the list current block devices.
# It will get modified by the various scrips as they descend through
# the device setup, starting with the mount information
# and ending at the block device

fallback_rootdev="$rootdev"
save_var fallback_rootdev
for name in root usr; do
    save_var ${name}dev
    save_var ${name}fsopts
    save_var ${name}fstype
done
save_var resumedev
save_var journaldev
save_var dumpdev
blockdev="$(resolve_device Root $rootdev) $(resolve_device /usr $usrdev) $(resolve_device Resume $resumedev) $(resolve_device Journal $journaldev) $(resolve_device Dump $dumpdev)"

