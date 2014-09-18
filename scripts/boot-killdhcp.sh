#!/bin/bash
#
#%stage: setup
#%provides: killprogs
#
#%dontshow
#
# Kills dhcpcd when the 'ifup' feature is used

pids=$(cat /var/run/dhcpcd-*.pid 2>/dev/null)
if test -n "$pids"; then
	kill -9 $pids
fi

