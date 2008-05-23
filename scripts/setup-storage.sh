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
mkdevn() {
    local major=$1 minor=$2 minorhi minorlo
    major=$(($major * 256))
    minorhi=$(($minor / 256))
    minorlo=$(($minor % 256))
    minor=$(($minorhi * 256 * 4096))
    echo $(( $minorlo + $major + $minor ))
}

# Extract the major part from a device number
devmajor() {
    local devn=$(($1 / 256))
    echo $(( $devn % 4096 ))
}

# Extract the minor part from a device number
devminor() {
    local devn=${1:-0}
    echo $(( $devn % 256 )) 
}

# (We are using a devnumber binary inside the initrd.)
devnumber() {
    set -- $(ls -lL $1)
    mkdevn ${5%,} $6
}

# usage		majorminor <major> <minor>
# returns	the block device name
majorminor2blockdev() {
	local major=$1 minor=$2

	if [ ! "$minor" ]; then
		minor=$(IFS=: ; set -- $major ; echo $2)
		major=$(IFS=: ; set -- $major ; echo $1)
	fi
	if [ $major -lt 0 ] ; then
	    return
	fi
	local retval=$(cat /proc/partitions | egrep "^[ ]*$major[ ]*$minor ")
	echo /dev/${retval##* }
}

beautify_blockdev() {
	local olddev="$1" udevdevs dev
	
	# search for udev information
	udevdevs=$(/sbin/udevadm info -q symlink --name=$olddev)
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
		echo "/dev/$dev"
		return
	done
	
	# get pretty name from device-mapper
	if [ -x /sbin/dmsetup -a "$blockdriver" = "device-mapper" ]; then
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
			dm_deps=$(dmsetup deps -j $blockmajor -m $blockminor)
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
	local dm_uuid dm_deps dm_dep bd
	local bds="$@"
	[ ! "$bds" ] && bds=$blockdev
	# resolve dependencies
	for bd in $bds ; do
		update_blockdev $bd >&2
		if [ "$blockdriver" = device-mapper ]; then
			root_dm=1
			dm_deps=$(dmsetup deps -j $blockmajor -m $blockminor)
			dm_deps=${dm_deps#*: }
			dm_deps=${dm_deps//, /:}
			dm_deps=${dm_deps//(/}
			dm_deps=${dm_deps//)/}
			for dm_dep in $dm_deps; do
				dm_resolvedeps $(majorminor2blockdev $dm_dep)
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

    # root device was already checked and non-existing
    # non-root device is not fatal, but may not be
    # shown to the following block resolver modules
    [ -b "$realrootdev" ] || exit 0

    case "$realrootdev" in
      LABEL=*|UUID=*)
	# get real root via fsck hack
	realrootdev=$(fsck -N "$rootdev" \
		      | sed -ne '2s/.* \/dev/\/dev/p' \
		      | sed -e 's/  *//g')
	if [ -z "$realrootdev" ] ; then
	    echo "Could not expand $x to real device" >&2
	    exit 1
	fi
	realrootdev=$(/usr/bin/readlink -m $realrootdev)
	;;
      /dev/disk/*)
	realrootdev=$(/usr/bin/readlink -m $realrootdev)
	;;
      *:*|//*)
        [ "$type" = "Root" ] && x="$rootfstype-root"
	;;
    esac

    [ "$x" != "$realrootdev" ] && x="$x ($realrootdev)"

    # FIXME: we should really print this to stdout
    echo -en "$type device:\t$x" >&2
    if [ "$type" = "Root" ]; then
	echo " (mounted on ${root_dir:-/} as $rootfstype)" >&2
    else
	echo >&2
    fi
    echo $realrootdev
}

#######################################################################################

if [ -z "$rootdev" ] ; then
  # no rootdev specified, get current root opts from /etc/fstab and device from stat
  
  # get rootdev via stat
  rootcpio=`echo / | /bin/cpio --quiet -o -H newc`
  rootmajor="$(echo $(( 0x${rootcpio:62:8} )) )"
  rootminor="$(echo $(( 0x${rootcpio:70:8} )) )"

  # get opts from fstab and device too if stat failed
  while read fstab_device fstab_mountpoint fstab_type fstab_options dummy ; do
    if [ "$fstab_mountpoint" = "/" ]; then
      update_blockdev "$fstab_device" # get major and minor
      # let's see if the stat device is the same as the fstab device
      if [ "$rootmajor" -eq 0 ] || [ "$blockmajor" -eq "$rootmajor" -a "$blockminor" -eq "$rootminor" ]; then # if both match
	rootdev="$fstab_device" # use the fstab device so the user can decide
                                # how to access the root device
      fi
      rootfstype="$fstab_type"
      rootfsopts="$fstab_options"
      break
    fi
  done < <(sed -e '/^[ \t]*#/d' < $root_dir/etc/fstab)

  if [ $((rootmajor)) -gt 0 -a -z "$rootdev" ] ; then
      # don't check for non-device mounts
      rootdev="$(majorminor2blockdev $rootmajor $rootminor)"
      update_blockdev $rootdev
      rootdev="$(beautify_blockdev $rootdev)"
  fi
  # no fstype found, so we will try to get it via vol_id
  if [ ! "$rootfstype" ]; then
    eval $(/lib/udev/vol_id "$rootdev" | grep ID_FS_TYPE)
    rootfstype=$ID_FS_TYPE
  fi
fi

#if we don't know where the root device belongs to
if [ -z "$rootfstype" ] ; then
  # get type from /etc/fstab or /proc/mounts (actually not needed)
  x1=$(cat $root_dir/etc/fstab /proc/mounts 2>/dev/null \
       | grep -E "$rootdev[[:space:]]" | tail -n 1)
  rootfstype=$(echo $x1 | cut -f 3 -d " ")
fi

# check for journal device
if [ "$rootfsopts" -a -z "$journaldev" ] ; then
    jdev=${rootfsopts#*,jdev=}
    if [ "$jdev" != "$rootfsopts" ] ; then
	journaldev=${jdev%%,*}
    fi
    logdev=${rootfsopts#*,logdev=}
    if [ "$logdev" != "$rootfsopts" ] ; then
	journaldev=${logdev%%,*}
    fi
fi

# WARNING: dirty hack to get the resume device of the current system
for o in $(cat /proc/cmdline); do
    case "$o" in
    resume=*)
	resumedev=${o##resume=}
	;;
    esac
done

# check for nfs root and set the rootfstype accordingly
case "$rootdev" in
    /dev/nfs)
	rootfstype=nfs
	;;
    /dev/*)
        if [ ! -e "$rootdev" ]; then
	    error 1 "Root device ($rootdev) not found"
	fi
	;;
    *://*) # URL type
	rootfstype=${rootdev%%://*}
	interface=default
	;;
    *:*)
	rootfstype=nfs
	interface=default
	;;
esac

if [ -z "$rootfstype" ]; then
    rootfstype=$(/lib/udev/vol_id -t $rootdev)
    [ $? -ne 0 ] && rootfstype=
    [ "$rootfstype" = "unknown" ] && $rootfstype=
fi

if [ ! "$rootfstype" ]; then
    error 1 "Could not find the filesystem type for root device $rootdev

Currently available -d parameters are:
	Block devices	/dev/<device>
	NFS		<server>:<path>
	URL		<protocol>://<path>"
fi

# Check if we have to load a module for the rootfs type
if [ ! "$(find $root_dir/lib/modules/$kernel_version/ -name $rootfstype.ko)" ]; then
    if ! grep -q ${rootfstype}_fs_type $map ; then
	error 1 "Could not find the filesystem module for root device $rootdev ($rootfstype)"
    else
	rootfsmod=
    fi
else
    rootfsmod=$rootfstype
fi

# blockdev is the list current block devices.
# It will get modified by the various scrips as they descend through
# the device setup, starting with the mount information
# and ending at the block device

fallback_rootdev="$rootdev"
save_var fallback_rootdev
save_var rootdev
save_var resumedev
save_var journaldev
save_var dumpdev
blockdev="$(resolve_device Root $rootdev) $(resolve_device Resume $resumedev) $(resolve_device Journal $journaldev) $(resolve_device Dump $dumpdev)"

