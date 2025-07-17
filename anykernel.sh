## [Magisk & recovery/TWRP] [boot-patcher] [This is standalone script, not sourced] - uses ash
##
## AnyKernel3 Ramdisk Mod Script
##   Modified for NetHunter
##
## CREDITS to osm0sis @ xda-developers
##   REF: https://github.com/osm0sis/AnyKernel3/blob/ad53675d2e13e2b52adc706fb8492bfe5b76440b/anykernel.sh

#set -x

#------------------------------------------------------------------------------

## AnyKernel setup
# begin properties (./build.py will set these)
properties() { '
kernel.string=NetHunter kernel
do.devicecheck=0   # Use value 1 while using boot-patcher standalone
do.modules=0
do.systemless=0    # Never use this for NetHunter kernels as it prevents us from writing to /lib/modules
do.cleanup=0
do.cleanuponabort=0
device.name1=r8q
device.name2=
device.name3=
device.name4=
device.name5=
device.name6=
device.name7=
device.name8=
device.name9=
device.name10=
device.name11=
device.name12=
device.name13=
device.name14=
device.name15=
supported.versions=
'; } # end properties

# shell variables

## <NetHunter Addition>
ramdisk_compression=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
source tools/ak3-core.sh

## NetHunter additions
$BB mount -o rw,remount -t auto /system 2>/dev/null || $BB mount -o rw,remount -t auto / 2>/dev/null

SYSTEM="/system"
SYSTEM_ROOT="/system_root"

setperm() {
  find "$3" -type d -exec chmod "$1" {} \;
  find "$3" -type f -exec chmod "$2" {} \;
}

install() {
  setperm "$2" "$3" "$home$1"
  if [ "$4" ]; then
    cp -r "$home$1" "$(dirname "$4")/"
    return
  fi
  cp -r "$home$1" "$(dirname "$1")/"
}

[ -d $home/system/etc/firmware ] && {
  ui_print "- Copying firmware to $SYSTEM/etc/firmware"
  install "/system/etc/firmware" 0755 0644 "$SYSTEM/etc/firmware"
}

[ -d $home/system/etc/init.d ] && {
  ui_print "- Copying init.d scripts to $SYSTEM/etc/init.d"
  install "/system/etc/init.d" 0755 0755 "$SYSTEM/etc/init.d"
}

[ -d $home/system/lib ] && {
  ui_print "- Copying 32-bit shared libraries to ${SYSTEM}/lib"
  install "/system/lib" 0755 0644 "$SYSTEM/lib"
}

[ -d $home/system/lib64 ] && {
  ui_print "- Copying 64-bit shared libraries to ${SYSTEM}/lib"
  install "/system/lib64" 0755 0644 "$SYSTEM/lib64"
}

[ -d $home/system/bin ] && {
  ui_print "- Installing ${SYSTEM}/bin binaries"
  install "/system/bin" 0755 0755 "$SYSTEM/bin"
}

[ -d $home/system/xbin ] && {
  ui_print "- Installing ${SYSTEM}/xbin binaries"
  install "/system/xbin" 0755 0755 "$SYSTEM/xbin"
}

[ -d $home/data/local ] && {
  ui_print "- Copying additional files to /data/local"
  install "/data/local" 0755 0644
}

[ -d $home/vendor/etc/init ] && {
  ui_print "- Copying additional files to /vendor/etc/init/"
  mount /vendor
  chmod 644 $home/vendor/etc/init/*
  cp -r $home/vendor/etc/init/* /vendor/etc/init/
}

[ -d $home/ramdisk-patch ] && {
  ui_print "- Copying ramdisk-patch files to $SYSTEM_ROOT"
  setperm "0755" "0750" "$home/ramdisk-patch"
  chown root:shell $home/ramdisk-patch/*
  cp -rp $home/ramdisk-patch/* "$SYSTEM_ROOT/"
}

[ -e $SYSTEM_ROOT/init.rc ] && {
  ui_print "- Checking $SYSTEM_ROOT/init.rc"
  if [ ! "$(grep /init.nethunter.rc $SYSTEM_ROOT/init.rc)" ]; then
    ui_print "- Inserting into $SYSTEM_ROOT/init.rc"
    insert_after_last "$SYSTEM_ROOT/init.rc" "import .*\.rc" "import /init.nethunter.rc"
  fi
}

[ -e $SYSTEM_ROOT/ueventd.rc ] && {
  ui_print "- Checking $SYSTEM_ROOT/ueventd.rc"
  if [ ! "$(grep /dev/hidg* $SYSTEM_ROOT/ueventd.rc)" ]; then
    ui_print "- Inserting into $SYSTEM_ROOT/ueventd.rc"
    insert_after_last "$SYSTEM_ROOT/ueventd.rc" "/dev/kgsl.*root.*root" "# HID driver\n/dev/hidg* 0666 root root"
  fi
}

[ -e ak_patches/* ] && {
  ui_print "- Found additional anykernel installation patches"
  for p in $(find ak_patches/ -type f); do
    ui_print "- Applying $p"
    source $p
  done
}
## </NetHunter Addition>

## AnyKernel file attributes
##set permissions/ownership for included ramdisk files
ui_print "- Applying permissions"
set_perm_recursive 0 0 755 644 $ramdisk/*
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin

## AnyKernel install
dump_boot

write_boot
## end install

ui_print "- AnyKernel done"
