#!/bin/bash
#%requires: killblogd
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
/vendor_init.sh
