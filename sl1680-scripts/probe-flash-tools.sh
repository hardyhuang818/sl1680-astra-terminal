#!/bin/bash
# Find how Astra SL1680 images are flashed (USB boot tool / scripts / docs).

echo "############ flashing tools / scripts in meta-synaptics ############"
grep -rilE 'usb_boot|usbboot|fastboot|genimage|flash|burn' ~/sdk/meta-synaptics/ 2>/dev/null | grep -iE '\.sh$|\.py$|\.md$|\.rst$|README|\.bb$' | head -30

echo
echo "############ SYNAIMG contents for an already-built machine (sl2619) ############"
ls -la ~/sdk/build-sl2619/tmp/deploy/images/sl2619/SYNAIMG/ 2>/dev/null | head
echo "--- emmc_image_list ---"
cat ~/sdk/build-sl2619/tmp/deploy/images/sl2619/SYNAIMG/emmc_image_list 2>/dev/null
echo "--- emmc_part_list ---"
cat ~/sdk/build-sl2619/tmp/deploy/images/sl2619/SYNAIMG/emmc_part_list 2>/dev/null

echo
echo "############ any usb_boot / flashing helper in deploy or SDK ############"
find ~/sdk -iname '*usb*boot*' -o -iname '*fastboot*' -o -iname '*.subimg' 2>/dev/null | grep -viE 'work/|sstate' | head -20

echo
echo "############ dolphin (sl1680) usb machine hints ############"
cat ~/sdk/meta-synaptics/conf/machine/sl1680usb.conf 2>/dev/null | head -30
