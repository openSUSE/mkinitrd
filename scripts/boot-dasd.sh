#!/bin/bash
#%stage: device
#%modules: $dasd_modules
#%programs: /sbin/dasdview /sbin/dasdinfo /sbin/dasd_configure
#%if: "$root_dasd"
#
##### S390: dasd module loader
##
## 
## 
##
## Command line parameters
## -----------------------
##
## dasd=
##

add_module_param dasd_mod "$(get_param dasd)"
