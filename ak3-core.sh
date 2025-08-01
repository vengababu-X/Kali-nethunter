## AnyKernel methods
##   Modified for NetHunter
##
## CREDITS to osm0sis @ xda-developers
##   REF: https://github.com/osm0sis/AnyKernel3/blob/49049132957f0850eef82eff6c7e85ad038ce174/tools/ak3-core.sh

# NetHunter additions
OUTFD=$(cat /tmp/console);
[ "$OUTFD" ] || OUTFD=/proc/$$/fd/1;

# set up working directory variables
[ "$home" ] || home=$PWD;
bootimg=$home/boot.img;
bin=$home/tools;
patch=$home/patch;
ramdisk=$home/ramdisk;
split_img=$home/split_img;

### output/testing functions:
# ui_print "<text>" [...]
ui_print() {
  until [ ! "$1" ]; do
    echo "ui_print $1
      ui_print" >> $OUTFD;
    shift;
  done;
}

# Nethunter Addition for automatic boot and slot detection
# ypicked from topjhonwu's magisk util_functions.sh
# ref: https://github.com/topjohnwu/Magisk/blob/master/scripts/util_functions.sh
grep_cmdline() {
  local REGEX="s/^$1=//p"
  cat /proc/cmdline | tr '[:space:]' '\n' | sed -n "$REGEX" 2>/dev/null
}

grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

get_flags() {
  [ -z $RECOVERYMODE ] && RECOVERYMODE=false
}

ab_slot() {
  SLOT=`grep_cmdline androidboot.slot_suffix`
  if [ -z $SLOT ]; then
    SLOT=`grep_cmdline androidboot.slot`
    [ -z $SLOT ] || SLOT=_${SLOT}
  fi
 }

