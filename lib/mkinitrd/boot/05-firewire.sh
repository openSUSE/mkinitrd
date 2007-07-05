#!/bin/bash
#%stage: device
#%udevmodules: ohci1394
#%if: "$root_firewire"
#
##### firewire module helper
##
## This script provides us with the firewire modules in case we have a
## firewire based root device.
##
## Command line parameters
## -----------------------
##
