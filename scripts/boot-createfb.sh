#!/bin/bash
#%stage: setup
#%programs: mknod
#%dontshow
#
##### framebuffer device node creator
##
## creates the framebuffer device nodes
##
## Command line parameters
## -----------------------
##
##

# Create framebuffer devices
if [ -f /proc/fb ]; then
    while read fbnum fbtype; do
        if [ $(($fbnum < 32)) ] ; then
            [ -c /dev/fb$fbnum ] || mknod -m 0660 /dev/fb$fbnum c 29 $fbnum
        fi
    done < /proc/fb
fi
