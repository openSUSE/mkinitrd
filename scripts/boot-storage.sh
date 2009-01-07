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
## nfsroot              alias for root
## resume               the resume device (the device software suspend puts its image to)
## journal              the journaling device (if journaling is being done on a seperate device)
##

# include the rootdev= option
. /config/mount.sh

if [ "$root" ]; then
    rootdev="$root"
fi

if [ "$nfsroot" ]; then
    rootdev=$nfsroot
fi

[ "$resume" ] && resumedev="$resume"
[ "$journal" ] && journaldev="$journal"

# lilo strips off the /dev/prefix from device names!
case $rootdev in
        /dev/disk/by-name/*)
            rootdevid=${rootdev#/dev/disk/by-name/}
            rootdevid=${rootdevid%-part*}
            ;;
        /dev/md*)
            md_dev=$rootdev
            md_minor=${rootdev#/dev/md}
            ;;
        /dev/*)
            ;;
        LABEL=*)
            label=${rootdev#LABEL=}
            echo "ENV{ID_FS_USAGE}==\"filesystem|other\", ENV{ID_FS_LABEL_SAFE}==\"$label\", SYMLINK+=\"root\"" > /etc/udev/rules.d/99-mkinitrd-label.rules
            rootdev=/dev/root
            ;;
        UUID=*)
            uuid=${rootdev#UUID=}
            echo "ENV{ID_FS_USAGE}==\"filesystem|other\", ENV{ID_FS_UUID}==\"$uuid\", SYMLINK+=\"root\"" > /etc/udev/rules.d/99-mkinitrd-uuid.rules
            rootdev=/dev/root
            ;;
        [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
            maj=$((0x0$rootdev >> 8))
            min=$((0x0$rootdev & 0xff))
            echo "SUBSYSTEM==\"block\", SYSFS{dev}==\"$maj:$min\", SYMLINK+=\"root\"" > /etc/udev/rules.d/05-mkinitrd-lilo.rules
            rootdev=/dev/root ;;
        [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
            maj=$((0x$rootdev >> 8))
            min=$((0x$rootdev & 0xff))
            echo "SUBSYSTEM==\"block\", SYSFS{dev}==\"$maj:$min\", SYMLINK+=\"root\"" > /etc/udev/rules.d/05-mkinitrd-lilo.rules
            rootdev=/dev/root ;;
        0x[0-9a-fA-F][0-9a-fA-F]*)
            maj=$(($rootdev >> 8))
            min=$(($rootdev & 0xff))
            echo "SUBSYSTEM==\"block\", SYSFS{dev}==\"$maj:$min\", SYMLINK+=\"root\"" > /etc/udev/rules.d/05-mkinitrd-lilo.rules
            rootdev=/dev/root ;;
        *://*) # URL type
            rootfstype=${rootdev%%://*}
        ;;
        *:/*)
            rootfstype="nfs"
            ;;
        *)
            [ "$rootdev" ] && rootdev=/dev/$rootdev
            ;;
esac
