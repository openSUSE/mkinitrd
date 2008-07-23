#!/bin/bash
#%stage: block
#%modules: cifs
#%programs: /sbin/mount.cifs
#%if: "$rootfstype" = "cifs"
#
##### CIFS support
##
## This is where CIFS gets mounted.
##
## Command line parameters
## -----------------------
##
## root=cifs://[user:pass@]<server>/<folder>	the cifs root path
## cifsuser=<username> (only used if not defined in root=)
## cifspass=<password> (only used if not defined in root=)
## 

if [ "$rootfstype" = "cifs" ]; then
	# load the cifs module before using it
	load_modules
	
	if [ "${rootdev%%://*}" = "cifs" ]; then # URL parsing
		rootdev=${rootdev##cifs://}
		username=${rootdev%@*}
		password=${username#*:}
		if [ "$password" ]; then
			cifspass=$password
			username=${username%:*}
		fi
		cifsuser=$username
		if [ "$username" ]; then
			rootdev="${rootdev#*@}"
		fi
		rootdev="//$rootdev"
	fi

	rootfsmod=
	if [ ! "$cifsuser" -o ! "$cifspass" ]; then
		echo "For CIFS support you need to specify a username and password either in the cifsuser and cifspass commandline parameters or in the root= CIFS URL."
	fi
	if [ "$rootflags" ] ; then
	    rootflags="${rootflags},user=$cifsuser"
	else
	    rootflags="user=$cifsuser"
	fi
	rootflags="$rootflags,pass=$cifspass"
else
	dont_load_modules
fi
