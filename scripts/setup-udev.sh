#!/bin/bash
#
#%stage: setup
#%depends: start
#

# Default udev timeout is 30 seconds
udev_timeout=30

mkdir -p $tmp_mnt/etc/udev/rules.d
mkdir -p $tmp_mnt/usr/lib/udev/rules.d
mkdir -p $tmp_mnt/usr/lib/udev/hwdb.d
mkdir -p $tmp_mnt/usr/lib/systemd
mkdir -p $tmp_mnt/lib
ln -sfn ../usr/lib/udev $tmp_mnt/lib/udev

# copy helper
for script in /usr/lib/udev/* /lib/udev/* /sbin/*_id ; do
    # some helpers are not needed 
    case "${script##*/}" in
    accelerometer) continue ;;
    ata_id) ;;
    bluetooth_serial) continue ;;
    bcache-register) ;;
    cdrom_id) ;;
    collect) ;;
    collect_lvm) ;;
    findkeyboards) continue ;;
    gpsd.sh) continue ;;
    hid2hci) continue ;;
    hwdb.d) continue ;;
    idedma.sh) continue ;;
    ift-load) continue ;;
    iphone-set-info) continue ;;
    ipod-set-info) continue ;;
    isdn.sh) continue ;;
    iwlwifi-led.sh) continue ;;
    keyboard-force-release.sh) continue ;;
    keymap) continue ;;
    kpartx_id) ;;
    lmt-udev) continue ;;
    lomoco.sh) continue ;;
    mtd_probe) ;;
    mtp-probe) ;;
    numlock-on) continue ;;
    openct_pcmcia) continue ;;
    openct_serial) continue ;;
    openct_usb) continue ;;
    pcmcia-check-broken-cis) continue ;;
    pcmcia-socket-startup) continue ;;
    probe-bcache) ;;
    scsi_id) ;;
    udev-acl) continue ;;
    udev-add-printer) continue ;;
    udev-configure-printer) continue ;;
    udevmountd) continue ;;
    udisks-dm-export) ;;
    udisks-part-id) ;;
    udisks-probe-ata-smart) ;;
    udisks-probe-sas-expander) ;;
    usb_modeswitch) continue ;;
    v4l_id) continue ;;
    write_dev_root_rule) continue ;;
    *) ;;
    esac
    if [ ! -d "$script" ] && [ -x "$script" ] ; then
        cp_bin $script ${tmp_mnt}${script}
    elif [ -f "$script" ] ; then
        cp -pL $script ${tmp_mnt}${script}
    fi
done

# copy needed rules
for rule in \
    05-udev-early.rules \
    50-udev-default.rules \
    50-firmware.rules \
    59-dasd.rules \
    60-persistent-storage.rules \
    60-persistent-input.rules \
    61-msft.rules \
    62-dm_linear.rules \
    64-device-mapper.rules \
    65-cciss-compat.rules \
    69-bcache.rules \
    79-kms.rules \
    80-drivers.rules \
    80-net-name-slot.rules \
    ; do
    if [ -f /usr/lib/udev/rules.d/$rule ]; then
        cp /usr/lib/udev/rules.d/$rule $tmp_mnt/usr/lib/udev/rules.d
    elif [ -f /lib/udev/rules.d/$rule ]; then
        cp /lib/udev/rules.d/$rule $tmp_mnt/lib/udev/rules.d
    elif [ -f /etc/udev/rules.d/$rule ]; then
        cp /etc/udev/rules.d/$rule $tmp_mnt/etc/udev/rules.d
    fi
done

cp -t $tmp_mnt/usr/lib/udev/hwdb.d \
    /usr/lib/udev/hwdb.d/*pci*.hwdb \
    /usr/lib/udev/hwdb.d/*acpi*.hwdb \
    /usr/lib/udev/hwdb.d/*usb*.hwdb

save_var udev_timeout
