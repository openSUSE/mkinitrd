#!/bin/bash
#
#%stage: boot
#
#%if: "$vendor_init_script"
#
##### vendor script
##
## This is the legacy interface for 3rd party vendors.
## It should not be used any more. Take your time and try
## to fix the scripts for the new mkinitrd.
##
## Command line parameters
## -----------------------
##

# Call vendor-specific init script
if [ -x /vendor_init.sh ] ; then
    /vendor_init.sh
fi

