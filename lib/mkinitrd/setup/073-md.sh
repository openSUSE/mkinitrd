#!/bin/bash

mdblockdev=

for bd in $blockdev ; do
    # get information about the current blockdev
    update_blockdev $bd
    mdconf=$(mdadm -Db $bd 2> /dev/null | sed -n "s@/dev/md[0-9]*@/dev/md$blockminor@p")
    if [ -n "$mdconf" ] ; then
	md_tmpblockdev=$(mdadm -Dbv $bd 2> /dev/null | sed -n "1D;s/,/ /g;s/^ *devices=\(.*\)/\1/p")
	md_dev=${bd##/dev/}
	mdblockdev="$mdblockdev $md_tmpblockdev"
	eval md_conf_${md_dev}=\"$mdconf\"
	md_devs="$md_devs $md_dev"
	root_md=1
    else
	mdblockdev="$mdblockdev $bd"
    fi
done

blockdev="$mdblockdev"

if [ -n "$root_md" ] ; then
    need_mdadm=1
    echo "DEVICE partitions" > $tmp_mnt/etc/mdadm.conf
    for md in $md_devs; do
        eval echo \$md_conf_$md >> $tmp_mnt/etc/mdadm.conf
    done
fi

save_var need_mdadm
save_var md_dev
save_var root_md
