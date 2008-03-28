#!/bin/bash
#
#%stage: device
#

if [ "$rootfstype" = "nfs" ]; then
	interface=default
	save_var rootfstype
fi
