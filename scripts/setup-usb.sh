#!/bin/bash
#
#%stage: setup
#
[ -d /sys/bus/usb ] && use_usb=1

save_var use_usb
