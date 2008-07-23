#!/bin/bash
#%stage: block
#%modules: nfs
#%programs: /sbin/mount.nfs
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
fi
if [ -z "$rootdev" ]; then
    echo "no local root= kernel option given and no root server set by the dhcp server."
    echo "exiting to /bin/sh"
    cd /
    PATH=$PATH PS1='$ ' /bin/sh -i
fi

if [ "$rootfstype" = "nfs" ]; then
	# load the nfs module before using it
	load_modules
	
	rootfsmod=
	if [ -n "$rootflags" ] ; then
	    rootflags="${rootflags},nolock"
	else
	    rootflags="nolock"
	fi
else
	dont_load_modules
fi
