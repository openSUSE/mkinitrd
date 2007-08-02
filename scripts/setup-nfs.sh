#!/bin/bash
#
#%stage: device
#
case "$rootdev" in
    /dev/nfs)
	rootfstype=nfs
	rootdev=
	use_dhcp=1
	;;
    /dev/*)
	;;
    *://*)
	rootfstype=${rootdev%%://*}
	interface=default
	save_var rootfstype
	;;
    *:/*)
	rootfstype=nfs
	;;
esac

if [ -z "$rootdev" ] ; then
    if [ -z "$use_dhcp" ]; then
	error 1 "No '/' mountpoint specified and no automatic configuration via dhcp"
    else
	rootfstype=nfs
    fi
fi

if [ "$rootfstype" = "nfs" ]; then
	interface=default
	save_var rootfstype
fi
