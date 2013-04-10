#!/bin/bash
#
#%stage: setup
#%param_f: "Features to be enabled when generating initrd.\nAvailable features are:\niscsi, md, multipath, lvm, lvm2, ifup, fcoe, lldpad" "\"feature list\"" ADDITIONAL_FEATURES
#%param_k: "List of kernel images for which initrd files are created. Defaults to all kernels found in /boot." "\"kernel list\"" kernel_images
#%param_i: "List of file names for the initrd; position have match to \"kernel list\". Defaults to all kernels found in /boot." "\"initrd list\"" initrd_images
#%param_l: "mkinitrd directory. Defaults to /lib/mkinitrd." "\"lib_dir\"" INITRD_PATH
#%param_b: "Boot directory. Defaults to /boot." boot_dir boot_dir
#%param_M: "System.map file to use." map sysmap
#%param_A: "Create a so called \"monster initrd\" which includes all features and modules possible."
#%param_B: "Do not update bootloader configuration."
#%param_P: "Do not include the password of the super user (root)."
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
# cp_bin file target_filename
# cp_bin file target_directory
# cp_bin file file target_directory
# file is either a regular file or a symlink. symlinks and all paths they point to will be copied
# the "root" of target is $tmp_mnt, which is required to copy symlinks properly
cp_bin() {
    local -a files
    local target
    local file

    # need at least two parameters, source and destination
    if test $# -lt 2; then
        return 0
    fi
    # store source filenames
    # (assigning array from $@ and setting target= from it does not work)
    until test $# -eq 1; do
        files=( ${files[@]} $1 )
        shift
    done
    # store target, either file or directory
    target=$1

    # if more than two parameters, last entry must be a directory
    if test ${#files[@]} -gt 1; then
        if ! test -d ${target}; then
            return 0
        fi
    fi

    # copy all source files
    for file in ${files[@]}; do
        local src dst
        src=${file}
        dst=${target}
        # copy requested soure file as is to requested destination
        cp -a --remove-destination ${src} ${dst}
        # copy symlinks recursivly
        while [ 1 ]; do
            local tmp_src
            if test -L ${src}; then
                # read link target
                tmp_src=$(readlink ${src})
                if test "${tmp_src:0:1}" = "/"; then
                    # reuse absolute paths
                    src=${tmp_src}
                else
                    # symlink is relative to current source
                    src=${src%/*}/${tmp_src}
                fi
                cp -a --remove-destination --parents ${src} $tmp_mnt
                # if link target exists, proceed to next symlink target
                if test -e "${src}"; then
                    continue
                fi
            fi
            # exit loop in case of dead symlink or if final target of symlink was reached
            break
        done

        # if source file exists, add it to list of binaries
        # use source instead of target to avoid referencing symlinks
        if test -e "${src}"; then
            initrd_bins[${#initrd_bins[@]}]=${src}
        fi
    done
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

# returns true if feature exists
feature_exists() {
    local feature=$1 script

    for script in $INITRD_PATH/boot/*-$feature.sh; do
        return 0
    done
    return 1
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

kernel_version=$(kernel_version_from_image $kernel_image)
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

# check features

for feature in $ADDITIONAL_FEATURES ; do
    feature_exists "$feature" || echo "[WARNING] Feature \"$feature\" not found. A typo?"
done

# create an empty initrd
if ! mkdir $tmp_mnt ; then
    error 1 "could not create temporary directory"
fi

# fill the initrd
cp $INITRD_PATH/bin/linuxrc $linuxrc
mkdir "$tmp_mnt/boot"

mkdir -p $tmp_mnt/{sbin,bin,etc,dev,proc,sys,root,config,usr/bin,usr/sbin}

mkdir -p -m 4777 $tmp_mnt/tmp

# Create a dummy /etc/mtab for mount/umount
echo -n > $tmp_mnt/etc/mtab

# Add modprobe, modprobe.conf*, and a version of /bin/true: modprobe.conf
# might use it.
for mod in $root_dir/etc/modprobe.conf $root_dir/etc/modprobe.conf.local \
    $root_dir/etc/modprobe.d ; do
    test -e $mod && cp -r $mod $tmp_mnt/etc
done
cat > $tmp_mnt/bin/true <<-'EOF'
	#! /bin/sh
	:
	EOF
chmod +x $tmp_mnt/bin/true

mkdir -p $tmp_mnt/var/log

# password support only if initrd is created by super user
(($(id -u) == 0)) || param_P=yes
if [ -z "$param_P" ]; then
    pw=x
else
    pw=
fi

# all dev nodes belong to root, but some may be
# owned by a group other than root
#  getent --service=files passwd | \
#  sed -n "/^\(nobody\|root\):/s/^\([^:]\+\):[^:]*:\([^:]\+\):\([^:]\+\):.*/\1:${pw}:\2:\3::\/:/p" > $tmp_mnt/etc/passwd
cat > $tmp_mnt/etc/passwd <<-EOF
	root:${pw}:0:0::/:
	nobody:${pw}:65534:65533::/:
	EOF
getent --service=files group | sed -n 's/^\([^:+]\+\):[^:]*:\([^:]\+\):.*/\1::\2:/p' > $tmp_mnt/etc/group
cat > $tmp_mnt/etc/nsswitch.conf <<-'EOF'
	passwd: files
	shadow: files
	group: files
	EOF
if [ -z "$param_P" ]; then
    oumask=$(umask)
    umask 0026
    getent --service=files shadow | \
    sed -n '/^\(nobody\|root\):/s/^\([^:]\+\):\([^:]\+\):\([0-9]*\):.*/\1:\2:\3::::::/p' > $tmp_mnt/etc/shadow
    chgrp shadow $tmp_mnt/etc/shadow
    umask $oumask
fi

# scsi_id config file
f=/etc/scsi_id.config
test -f $f && cp $f $tmp_mnt/$f

# Store the commandline
echo $build_cmdline > $tmp_mnt/mkinitrd.config
