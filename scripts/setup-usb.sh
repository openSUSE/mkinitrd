#!/bin/bash
#
#%stage: setup
#%depends: start
#

# capture the output into a variable so that it is visible in bash -x mode
output=$(/sbin/modprobe -C /dev/null --set-version $kernel_version \
	--ignore-install --show-depends usbhid 2>&1)
if test $? -eq 0; then
	use_usb=1
fi

save_var use_usb
