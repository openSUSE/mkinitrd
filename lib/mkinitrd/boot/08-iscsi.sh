#!/bin/bash
#%stage: device
#%depends: network
#%programs: /sbin/iscsid /sbin/iscsiadm /sbin/fwparam_ibft usleep
#%modules: iscsi_tcp crc32c scsi_transport_iscsi
#%if: "$root_iscsi" -o "$TargetAddress"
#
##### iSCSI initialization
##
## This script initializes iSCSI (SCSI over IP).
## To be able to use this script, the network has to be setup. 
## When everything worked as expected, the iSCSI devices will show
## up as real SCSI devices.
##
## Command line parameters
## -----------------------
##
## TargetAddress		the address of the iscsi server
## TargetPort		the port of the iscsi server (defaults to 3260)
## TargetName		the iscsi target name (connect to all if empty)
## iSCSI_ignoreNodes	if set all stored nodes will be ignored (only 
##			iBFT and commandline nodes get parsed)
## 

### iSCSI_warning_InitiatorName <new InitiatorName> <Origin>
# shows a warning about iSCSI InitiatorName differences
# Origin should be something like "commandline" or "iBFT"
iSCSI_warning_InitiatorName() {
	echo "iSCSI:       WARNING"
	echo "iSCSI: ======================="
	echo "iSCSI: "
	echo "iSCSI: InitiatorName given on $2 and internally stored Initiator are different."
	echo "iSCSI: New:    $tmp_InitiatorName"
	echo "iSCSI: Stored: $InitiatorName"
	echo "iSCSI: "
	echo "iSCSI: using the $2 version"
}

if [ "$iSCSI_ignoreNodes" ]; then
	# make us forget we have to initialize stored nodes
	echo "iSCSI: removing node information..."
	iscsi_sessions=
	rm -rf /etc/iscsi/nodes
	mkdir /etc/iscsi/nodes
fi

# get the command line InitiatorName
tmp_InitiatorName="$(get_param InitiatorName)"
# reads the InitiatorName variable
. /etc/iscsi/initiatorname.iscsi

# Check of iBFT settings
if [ -x /sbin/fwparam_ibft ] ; then
    eval $(/sbin/fwparam_ibft -b 2> /dev/null )
    # only use the iBFT InitiatorName if the commandline argument is not "default"
    if [ "$iSCSI_INITIATOR_NAME" -a "$tmp_InitiatorName" != "default" ] ; then
    	iSCSI_warning_InitiatorName "$iSCSI_INITIATOR_NAME" "iBFT"
        InitiatorName=$iSCSI_INITIATOR_NAME
    fi
    
    TargetNameiBFT=$iSCSI_TARGET_NAME
    TargetAddressiBFT=iSCSI_TARGET_IPADDR
    TargetPortiBFT=$iSCSI_TARGET_PORT
fi


if [ "$tmp_InitiatorName" != "$InitiatorName" -a "$tmp_InitiatorName" != "default" -a "$tmp_InitiatorName" ]; then
    	iSCSI_warning_InitiatorName "$tmp_InitiatorName" "cmdline"
	InitiatorName=$tmp_InitiatorName
fi

# store the detected InitiatorName permanently
echo "InitiatorName=$InitiatorName" > /etc/iscsi/initiatorname.iscsi

# ... hier wuerde viel s390-init zeug kommen

iscsi_mark_root_nodes()
{
    local iscsi_tgts

    if [ -z "$iscsitarget" ] ; then
        iscsi_tgts=$(/sbin/iscsiadm -m node | sed -n "s/.*$iscsiserver:$iscsiport,.* \(iqn.*\)/\1/p")
    else
        iscsi_tgts="$iscsitarget"
    fi

    for tgt in $iscsi_tgts ; do
        /sbin/iscsiadm -m node -p $iscsiserver:$iscsiport -T $tgt -o update -n node.conn[0].startup -v automatic
    done
}

load_modules

echo "Starting iSCSI daemon"
/sbin/iscsid
usleep 5000000

# loop through all stored iscsi sessions, the command line and iBFT settings
for session in iscsi_sessions "" iBFT; do
	# get the current config
	iscsiserver=$(eval echo \$TargetAddress$session)
	iscsiport=$(eval echo \$TargetPort$session)
	iscsitarget=$(eval echo \$TargetName$session)
	
	# try to detect and connect to the iscsi server
	if [ "$iscsiserver" -a "$iscsiport" ] ; then
	    echo -n "Starting discovery on ${iscsiserver},${iscsiport}: "
	    if /sbin/iscsiadm -m discovery -t st -p ${iscsiserver}:${iscsiport} 2> /dev/null ; then
	        echo "ok."
	    else
	        echo "failed."
	    fi
	    iscsi_mark_root_nodes
	fi
done

/sbin/iscsiadm -m node -L automatic
