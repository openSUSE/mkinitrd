#!/bin/bash
#
#%stage: block
#%provides: partition
#
blockpart_blockdev=

for bd in $blockdev; do
        update_blockdev $bd
        blkpart=$(majorminor2blockdev $blockmajor $blockminor)
        # /proc/partitions lists only partitions or devices which are
        # are partitionable
        if [ "$blkpart" ]; then
            blkpart=$(echo ${blkpart#/dev/} | sed 's./.!.g')
            blkdev=$(echo $blkpart | sed 's/\([a-z]\)[0-9]*$/\1/;s/p$//')
            if [ -d /sys/block/$blkdev/$blkpart ] ; then
                blkdev=$(echo $blkdev | sed 's.!./.g')
                bd="/dev/$blkdev"
            fi
        fi
        blockpart_blockdev="$(update_list $bd $blockpart_blockdev)"
done

blockdev="$blockpart_blockdev"
