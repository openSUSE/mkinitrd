#!/bin/bash
#
#%stage: boot
#%depends: start
#%udevmodules: $rootfsmod
#
#%dontshow
#
##### Storage parameter parsing
##
## This is where we analyze different parts of the root device information,
## so the following scripts will be able to initialize properly according to that
##
## Command line parameters
## -----------------------
##
## root                 the root device (the device /bin/init is on)
## nfsroot              nfs root if root=/dev/nfs, otherwise alias for root
## resume               the resume device (the device software suspend puts its image to)
## journal              the journaling device (if journaling is being done on a seperate device)
##

# include the rootdev= option
. /config/mount.sh

if [ "$root" ]; then
    rootdev="$root"
fi

if [ -n "$nfsroot" -a -z "$root" ]; then
    rootdev=/dev/nfs
fi

[ "$resume" ] && resumedev="$resume"
[ "$journal" ] && journaldev="$journal"

for name in root usr; do
    # lilo strips off the /dev/prefix from device names!
    var_dev=${name}dev
    var_fstype=${name}fstype
    dev=${!var_dev}
    fstype=${!var_fstype}
    case "$dev" in
    /dev/md*)
        # FIXME: support for / and /usr on different md devices
        md_dev=$rootdev
        md_minor=${rootdev#/dev/md}
        ;;
   /dev/nfs)
        rootfstype="nfs"
        rootdev=$nfsroot
        ;;
    /dev/*)
        ;;
    LABEL=*)
        label=${dev#LABEL=}
        echo "ENV{ID_FS_USAGE}==\"filesystem|other\", ENV{ID_FS_LABEL_ENC}==\"$label\", SYMLINK+=\"$name\"" > /etc/udev/rules.d/99-mkinitrd-$name-label.rules
        dev=/dev/$name
        ;;
    UUID=*)
        uuid=${dev#UUID=}
        echo "ENV{ID_FS_USAGE}==\"filesystem|other\", ENV{ID_FS_UUID}==\"$uuid\", SYMLINK+=\"$name\"" > /etc/udev/rules.d/99-mkinitrd-$name-uuid.rules
        dev=/dev/$name
        ;;
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
        maj=$((0x0$dev >> 8))
        min=$((0x0$dev & 0xff))
        echo "SUBSYSTEM==\"block\", SYSFS{dev}==\"$maj:$min\", SYMLINK+=\"$name\"" > /etc/udev/rules.d/05-mkinitrd-$name-lilo.rules
        dev=/dev/$name
	;;
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
        maj=$((0x$dev >> 8))
        min=$((0x$dev & 0xff))
        echo "SUBSYSTEM==\"block\", SYSFS{dev}==\"$maj:$min\", SYMLINK+=\"$name\"" > /etc/udev/rules.d/05-mkinitrd-$name-lilo.rules
        dev=/dev/$name
	;;
    0x[0-9a-fA-F][0-9a-fA-F]*)
        maj=$(($dev >> 8))
        min=$(($dev & 0xff))
        echo "SUBSYSTEM==\"block\", SYSFS{dev}==\"$maj:$min\", SYMLINK+=\"$name\"" > /etc/udev/rules.d/05-mkinitrd-lilo.rules
        dev=/dev/$name ;;
    *://*) # URL type
        fstype=${dev%%://*}
    ;;
    *:/*)
        fstype="nfs"
        ;;
    *)
        [ "$dev" ] && dev=/dev/$dev
        ;;
    esac
    read $var_dev < <(echo "$dev")
    read $var_fstype < <(echo "$fstype")
done
