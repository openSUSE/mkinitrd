#!/bin/bash
#%requires: dmraid
#%programs: /sbin/kpartx /sbin/kpartx_id
#%if: -n "$root_kpartx"
#
##### KPartX
##
## KPartX is a simple method to create partitions on top of Device Mapper devices.
## For it to work, only the binary files have to be available.
##

