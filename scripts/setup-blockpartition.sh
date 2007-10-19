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
	    elif [ "${blockdriver%%[0-9]*}" = "ida" ] ; then
		blkpart="ida!${bd##*/}"
		blkdev="${blkpart%%p[0-9]}"
	    else
		blkpart="${bd##*/}"
		blkdev="$(echo $blkpart | sed 's/^\([a-z|!]*\)[0-9]*$/\1/')"
	    fi
	    if [ -d /sys/block/$blkdev/$blkpart ] ; then
		blkdev=$(echo $blkdev | sed 's.!./.g')
		bd="/dev/$blkdev"
	    fi
	fi
	blockpart_blockdev="$(update_list $bd $blockpart_blockdev)"
done

blockdev="$blockpart_blockdev"
