#!/bin/bash
#%dontshow
#%requires: netconsole

# TODO: disable

# Enable asynchronous scanning again
if [ -e /sys/module/scsi_transport_fc/parameters/rport_scan_timeout ] ; then
  echo 0 > /sys/module/scsi_transport_fc/parameters/rport_scan_timeout
fi

/sbin/udevsettle --timeout=$udev_timeout