find_block() {
  local BLOCK DEV DEVICE DEVNAME PARTNAME UEVENT
  for BLOCK in "$@"; do
    DEVICE=`find /dev/block \( -type b -o -type c -o -type l \) -iname $BLOCK | head -n 1` 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  # Fallback by parsing sysfs uevents
  for UEVENT in /sys/dev/block/*/uevent; do
    DEVNAME=`grep_prop DEVNAME $UEVENT`
    PARTNAME=`grep_prop PARTNAME $UEVENT`
    for BLOCK in "$@"; do
      if [ "$(toupper $BLOCK)" = "$(toupper $PARTNAME)" ]; then
        echo /dev/block/$DEVNAME
        return 0
      fi
    done
  done
  # Look just in /dev in case we're dealing with MTD/NAND without /dev/block devices/links
  for DEV in "$@"; do
    DEVICE=`find /dev \( -type b -o -type c -o -type l \) -maxdepth 1 -iname $DEV | head -n 1` 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  return 1
}

find_boot_image() {
  BOOTIMAGE=
  if $RECOVERYMODE; then
    BOOTIMAGE=`find_block recovery_ramdisk$SLOT recovery sos`
  elif [ ! -z $SLOT ]; then
    BOOTIMAGE=`find_block ramdisk$SLOT recovery_ramdisk$SLOT boot$SLOT`
  else
    BOOTIMAGE=`find_block ramdisk recovery_ramdisk kern-a android_boot kernel boot lnx bootimg boot_a`
  fi
  if [ -z $BOOTIMAGE ]; then
    # Lets see what fstabs tells me
    BOOTIMAGE=`grep -v '#' /etc/*fstab* | grep -E '/boot[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
  fi
}

# abort ["<text>" [...]]
abort() {
  ui_print " " "$@";
  exit 1;
}

# contains <string> <substring>
contains() {
  [ "${1#*$2}" != "$1" ];
}

# file_getprop <file> <property>
file_getprop() {
  grep "^$2=" "$1" | cut -d= -f2-;
}
###

### file/directory attributes functions:
# set_perm <owner> <group> <mode> <file> [<file2> ...]
set_perm() {
  local uid gid mod;
  uid=$1; gid=$2; mod=$3;
  shift 3;
  chown $uid:$gid "$@" || chown $uid.$gid "$@";
  chmod $mod "$@";
}

# set_perm_recursive <owner> <group> <dir_mode> <file_mode> <dir> [<dir2> ...]
set_perm_recursive() {
  local uid gid dmod fmod;
  uid=$1; gid=$2; dmod=$3; fmod=$4;
  shift 4;
  while [ "$1" ]; do
    chown -R $uid:$gid "$1" || chown -R $uid.$gid "$1";
    find "$1" -type d -exec chmod $dmod {} +;
    find "$1" -type f -exec chmod $fmod {} +;
    shift;
  done;
}
###

### dump_boot functions:
# split_boot (dump and split image only)
split_boot() {
  local dumpfail;

  if [ ! -e "$(echo $BOOTIMAGE | cut -d\  -f1)" ]; then
    abort "Invalid partition. Aborting...";
  fi;
  if [ "$(echo $BOOTIMAGE | grep ' ')" ]; then
    block=$(echo $BOOTIMAGE | cut -d\  -f1);
    customdd=$(echo $BOOTIMAGE | cut -d\  -f2-);
  elif [ ! "$customdd" ]; then
    local customdd="bs=1048576";
  fi;
  if [ -f "$bin/nanddump" ]; then
    $bin/nanddump -f $bootimg $BOOTIMAGE;
  else
    dd if=$BOOTIMAGE of=$bootimg $customdd;
  fi;
  [ $? != 0 ] && dumpfail=1;

  mkdir -p $split_img;
  cd $split_img;
  if [ -f "$bin/unpackelf" ] && $bin/unpackelf -i $bootimg -h -q 2>/dev/null; then
    if [ -f "$bin/elftool" ]; then
      mkdir elftool_out;
      $bin/elftool unpack -i $bootimg -o elftool_out;
    fi;
    $bin/unpackelf -i $bootimg;
    [ $? != 0 ] && dumpfail=1;
    mv -f boot.img-kernel kernel.gz;
    mv -f boot.img-ramdisk ramdisk.cpio.gz;
    mv -f boot.img-cmdline cmdline.txt 2>/dev/null;
    if [ -f boot.img-dt -a ! -f "$bin/elftool" ]; then
      case $(od -ta -An -N4 boot.img-dt | sed -e 's/ del//' -e 's/   //g') in
        QCDT|ELF) mv -f boot.img-dt dt;;
        *)
          gzip -c kernel.gz > kernel.gz-dtb;
          cat boot.img-dt >> kernel.gz-dtb;
          rm -f boot.img-dt kernel.gz;
        ;;
      esac;
    fi;
  elif [ -f "$bin/mboot" ]; then
    $bin/mboot -u -f $bootimg;
  elif [ -f "$bin/dumpimage" ]; then
    dd bs=$(($(printf '%d\n' 0x$(hexdump -n 4 -s 12 -e '16/1 "%02x""\n"' $bootimg)) + 64)) count=1 conv=notrunc if=$bootimg of=boot-trimmed.img;
    $bin/dumpimage -l boot-trimmed.img > header;
    grep "Name:" header | cut -c15- > boot.img-name;
    grep "Type:" header | cut -c15- | cut -d\  -f1 > boot.img-arch;
    grep "Type:" header | cut -c15- | cut -d\  -f2 > boot.img-os;
    grep "Type:" header | cut -c15- | cut -d\  -f3 | cut -d- -f1 > boot.img-type;
    grep "Type:" header | cut -d\( -f2 | cut -d\) -f1 | cut -d\  -f1 | cut -d- -f1 > boot.img-comp;
    grep "Address:" header | cut -c15- > boot.img-addr;
    grep "Point:" header | cut -c15- > boot.img-ep;
    $bin/dumpimage -p 0 -o kernel.gz boot-trimmed.img;
    [ $? != 0 ] && dumpfail=1;
    case $(cat boot.img-type) in
      Multi) $bin/dumpimage -p 1 -o ramdisk.cpio.gz boot-trimmed.img;;
      RAMDisk) mv -f kernel.gz ramdisk.cpio.gz;;
    esac;
  elif [ -f "$bin/rkcrc" ]; then
    dd bs=4096 skip=8 iflag=skip_bytes conv=notrunc if=$bootimg of=ramdisk.cpio.gz;
  else
    $bin/magiskboot unpack -h $bootimg;
    case $? in
      1) dumpfail=1;;
      2) touch chromeos;;
    esac;
  fi;

  if [ $? != 0 -o "$dumpfail" ]; then
    abort "Dumping/splitting image failed. Aborting...";
  fi;
  cd $home;
}

# unpack_ramdisk (extract ramdisk only)
unpack_ramdisk() {
  local comp;

  cd $split_img;
  if [ -f ramdisk.cpio.gz ]; then
    if [ -f "$bin/mkmtkhdr" ]; then
      mv -f ramdisk.cpio.gz ramdisk.cpio.gz-mtk;
      dd bs=512 skip=1 conv=notrunc if=ramdisk.cpio.gz-mtk of=ramdisk.cpio.gz;
    fi;
    mv -f ramdisk.cpio.gz ramdisk.cpio;
  fi;

  if [ -f ramdisk.cpio ]; then
    comp=$($bin/magiskboot decompress ramdisk.cpio 2>&1 | grep -v 'raw' | sed -n 's;.*\[\(.*\)\];\1;p');
  else
    abort "No ramdisk found to unpack. Aborting...";
  fi;
  if [ "$comp" ]; then
    mv -f ramdisk.cpio ramdisk.cpio.$comp;
    $bin/magiskboot decompress ramdisk.cpio.$comp ramdisk.cpio;
    if [ $? != 0 ]; then
      echo "Attempting ramdisk unpack with busybox $comp..." >&2;
      $comp -dc ramdisk.cpio.$comp > ramdisk.cpio;
    fi;
  fi;

  [ -d $ramdisk ] && mv -f $ramdisk $home/rdtmp;
  mkdir -p $ramdisk;
  chmod 755 $ramdisk;

  cd $ramdisk;
  EXTRACT_UNSAFE_SYMLINKS=1 cpio -d -F $split_img/ramdisk.cpio -i;
  if [ $? != 0 -o ! "$(ls)" ]; then
    abort "Unpacking ramdisk failed. Aborting...";
  fi;
  if [ -d "$home/rdtmp" ]; then
    cp -af $home/rdtmp/* .;
  fi;
}
### dump_boot (dump and split image, then extract ramdisk)
dump_boot() {
  ui_print "- Unpacking boot image";
  split_boot;
  ui_print "- Unpacking ramdisk";
  unpack_ramdisk;
}
###

### write_boot functions:
# repack_ramdisk (repack ramdisk only)
repack_ramdisk() {
  local comp packfail mtktype;

  cd $home;
  case $ramdisk_compression in
    auto|"") comp=$(ls $split_img/ramdisk.cpio.* 2>/dev/null | grep -v 'mtk' | rev | cut -d. -f1 | rev);;
    none|cpio) comp="";;
    gz) comp=gzip;;
    lzo) comp=lzop;;
    bz2) comp=bzip2;;
    lz4-l) comp=lz4_legacy;;
    *) comp=$ramdisk_compression;;
  esac;

  if [ -f "$bin/mkbootfs" ]; then
    $bin/mkbootfs $ramdisk > ramdisk-new.cpio;
  else
    cd $ramdisk;
    find . | cpio -H newc -o > $home/ramdisk-new.cpio;
  fi;
  [ $? != 0 ] && packfail=1;

  cd $home;
  $bin/magiskboot cpio ramdisk-new.cpio test;
  magisk_patched=$?;
  [ $((magisk_patched & 3)) -eq 1 ] && $bin/magiskboot cpio ramdisk-new.cpio "extract .backup/.magisk $split_img/.magisk";
  if [ "$comp" ]; then
    $bin/magiskboot compress=$comp ramdisk-new.cpio;
    if [ $? != 0 ]; then
      echo "Attempting ramdisk repack with busybox $comp..." >&2;
      $comp -9c ramdisk-new.cpio > ramdisk-new.cpio.$comp;
      [ $? != 0 ] && packfail=1;
      rm -f ramdisk-new.cpio;
    fi;
  fi;
  if [ "$packfail" ]; then
    abort "Repacking ramdisk failed. Aborting...";
  fi;

  if [ -f "$bin/mkmtkhdr" -a -f "$split_img/boot.img-base" ]; then
    mtktype=$(od -ta -An -N8 -j8 $split_img/ramdisk.cpio.gz-mtk | sed -e 's/ nul//g' -e 's/   //g' | tr '[:upper:]' '[:lower:]');
    case $mtktype in
      rootfs|recovery) $bin/mkmtkhdr --$mtktype ramdisk-new.cpio*;;
    esac;
  fi;
}

# flash_boot (build, sign and write image only)
flash_boot() {
  local varlist i kernel ramdisk fdt cmdline comp part0 part1 nocompflag signfail pk8 cert avbtype;

  cd $split_img;
  if [ -f "$bin/mkimage" ]; then
    varlist="name arch os type comp addr ep";
  elif [ -f "$bin/mkbootimg" -a -f "$bin/unpackelf" -a -f boot.img-base ]; then
    mv -f cmdline.txt boot.img-cmdline 2>/dev/null;
    varlist="cmdline base pagesize kernel_offset ramdisk_offset tags_offset";
  fi;
  for i in $varlist; do
    if [ -f boot.img-$i ]; then
      eval local $i=\"$(cat boot.img-$i)\";
    fi;
  done;

  cd $home;
  for i in zImage zImage-dtb Image Image-dtb Image.gz Image.gz-dtb Image.bz2 Image.bz2-dtb Image.lzo Image.lzo-dtb Image.lzma Image.lzma-dtb Image.xz Image.xz-dtb Image.lz4 Image.lz4-dtb Image.fit; do
    if [ -f $i ]; then
      kernel=$home/$i;
      break;
    fi;
  done;
  if [ "$kernel" ]; then
    if [ -f "$bin/mkmtkhdr" -a -f "$split_img/boot.img-base" ]; then
      $bin/mkmtkhdr --kernel $kernel;
      kernel=$kernel-mtk;
    fi;
  elif [ "$(ls $split_img/kernel* 2>/dev/null)" ]; then
    kernel=$(ls $split_img/kernel* | grep -v 'kernel_dtb' | tail -n1);
  fi;
  if [ "$(ls ramdisk-new.cpio* 2>/dev/null)" ]; then
    ramdisk=$home/$(ls ramdisk-new.cpio* | tail -n1);
  elif [ -f "$bin/mkmtkhdr" -a -f "$split_img/boot.img-base" ]; then
    ramdisk=$split_img/ramdisk.cpio.gz-mtk;
  else
    ramdisk=$(ls $split_img/ramdisk.cpio* 2>/dev/null | tail -n1);
  fi;
  for fdt in dt recovery_dtbo dtb; do
    for i in $home/$fdt $home/$fdt.img $split_img/$fdt; do
      if [ -f $i ]; then
        eval local $fdt=$i;
        break;
      fi;
    done;
  done;

  cd $split_img;
  if [ -f "$bin/mkimage" ]; then
    [ "$comp" == "uncompressed" ] && comp=none;
    part0=$kernel;
    case $type in
      Multi) part1=":$ramdisk";;
      RAMDisk) part0=$ramdisk;;
    esac;
    $bin/mkimage -A $arch -O $os -T $type -C $comp -a $addr -e $ep -n "$name" -d $part0$part1 $home/boot-new.img;
  elif [ -f "$bin/elftool" ]; then
    [ "$dt" ] && dt="$dt,rpm";
    [ -f cmdline.txt ] && cmdline="cmdline.txt@cmdline";
    $bin/elftool pack -o $home/boot-new.img header=elftool_out/header $kernel $ramdisk,ramdisk $dt $cmdline;
  elif [ -f "$bin/mboot" ]; then
    cp -f $kernel kernel;
    cp -f $ramdisk ramdisk.cpio.gz;
    $bin/mboot -d $split_img -f $home/boot-new.img;
  elif [ -f "$bin/rkcrc" ]; then
    $bin/rkcrc -k $ramdisk $home/boot-new.img;
  elif [ -f "$bin/mkbootimg" -a -f "$bin/unpackelf" -a -f boot.img-base ]; then
    [ "$dt" ] && dt="--dt $dt";
    $bin/mkbootimg --kernel $kernel --ramdisk $ramdisk --cmdline "$cmdline" --base $base --pagesize $pagesize --kernel_offset $kernel_offset --ramdisk_offset $ramdisk_offset --tags_offset "$tags_offset" $dt --output $home/boot-new.img;
  else
    [ "$kernel" ] && cp -f $kernel kernel;
    [ "$ramdisk" ] && cp -f $ramdisk ramdisk.cpio;
    [ "$dt" -a -f extra ] && cp -f $dt extra;
    for i in dtb recovery_dtbo; do
      [ "$(eval echo \$$i)" -a -f $i ] && cp -f $(eval echo \$$i) $i;
    done;
    case $kernel in
      *Image*)
        if [ ! "$magisk_patched" ]; then
          $bin/magiskboot cpio ramdisk.cpio test;
          magisk_patched=$?;
        fi;
        if [ $((magisk_patched & 3)) -eq 1 ]; then
          ui_print "- Magisk detected! Patching kernel so reflashing Magisk is not necessary...";
          comp=$($bin/magiskboot decompress kernel 2>&1 | grep -v 'raw' | sed -n 's;.*\[\(.*\)\];\1;p');
          ($bin/magiskboot split $kernel || $bin/magiskboot decompress $kernel kernel) 2>/dev/null;
          if [ $? != 0 -a "$comp" ]; then
            echo "Attempting kernel unpack with busybox $comp..." >&2;
            $comp -dc $kernel > kernel;
          fi;
          $bin/magiskboot hexpatch kernel 736B69705F696E697472616D667300 77616E745F696E697472616D667300;
          if [ "$(file_getprop $home/anykernel.sh do.systemless)" == 1 ]; then
            strings kernel | grep -E 'Linux version.*#' > $home/vertmp;
          fi;
          if [ "$comp" ]; then
            $bin/magiskboot compress=$comp kernel kernel.$comp;
            if [ $? != 0 ]; then
              echo "Attempting kernel repack with busybox $comp..." >&2;
              $comp -9c kernel > kernel.$comp;
            fi;
            mv -f kernel.$comp kernel;
          fi;
          [ ! -f .magisk ] && $bin/magiskboot cpio ramdisk.cpio "extract .backup/.magisk .magisk";
          export $(cat .magisk);
          [ $((magisk_patched & 8)) -ne 0 ] && export TWOSTAGEINIT=true;
          for fdt in dtb extra kernel_dtb recovery_dtbo; do
            [ -f $fdt ] && $bin/magiskboot dtb $fdt patch;
          done;
        else
          case $kernel in
            *-dtb) rm -f kernel_dtb;;
          esac;
        fi;
        unset magisk_patched KEEPFORCEENCRYPT KEEPVERITY SHA1 TWOSTAGEINIT;
      ;;
    esac;
    case $ramdisk_compression in
      none|cpio) nocompflag="-n";;
    esac;
    $bin/magiskboot repack $nocompflag $bootimg $home/boot-new.img;
  fi;
  if [ $? != 0 ]; then
    abort "Repacking image failed. Aborting...";
  fi;

  cd $home;
  if [ -f "$bin/futility" -a -d "$bin/chromeos" ]; then
    if [ -f "$split_img/chromeos" ]; then
      echo "- Signing with CHROMEOS..." >&2;
      $bin/futility vbutil_kernel --pack boot-new-signed.img --keyblock $bin/chromeos/kernel.keyblock --signprivate $bin/chromeos/kernel_data_key.vbprivk --version 1 --vmlinuz boot-new.img --bootloader $bin/chromeos/empty --config $bin/chromeos/empty --arch arm --flags 0x1;
    fi;
    [ $? != 0 ] && signfail=1;
  fi;
  if [ -f "$bin/boot_signer-dexed.jar" -a -d "$bin/avb" ]; then
    pk8=$(ls $bin/avb/*.pk8);
    cert=$(ls $bin/avb/*.x509.*);
    case $BOOTIMAGE in
      *recovery*|*SOS*) avbtype=recovery;;
      *) avbtype=boot;;
    esac;
    if [ "$(/system/bin/dalvikvm -Xnoimage-dex2oat -cp $bin/boot_signer-dexed.jar com.android.verity.BootSignature -verify boot.img 2>&1 | grep VALID)" ]; then
      echo "- Signing with AVBv1..." >&2;
      /system/bin/dalvikvm -Xnoimage-dex2oat -cp $bin/boot_signer-dexed.jar com.android.verity.BootSignature /$avbtype boot-new.img $pk8 $cert boot-new-signed.img;
    fi;
  fi;
  if [ $? != 0 -o "$signfail" ]; then
    abort "Signing image failed. Aborting...";
  fi;
  mv -f boot-new-signed.img boot-new.img 2>/dev/null;

  if [ ! -f boot-new.img ]; then
    abort "No repacked image found to flash. Aborting...";
  elif [ "$(wc -c < boot-new.img)" -gt "$(wc -c < boot.img)" ]; then
    abort "New image larger than boot partition. Aborting...";
  fi;
  blockdev --setrw $BOOTIMAGE 2>/dev/null;
  if [ -f "$bin/flash_erase" -a -f "$bin/nandwrite" ]; then
    $bin/flash_erase $BOOTIMAGE 0 0;
    $bin/nandwrite -p $BOOTIMAGE boot-new.img;
  elif [ "$customdd" ]; then
    dd if=/dev/zero of=$BOOTIMAGE $customdd 2>/dev/null;
    dd if=boot-new.img of=$BOOTIMAGE $customdd;
  else
    cat boot-new.img /dev/zero > $BOOTIMAGE 2>/dev/null || true;
  fi;
  if [ $? != 0 ]; then
    abort "Flashing image failed. Aborting...";
  else
    ui_print "- Flashed new bootimage"
  fi;
}

# flash_dtbo (flash dtbo only)
flash_dtbo() {
  local i dtbo dtboblock;
  ab_slot;

  cd $home;
  for i in dtbo dtbo.img; do
    if [ -f $i ]; then
      dtbo=$i;
      break;
    fi;
  done;

  if [ "$dtbo" ]; then
    dtboblock=/dev/block/bootdevice/by-name/dtbo$SLOT;
    if [ ! -e "$dtboblock" ]; then
      abort "dtbo partition could not be found. Aborting...";
    fi;
    blockdev --setrw $dtboblock 2>/dev/null;
    if [ -f "$bin/flash_erase" -a -f "$bin/nandwrite" ]; then
      $bin/flash_erase $dtboblock 0 0;
      $bin/nandwrite -p $dtboblock $dtbo;
    elif [ "$customdd" ]; then
      dd if=/dev/zero of=$dtboblock 2>/dev/null;
      dd if=$dtbo of=$dtboblock;
    else
      cat $dtbo /dev/zero > $dtboblock 2>/dev/null || true;
    fi;
    if [ $? != 0 ]; then
      abort "Flashing dtbo failed. Aborting...";
    else
      ui_print "- Flashed new dtbo";
    fi;
  fi;
}
### write_boot (repack ramdisk then build, sign and write image and dtbo)
write_boot() {
  ui_print "- Repacking ramdisk";
  repack_ramdisk;
  flash_boot;
  flash_dtbo;
}
###

### file editing functions:
# backup_file <file>
backup_file() { [ ! -f $1~ ] && cp -fp $1 $1~; }

# restore_file <file>
restore_file() { [ -f $1~ ] && cp -fp $1~ $1; rm -f $1~; }

# replace_string <file> <if search string> <original string> <replacement string> <scope>
replace_string() {
  [ "$5" == "global" ] && local scope=g;
  if ! grep -q "$2" $1; then
    sed -i "s;${3};${4};${scope}" $1;
  fi;
}

# replace_section <file> <begin search string> <end search string> <replacement string>
replace_section() {
  local begin endstr last end;
  begin=$(grep -n "$2" $1 | head -n1 | cut -d: -f1);
  if [ "$begin" ]; then
    if [ "$3" == " " -o ! "$3" ]; then
      endstr='^[[:space:]]*$';
      last=$(wc -l $1 | cut -d\  -f1);
    else
      endstr="$3";
    fi;
    for end in $(grep -n "$endstr" $1 | cut -d: -f1) $last; do
      if [ "$end" ] && [ "$begin" -lt "$end" ]; then
        sed -i "${begin},${end}d" $1;
        [ "$end" == "$last" ] && echo >> $1;
        sed -i "${begin}s;^;${4}\n;" $1;
        break;
      fi;
    done;
  fi;
}

# remove_section <file> <begin search string> <end search string>
remove_section() {
  local begin endstr last end;
  begin=$(grep -n "$2" $1 | head -n1 | cut -d: -f1);
  if [ "$begin" ]; then
    if [ "$3" == " " -o ! "$3" ]; then
      endstr='^[[:space:]]*$';
      last=$(wc -l $1 | cut -d\  -f1);
    else
      endstr="$3";
    fi;
    for end in $(grep -n "$endstr" $1 | cut -d: -f1) $last; do
      if [ "$end" ] && [ "$begin" -lt "$end" ]; then
        sed -i "${begin},${end}d" $1;
        break;
      fi;
    done;
  fi;
}

# insert_line <file> <if search string> <before|after> <line match string> <inserted line>
insert_line() {
  local offset line;
  if ! grep -q "$2" $1; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    if [ -f $1 -a "$line" ] && [ "$(wc -l $1 | cut -d\  -f1)" -lt "$line" ]; then
      echo "$5" >> $1;
    else
      sed -i "${line}s;^;${5}\n;" $1;
    fi;
  fi;
}

# replace_line <file> <line replace string> <replacement line> <scope>
replace_line() {
  local lines line;
  if grep -q "$2" $1; then
    lines=$(grep -n "$2" $1 | cut -d: -f1 | sort -nr);
    [ "$4" == "global" ] || lines=$(echo "$lines" | tail -n1);
    for line in $lines; do
      sed -i "${line}s;.*;${3};" $1;
    done;
  fi;
}

# remove_line <file> <line match string> <scope>
remove_line() {
  local lines line;
  if grep -q "$2" $1; then
    lines=$(grep -n "$2" $1 | cut -d: -f1 | sort -nr);
    [ "$3" == "global" ] || lines=$(echo "$lines" | tail -n1);
    for line in $lines; do
      sed -i "${line}d" $1;
    done;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if ! grep -q "$2" $1; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# insert_file <file> <if search string> <before|after> <line match string> <patch file>
insert_file() {
  local offset line;
  if ! grep -q "$2" $1; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

insert_after_last() {
	grep -q "^$3$" "$1" || {
		line=$(($(grep -n "^[[:space:]]*$2[[:space:]]*$" "$1" | tail -1 | cut -d: -f1) + 1));
		sed -i "${line}i$3" "$1";
	}
}

# append_file <file> <if search string> <patch file>
append_file() {
  if ! grep -q "$2" $1; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

# replace_file <file> <permissions> <patch file>
replace_file() {
  cp -pf $patch/$3 $1;
  chmod $2 $1;
}

# patch_fstab <fstab file> <mount match name> <fs match type> block|mount|fstype|options|flags <original string> <replacement string>
patch_fstab() {
  local entry part newpart newentry;
  entry=$(grep "$2" $1 | grep "$3");
  if [ ! "$(echo "$entry" | grep "$6")" -o "$6" == " " -o ! "$6" ]; then
    case $4 in
      block) part=$(echo "$entry" | awk '{ print $1 }');;
      mount) part=$(echo "$entry" | awk '{ print $2 }');;
      fstype) part=$(echo "$entry" | awk '{ print $3 }');;
      options) part=$(echo "$entry" | awk '{ print $4 }');;
      flags) part=$(echo "$entry" | awk '{ print $5 }');;
    esac;
    newpart=$(echo "$part" | sed -e "s;${5};${6};" -e "s; ;;g" -e 's;,\{2,\};,;g' -e 's;,*$;;g' -e 's;^,;;g');
    newentry=$(echo "$entry" | sed "s;${part};${newpart};");
    sed -i "s;${entry};${newentry};" $1;
  fi;
}

# patch_cmdline <cmdline entry name> <replacement string>
patch_cmdline() {
  local cmdfile cmdtmp match;
  if [ -f "$split_img/cmdline.txt" ]; then
    cmdfile=$split_img/cmdline.txt;
  else
    cmdfile=$home/cmdtmp;
    grep "^cmdline=" $split_img/header | cut -d= -f2- > $cmdfile;
  fi;
  if ! grep -q "$1" $cmdfile; then
    cmdtmp=$(cat $cmdfile);
    echo "$cmdtmp $2" > $cmdfile;
    sed -i -e 's;  *; ;g' -e 's;[ \t]*$;;' $cmdfile;
  else
    match=$(grep -o "$1.*$" $cmdfile | cut -d\  -f1);
    sed -i -e "s;${match};${2};" -e 's;  *; ;g' -e 's;[ \t]*$;;' $cmdfile;
  fi;
  if [ -f "$home/cmdtmp" ]; then
    sed -i "s|^cmdline=.*|cmdline=$(cat $cmdfile)|" $split_img/header;
    rm -f $cmdfile;
  fi;
}

# patch_prop <prop file> <prop name> <new prop value>
patch_prop() {
  if ! grep -q "^$2=" $1; then
    echo -ne "\n$2=$3\n" >> $1;
  else
    local line=$(grep -n "^$2=" $1 | head -n1 | cut -d: -f1);
    sed -i "${line}s;.*;${2}=${3};" $1;
  fi;
}

# patch_ueventd <ueventd file> <device node> <permissions> <chown> <chgrp>
patch_ueventd() {
  local file dev perm user group newentry line;
  file=$1; dev=$2; perm=$3; user=$4;
  shift 4;
  group="$@";
  newentry=$(printf "%-23s   %-4s   %-8s   %s\n" "$dev" "$perm" "$user" "$group");
  line=$(grep -n "$dev" $file | head -n1 | cut -d: -f1);
  if [ "$line" ]; then
    sed -i "${line}s;.*;${newentry};" $file;
  else
    echo -ne "\n$newentry\n" >> $file;
  fi;
}
###

### configuration/setup functions:
# reset_ak [keep]
reset_ak() {
  local current i;

  current=$(dirname $home/*-files/current);
  if [ -d "$current" ]; then
    rm -rf $current/ramdisk;
    for i in $bootimg boot-new.img; do
      [ -e $i ] && cp -af $i $current;
    done;
  fi;
  [ -d $split_img ] && rm -rf $ramdisk;
  rm -rf $bootimg $split_img $home/*-new* $home/*-files/current;

  if [ "$1" == "keep" ]; then
    [ -d $home/rdtmp ] && mv -f $home/rdtmp $ramdisk;
  else
    rm -rf $patch $home/rdtmp;
  fi;
  setup_ak;
}

# setup_ak
setup_ak() {
  local blockfiles parttype name part mtdmount mtdpart mtdname target;

  # allow multi-partition ramdisk modifying configurations (using reset_ak)
  if [ "$BOOTIMAGE" ] && [ ! -d "$ramdisk" -a ! -d "$patch" ]; then
    blockfiles=$home/$(basename $BOOTIMAGE)-files;
    if [ "$(ls $blockfiles 2>/dev/null)" ]; then
      cp -af $blockfiles/* $home;
    else
      mkdir -p $blockfiles;
    fi;
    touch $blockfiles/current;
  fi;

# NetHunter Addition 
# Check device is either A/B or A only
ab_slot;
[ -z $SLOT ] || ui_print "- A/B device Detected. Current slot: $SLOT"

# find boot image using find block,get_flags and find_boot_image function
get_flags;
find_boot_image;
ui_print "- Target Image: $BOOTIMAGE";
}
###

### end methods

setup_ak;
