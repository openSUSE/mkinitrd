#!/bin/bash

case "$rootdev" in
    *:*)
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
