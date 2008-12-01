#!/bin/bash
#
#%stage: setup
#
#%dontshow
#
##### debug shell
##
## Runs a debug shell if the parameter "shell=1" was given on the command line
##
## Command line parameters
## -----------------------
##
## shell=1              turn on a debug shell
## 

[ "$(get_param shell)" ] && bash
