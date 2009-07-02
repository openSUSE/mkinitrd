#!/bin/bash
#
#%stage: crypto
#

if [ -x /sbin/cryptsetup -a -x /sbin/dmsetup ] ; then
    luks_blockdev=
    # bd holds the device we see the decrypted LUKS partition as
    for bd in $blockdev ; do
    	luks_name=
	update_blockdev $bd
	luks_blockmajor=$blockmajor
	luks_blockminor=$blockminor
	# luksbd holds the device, LUKS is running on
	for luksbd in $(dm_resolvedeps $bd); do # should only be one for luks
		[ $? -eq 0 ] || return 1
		update_blockdev $luksbd
		if /sbin/cryptsetup isLuks $luksbd 2>/dev/null; then
			root_luks=1
			tmp_root_dm=1 # luks needs dm

			luks_name="$(dmsetup -c info -o name --noheadings -j $luks_blockmajor -m $luks_blockminor)"
			eval luks_${luks_name}=$(beautify_blockdev ${luksbd})
			save_var luks_${luks_name}

			luks="$luks $luks_name"
			luks_blockdev="$luks_blockdev $luksbd"
		fi
	done
	if [ ! "$luks_name" ]; then # no luks found
		luks_blockdev="$luks_blockdev $bd"
	fi
    done
    blockdev="$luks_blockdev"
fi

if [ "$root_luks" ]; then
    case $LANG in
	en*)
	    /* We only support english keyboard layout currently */
	    ;;
	*)
	    echo "Only english keyboard layout supported."
	    echo "Please ensure that the password is typed correctly."
	    luks_lang=$LANG
	    ;;
    esac
    cryptmodules="$(sed -rn 's/^module[[:blank:]]*:[[:blank:]]*(.*)$/\1/p' < /proc/crypto)"
fi

save_var root_luks	# do we have luks?
save_var luks		# which names do the luks devices have?
save_var cryptmodules	# required kernel modules for crypto setup
save_var luks_lang	# original language settings
