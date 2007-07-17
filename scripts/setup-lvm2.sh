#!/bin/bash
#
#%stage: volumemanager
#%depends: evms
#
# get information about the current blockdev
update_blockdev

# Check whether we are using LVM2 (only available when not using EVMS)
if [ -z "$root_evms" ] && [ -x /sbin/lvdisplay ] ; then
  lvm_blockdev=

  for bd in $blockdev; do
    update_blockdev $bd
	
    vg_name=$(lvdisplay -c 2> /dev/null | sed -n "/.*:$blockmajor:$blockminor/p")
    vg_dev=${vg_name%%:*}
    vg_name=${vg_name#*:}
    vg_root=${vg_name%%:*}
    if [ "$vg_root" ] ; then
	root_lvm2=1
	realrootdev=${vg_dev##  }
#	blockdev=$(vgs --noheadings --options devices $vg_root 2> /dev/null | sed -n "s@ *\(/dev/.*\)([0-9]*) *@\1@p" | sort | uniq)
	lvm_blockdev="$lvm_blockdev $(dm_resolvedeps $blockdev)"
	[ $? -eq 0 ] || return 1
	vg_roots="$vg_roots $vg_root"
    else
	lvm_blockdev="$lvm_blockdev $bd"
    fi
  done
  blockdev="$lvm_blockdev"
fi

if use_script lvm2; then
    tmp_root_dm=1 # lvm needs dm
    mkdir -p $tmp_mnt/etc/lvm
    mkdir -p $tmp_mnt/var/lock/lvm
    cp -a /etc/lvm/lvm.conf $tmp_mnt/etc/lvm
fi

save_var root_lvm2
save_var vg_roots

