#!/bin/bash
#
#%stage: setup
#%param_f: "Features to be enabled when generating initrd.\nAvailable features are:\niscsi, md, mpath, lvm, lvm2, evms" "\"feature list\"" ADDITIONAL_FEATURES
#%param_k: "List of kernel images for which initrd files are created. Defaults to all kernels found in /boot." "\"kernel list\"" kernel_images
#%param_i: "List of file names for the initrd; position have match to \"kernel list\". Defaults to all kernels found in /boot." "\"initrd list\"" initrd_images
#%param_l: "mkinitrd directory. Defaults to /lib/mkinitrd." "\"lib_dir\"" INITRD_PATH
#%param_b: "Boot directory. Defaults to /boot." boot_dir boot_dir
#%param_M: "System.map file to use." map sysmap
#%param_A: "Create a so called \"monster initrd\" which includes all features and modules possible."
#%param_B: "Do not update bootloader configuration."
#%param_v: "Verbose mode."
#%param_R: "Print release (version)."
#%param_L: "Disable logging."
#%param_h: "This help screen."
#
###### Additional options
##
## Script inclusion may be overriden by
##      1) creating a monster-initrd
##      2) including the wanted module in the configuration option ADDITIONAL_FEATURES in /etc/sysconfig/initrd
##      3) definition using the -f command line switch
##

# Install a binary file
cp_bin() {
    cp -a "$@" \
    || exit_code=1

    # Remember the binaries installed. We need the list for checking
    # for dynamic libraries.
    while [ $# -gt 1 ]; do
        initrd_bins[${#initrd_bins[@]}]=$1
        shift
   done
   # file may print '^setuid ELF ...'
   # suid mount will fail if mkinitrd was called as user
   if [ -L "$1" ]; then
        : do nothing with symlinks
   elif [ -d "$1" -o -f "$1" ]; then
     find "$1" -type f -print0 | xargs -0 chmod 0755
   fi
}

# check if we should use script or feature $1
use_script() {
    local condition feature script file

    # always use when creating monster initrd
    [ "$create_monster_initrd" ] && return 0

    # Normalize to feature name
    feature="${1##*/}"
    feature="${feature#*-}"
    feature="${feature%.sh}"

    # when using additional features defined in the sysconfig
    # script / command line, always use them
    if [ "$ADDITIONAL_FEATURES" ]; then
      for addfeature in $ADDITIONAL_FEATURES; do
        if [ "$addfeature" = "$feature" ]; then
            return 0
        fi
      done
    fi

    # return false if file does not exist
    for file in $INITRD_PATH/boot/*-$feature.sh ; do
        if [ -e $file ] ; then
            script=$file
        fi
    done
    [ -e "$script" ] || return 1

    condition="$(cat "$script" | grep '%if: ')"
    condition="${condition#*if: }"
    if [ "$condition" ]; then
        if ! eval test $condition; then
#           echo "[FAILED] ($1) $(eval echo $condition)"
            return 1
#       else
#           echo "[OK] ($1) $(eval echo $condition)"
        fi
    fi
#    echo "[OK] ($1)"
    return 0
}

create_monster_initrd=$param_A

local kernel_version
local -a features
local fs_modules drv_modules uld_modules xen_modules

tmp_mnt=$work_dir/mnt
tmp_mnt_small=${tmp_mnt}_small
tmp_msg=$work_dir/msg$$
vendor_script=$tmp_mnt/vendor_init.sh

linuxrc=$tmp_mnt/init

if [ ! -f "$kernel_image" ] ; then
    error 1 "No kernel image $kernel_image found"
fi

kernel_version=$(/sbin/get_kernel_version $kernel_image)
modules_dir=$root_dir/lib/modules/$kernel_version

#echo -e "Kernel version:\t$kernel_version"
echo -e "Kernel image:   $kernel_image"
echo -e "Initrd image:   $initrd_image"

if [ ! -d "$modules_dir/misc" -a \
    ! -d "$modules_dir/kernel" ]; then
    echo -e "Kernel Modules: <not available>"
fi

# And run depmod to ensure proper loading
if [ "$sysmap" ] ; then
    map="$sysmap"
else
    map=$root_dir/boot/System.map-$kernel_version
fi
if [ ! -f $map ]; then
    map=$root_dir/boot/System.map
fi
if [ ! -f $map ]; then
    oops 9 "Could not find map $map, please specify a correct file with -M."
fi

# create an empty initrd
if ! mkdir $tmp_mnt ; then
    error 1 "could not create temporary directory"
fi

# fill the initrd
cp $INITRD_PATH/bin/linuxrc $linuxrc
mkdir "$tmp_mnt/boot"

mkdir -p $tmp_mnt/{sbin,bin,etc,dev,proc,sys,root,config}

mkdir -p -m 4777 $tmp_mnt/tmp

# Create a dummy /etc/mtab for mount/umount
echo -n > $tmp_mnt/etc/mtab

# Add modprobe, modprobe.conf*, and a version of /bin/true: modprobe.conf
# might use it.
for mod in $root_dir/etc/modprobe.conf $root_dir/etc/modprobe.conf.local \
    $root_dir/etc/modprobe.d ; do
    test -e $mod && cp -r $mod $tmp_mnt/etc
done
cat > $tmp_mnt/bin/true <<-EOF
#! /bin/sh
:
EOF
chmod +x $tmp_mnt/bin/true

mkdir -p $tmp_mnt/var/log

# all dev nodes belong to root, but some may be
# owned by a group other than root
# getent passwd | sed '/^root:/s/^\([^:]\+\):[^:]*:\([^:]\+\):\([^:]\+\):.*/\1::\2:\3:::/p;d' > $tmp_mnt/etc/passwd
echo 'root::0:0:::' > $tmp_mnt/etc/passwd
echo 'nobody::65534:65533:::' >> $tmp_mnt/etc/passwd
getent group | sed 's/^\([^:]\+\):[^:]*:\([^:]\+\):.*/\1::\2:/' > $tmp_mnt/etc/group
(echo 'passwd: files';echo 'group: files') > $tmp_mnt/etc/nsswitch.conf

# scsi_id config file
f=/etc/scsi_id.config
test -f $f && cp $f $tmp_mnt/$f

# Store the commandline
echo $build_cmdline > $tmp_mnt/mkinitrd.config

# HBA firmware
mkdir -p $tmp_mnt/lib/firmware
for fw in /lib/firmware/ql*.bin /lib/firmware/aic94xx* ; do
    if [ -f "$fw" ] ; then
        cp -a $fw $tmp_mnt/lib/firmware
    fi
done
