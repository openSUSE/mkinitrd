#!/bin/bash
#%requires: storage
#%modules: nfs
#%if: "$rootfstype" = "nfs" -o "$interface"
#
##### Network FileSystem
##
## This is where NFS gets mounted.
## If no root= option was given, the root device will be taken from the DHCP-server.
##
## Command line parameters
## -----------------------
##
## root=<server>:/<folder>	the nfs root path
## 

if [ -z "$rootdev" ]; then
  # ROOTPATH gets set via dhcpcd
  case "$ROOTPATH" in
    "") ;;
    *:*)
	rootfstype="nfs"
	rootdev="$ROOTPATH" ;;
    *)
	if [ -n "$DHCPSIADDR" ]; then
	    rootdev="$DHCPSIADDR:$ROOTPATH"
	    rootfstype="nfs"
	elif [ -n "$DHCPSNAME" ]; then
	    rootdev="$DHCPSNAME:$ROOTPATH"
	    rootfstype="nfs"
	fi ;;
  esac
  if [ -z "$rootdev" ]; then
	echo "no local root= kernel option given and no root server set by the dhcp server."
	die 0
  fi
fi

if [ "$rootfstype" = "nfs" ]; then
	# load the nfs module before using it
	load_modules
	
	opt="-t nfs -o ro,nolock"
	# mount the actual nfs root device on /root
	echo "Mounting root $rootdev"
	[ -n "$rootflags" ] && opt="${opt},$rootflags"
	
	mount $opt $rootdev /root || die 1
	
	# keep the mount module from mounting the root device again
	[ "$(cat /proc/mounts | grep /root)" ] && root_already_mounted=1
else
	dont_load_modules
fi
