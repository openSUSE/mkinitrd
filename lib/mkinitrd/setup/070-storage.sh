#!/bin/bash

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
		minor=$(echo $major | cut -d : -f 2)
		major=$(echo $major | cut -d : -f 1)
	fi
	local retval=$(cat /proc/partitions | egrep "^[ ]*$major[ ]*$minor")
	echo /dev/${retval##* }
}

beautify_blockdev() {
	local olddev="$1" udevdevs dev
	
	# search for udev information
	udevdevs=$(udevinfo -q symlink --name=$olddev)
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
	if [ -x /sbin/dmsetup ]; then
		beauty_blockdevn="$(devnumber $root_dir/${olddev})"
		echo -n /dev/mapper/
		dmsetup info -c --noheadings -o name -j $(devmajor $beauty_blockdevn) -m $(devminor $beauty_blockdevn)
	fi
}

dm_resolvedeps() {
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
				majorminor2blockdev $dm_dep
			done
		else
			echo $bd
		fi
	done
	return 0
}

# this receives information about the current blockdev so each storage layer has access to it for its current blockdev
update_blockdev() {
	local curblockdev=$1
	[ -z "$curblockdev" ] && curblockdev=$blockdev
	
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

    [ "$2" ] || exit 0

    case "$rootdev" in
      LABEL=*|UUID=*)
	# get real root via fsck hack
	realrootdev=$(fsck -N "$rootdev" \
		      | sed -ne '2s/.* \/dev/\/dev/p' \
		      | sed -e 's/  *//g')
	if [ -z "$realrootdev" ] ; then
	    echo "Could not expand $rootdev to real device" >&2
	    exit 1
	fi
	realrootdev=$(/usr/bin/readlink -m $realrootdev)
	;;
      /dev/disk/*)
	realrootdev=$(/usr/bin/readlink -m $rootdev)
	;;
      *:*)
        if [ "$type" = "Root" ]; then
	    rootfstype=nfs
	    x="nfs-root"
	fi
	;;
    esac

    [ "$2" != "$realrootdev" ] && x="$x ($realrootdev)"

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
  # no rootdev specified, get current root from /etc/fstab
  
  while read fstab_device fstab_mountpoint fstab_type fstab_options dummy ; do
    if [ "$fstab_mountpoint" = "/" ]; then
      rootdev="$fstab_device"
      rootfstype="$fstab_type"
      rootfsopts="$fstab_options"
      break
    fi
  done < <(sed -e '/^[ \t]*#/d' < $root_dir/etc/fstab)
else
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
      /dev/*)
        if [ ! -e "$rootdev" ]; then
	    error 1 "Root device not found"
	fi
	;;
      *:*)
	rootfstype=nfs
	;;
esac

if [ -z "$rootfstype" ]; then
    rootfstype=$(/lib/udev/vol_id -t $rootdev)
    [ $? -ne 0 ] && rootfstype=
    [ "$rootfstype" = "unknown" ] && $rootfstype=
fi

if [ ! "$rootfstype" ]; then
    error 1 "Could not find the filesystem type for root device $rootdev"
fi

if ! modprobe --set-version $kernel_version -q $rootfstype; then
    error 1 "Could not find the filesystem module for root device $rootdev ($rootfstype)"
fi

# blockdev is the current block device depending on the layered storage script we are in
# It will get replaced through its way of abstraction, starting at the information mount tell us
# and ending at the block device

blockdev="$(resolve_device Root $rootdev) $(resolve_device Resume $resumedev) $(resolve_device Journal $journaldev) $(resolve_device Dump $dumpdev)"

