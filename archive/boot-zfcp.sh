#!/bin/bash
#%stage: device
#%if: "$root_zfcp"
#
##### S390: zfcp module loader
##
## 
## 
##
## Command line parameters
## -----------------------
##
## zfcp=
##

add_module_param zfcp "$(get_param zfcp)"
