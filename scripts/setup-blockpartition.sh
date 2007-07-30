#!/bin/bash
#
#%stage: block
#%provides: partition
#
blockpart_blockdev=

for bd in $blockdev; do
	update_blockdev $bd
	if [ "$(echo $bd | egrep '[a-z][0-9]*$')" ]; then
	    if [ "${blockdriver%%[0-9]*}" = "cciss" ] ; then
		blkpart="cciss!${bd##*/}"
		blkdev="${blkpart%%p[0-9]}"
	    else
		blkpart="${bd##*/}"
		blkdev="$(echo $blkpart | sed 's/^\([a-z|!]*\)[0-9]*$/\1/')"
	    fi
	    if [ -d /sys/block/$blkdev/$blkpart ] ; then
		blkdev=$(echo $blkdev | sed 's.!./.g')
		blockpart_blockdev="$blockpart_blockdev /dev/$blkdev"
	    else
		blockpart_blockdev="$blockpart_blockdev $bd"
	    fi
	else
	    blockpart_blockdev="$blockpart_blockdev $bd"
	fi
done

blockdev="$blockpart_blockdev"
