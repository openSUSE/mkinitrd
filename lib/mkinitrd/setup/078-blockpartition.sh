#!/bin/bash

blockpart_blockdev=

for bd in $blockdev; do
	update_blockdev $bd
	if [ "$(echo $bd | egrep '[0-9]$')" ]; then
		blkpart="${bd##*/}"
		blkdev="$(echo $blkpart | sed 's/^\([a-z|!]*\)[0-9]*$/\1/')"
	    if [ -d /sys/block/$blkdev/$blkpart ] ; then
			blockpart_blockdev="$blockpart_blockdev /dev/$blkdev"
	    else
			blockpart_blockdev="$blockpart_blockdev $bd"
		fi
	else
		blockpart_blockdev="$blockpart_blockdev $bd"
	fi
done

blockdev="$blockpart_blockdev"
