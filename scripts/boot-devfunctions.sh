#!/bin/bash
#
#%stage: boot
#
#%dontshow
#
##### Device functions
##
## This script provides helper functions for major/minor analyzation.
## Usually this should not have to be changed in any way and only exists
## here because I have not found any better place to put it to.
##
## Command line parameters
## -----------------------
##

# Convert a major:minor pair into a device number
mkdevn() {
    local major=$1 minor=$2 minorhi minorlo
    major=$(($major * 256))
    minorhi=$(($minor / 256))
    minorlo=$(($minor % 256))
    minor=$(($minorhi * 256 * 4096))
    echo $(( $minorlo + $major + $minor ))
}

# Extract the major part from a device number
devmajor() {
    local devn=$(($1 / 256))
    echo $(( $devn % 4096 ))
}

# Extract the minor part from a device number
devminor() {
    local devn=${1:-0}
    echo $(( $devn % 256 )) 
}

# (We are using a devnumber binary inside the initrd.)
devnumber() {
    set -- $(ls -lL $1)
    mkdevn ${5%,} $6
}
