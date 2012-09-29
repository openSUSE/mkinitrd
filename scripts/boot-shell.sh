#!/bin/bash
#
#%stage: setup
#%programs: chmod
#%programs: cp
#%programs: dmesg
#%programs: halt
#%programs: kill
#%programs: killall5
#%programs: ls
#%programs: mv
#%programs: pidof
#%programs: reboot
#%programs: rm
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
