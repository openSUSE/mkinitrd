#!/bin/bash
#
#%stage: setup
#%depends: start
#
[ -d /sys/bus/usb ] && use_usb=1

save_var use_usb
