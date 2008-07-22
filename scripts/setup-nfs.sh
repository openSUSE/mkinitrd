#!/bin/bash
#
#%stage: device
#

if [ "$rootfstype" = "nfs" ]; then
	interface=${interface:-default}
	save_var rootfstype
fi
