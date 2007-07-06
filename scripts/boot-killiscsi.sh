#!/bin/bash
#
#%stage: setup
#%provides: killprogs
#
#%if: "$iscsi_root"
#%dontshow
#
##### kill iscsi
##
## Because we will run and use the iSCSI daemon from the new root
## the old one has to be killed. During that time no iSCSI 
## exceptions should occur!
##
## Command line parameters
## -----------------------
##

# kill iscsid, will be restarted from the real root
iscsi_pid=$(pidof iscsid)
[ "$iscsi_pid" ] && kill -KILL $iscsi_pid
