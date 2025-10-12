#!/bin/bash

dir=$(cd $(dirname $0); pwd -P)
cmd=$(basename $0)

disks=$(lsblk -n -l -o type,name |  grep -E "^disk\s" | cut -d' ' -f2)
[ $? -ne 0 ] && { echo "Cannot get disks by lsblk -n -l -o type,name'"; exit 1; }

usage()
{
  echo "Usage: <script> $(echo $disks | tr ' ' '|') <host name> <user name> [<password>]"; exit 1
}

run()
{
  echo "Run '$@'"; "$@"; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

set_password()
{
    read -rs -p "New password: " pass_01; echo ""
    read -rs -p "Retype new password: " pass_02; echo ""
    if [[ "$pass_01" != "$pass_02" ]] ; then
      echo "Sorry, passwords do not match."
      set_password
    elif [[ -z "$pass_01"  ]] ; then
      echo "Sorry, password should not be empty."
      set_password
    else
      pass="$pass_01"
    fi
}

firm_efi=/sys/firmware/efi
arch_rel=/etc/arch-release
pacm_lck=/var/lib/pacman/db.lck

[ ! -d $firm_efi ] && { echo "This script must be run under efi boot"; exit -1; }
[ $(id -u) -ne 0 ] && { echo "This script must be run under root user"; exit -1; }
[ ! -e $arch_rel ] && { echo "This script must be run in 'arch linux'"; exit -1; }
[   -f $pacm_lck ] && { echo "Packman is locked, check file $pacm_lck"; exit -1; }

disk=$1; [ -z $disk ] && { usage; exit -1; }
host=$2; [ -z $host ] && { usage; exit -1; }
user=$3; [ -z $user ] && { usage; exit -1; }
pass=$4

# set up size of root partition
typeset -i rsize=$5; [ $rsize -ne 0 ] && rs="+${rsize}G" || rs="-${rsize}"

# set up optional extra partition with name passed, if size of root partition is passed
extra=$6; [ $extra ] && [ $rsize -eq 0 ] && { echo "To create extra partition, you should pass size of root partition"; exit 1; }

# set optional bootloader-id
boot_id=$7; [ -z $boot_id ] && boot_id="ArchLinux"

# set optional removable option for disk
disk_rm=$8

# set optional crypt device for disk, it will be crypt device name in /dev/mapper
crypt_device=$9; [ ! -z $crypt_device ] && cryptsetup_pkg="cryptsetup"

ptype_boot="ef00" # EFI system partition
ptype_glfs="8300" # Generic Linux filesystem, including ext4, brtfs
ptype_luks="8309" # Linux LUKS

if [ -z $crypt_device ] ; then
   ptype_root=${ptype_glfs}
else
   ptype_root=${ptype_luks}
fi

# partitions, n is incremental count started form 1
# /dev/sdXn - mandatory - EFI, 1G default size
# /dev/sdXn - mandatory - root, size is optional, size is til the end of disk by default
# /dev/sdXn - optional  - <name>,  mounted to /, size is til the end of disk

echo "$disks" | grep -E "^${disk}$" > /dev/null 2>&1
[ $? -ne 0 ] && { echo "Disk $disk is not found"; exit -1; }

dzap=1 # Zap (destroy) the GPT and MBR data structures on disk by default
boot_part=1
root_part=2
extra_part=3
batch_mode=1

# Check if disk is empty
lsblk -n -l -o type,name | grep -E "^part\s+$disk" > /dev/null 2>&1
if [ $? -eq 0 ] ; then
  batch_mode= # need to answer some questions
  lsblk /dev/$disk -o "name,partlabel,label,size,fsused,UUID,model"
  read -r -p "Disk $disk has partitions (see above), remove them? (y|n) " answer
  [[ $answer == [yY] ]] || dzap= # keep disk partitions as is
  if [ -z $dzap ] ; then
      read -r -p "Enter boot partition number for disk $disk " boot_part
      read -r -p "Enter root partition number for disk $disk " root_part
      if [ $extra ] ; then
         read -r -p "Enter extra partition number for disk $disk " extra_part
      fi
  fi
  if [ -z $dzap ] ; then
     msg="Continue installation? (${disk}${root_part} partition will be formatted) (y|n) "
  else
     msg="Continue installation? ($disk will be erazed) (y|n) "
  fi
  read -r -p "$msg" answer
  [[ $answer == [yY] ]] || exit 0
fi

# get local timezone
tz_ipapi="https://ipapi.co/timezone"
tz_local=$(curl --fail -s $tz_ipapi)
[ -z $tz_local ] && { echo "Cannot obtain time zone from $tz_ipapi"; exit -1; }

# get local country
ifconfig_co="ifconfig.co/country-iso"
country=$(curl -4 --fail -s $ifconfig_co)
[ -z $country ] && { echo "Cannot obtain country from $ifconfig_co"; exit -1; }

# set password if needed
[ -z $pass ] && { echo "Password is not passed, set password for user '$user' manually"; set_password; }

echo "Installing arch linux"
echo "Diskname: $disk"
echo "Hostname: $host"
echo "Username: $user"
echo "Timezone: $tz_local"
echo "Country : $country"

# begin instalaltion, at first do the following:
# 1. set better terminal font
# 2. sync local time
# 3. uncoment parallel download in pacman config
# 4. sync package database (should already be synced by invocation script)
# 6. set up package download from country mirrors by using reflector
# 7. umount /tmp, just to be sure /tmp is ready for mount
run setfont ter-v22b
run timedatectl set-ntp true
run sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
run pacman -Sy 
# do not trust mirror list from reflector - http connections
# run cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
# run reflector --verbose -p https -a 48 -c $country -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

umount -A -R -q /mnt # just for sure, exits with code 1 if no mount

# set full disk name and partitons:
[[ $disk == "nvme"* ]] && p=p
devn="$disk"      # save  short device name
disk="/dev/$disk" # create full device name
par1=${disk}${p}${boot_part}
par2=${disk}${p}${root_part}
par3=${disk}${p}${extra_part}

check_partition()
{
   lsblk -l $1 | grep -q -E "^\b${2}\b" || { echo "$3 does not exist"; exit 1; }
}

if [ $dzap ] ; then
   echo "Disk $disk will be partitioned as follows"
   echo " EFI: $par1 : vfat"
   echo "ROOT: $par2 : btrfs"
   if [ $extra ] ; then
       echo "$extra: $par3 : ext4"
   fi
else
   run check_partition $disk ${devn}${p}${boot_part} $par1
   run check_partition $disk ${devn}${p}${root_part} $par2
   if [ $extra ] ; then
      run check_partition $disk ${devn}${p}${extra_part} $par3
   fi
   echo "$par2 will be formatted as btrfs partition"
   echo "$par1 will be mounted as /efi partition"
   if [ $extra ] ; then
      echo "$par3 will be mounted as /$extra partition"
   fi
fi

if [ ! -z $crypt_device ] ; then
   echo "LUKS1 will be set up on $par2 with name: $crypt_device"
fi

if [ -z $batch_mode ] ; then
  read -r -p "Continue installation? (y|n) " answer
  [[ $answer == [yY] ]] || exit 0
fi

if [ $dzap ] ; then
   # format disk as follows:
   # 1. Zap (destroy) the GPT and MBR data structures (-Z), clear partition table (--clear)
   # 2. Create new gpt disk 2048 alignment
   # 3. Create EFI partition
   # 4. Create ROOT partition 
   # 5. Inform the OS of partition table changes (partprobe)
   # 6. Format EFI, and ROOT partitions
   #    Notes: -c option is partlabel, -n and -L options are labels
   echo "Format $disk and mound partitions"
   run sgdisk -Z --clear ${disk}
   run sgdisk -a 2048 -o ${disk} 
   run sgdisk -n 1::+1G   -t 1:${ptype_boot} ${disk}
   run sgdisk -n 2::${rs} -t 2:${ptype_root} ${disk}

   if [ $extra ] ; then
     run sgdisk -n 3::-0 -t 3:${ptype_glfs} ${disk}
   fi

   run partprobe ${disk} 

   if [ $extra ] ; then
      run mkfs.ext4 -L $extra $par3
   fi
   run mkfs.fat -F32 -n EFI $par1
fi

if [ ! -z $crypt_device ] ; then
   # Encrypt partition (only LUKS1 works correctly)
   run cryptsetup --type luks1 luksFormat ${par2} <<< $pass
   run cryptsetup open ${par2} $crypt_device <<< $pass
   mdev="/dev/mapper/$crypt_device"
else
   mdev="$par2"
fi

run mkfs.btrfs -L "$boot_id" -f $mdev

run mount $mdev /mnt
run btrfs subvolume create /mnt/@
run btrfs subvolume create /mnt/@home
run btrfs subvolume create /mnt/@log
run btrfs subvolume create /mnt/@tmp
run btrfs subvolume create /mnt/@spool
run btrfs subvolume create /mnt/@cache
run btrfs subvolume create /mnt/@libvirt
run btrfs subvolume create /mnt/@snapshots

run umount /mnt

if [ ! -z $p ] ; then # nvme device
   #mo="rw,noatime,compress-force=zstd:1,space_cache=v2"
   mo="compress=zstd:1"
else
   mo="compress=zstd"
fi

run mount    -o ${mo},subvol=@          $mdev /mnt
run mount -m -o ${mo},subvol=@home      $mdev /mnt/home
run mount -m -o ${mo},subvol=@log       $mdev /mnt/var/log
run mount -m -o ${mo},subvol=@tmp       $mdev /mnt/var/tmp
run mount -m -o ${mo},subvol=@cache     $mdev /mnt/var/cache
run mount -m -o ${mo},subvol=@spool     $mdev /mnt/var/spool
run mount -m -o ${mo},subvol=@libvirt   $mdev /mnt/var/lib/libvirt
run mount -m -o ${mo},subvol=@snapshots $mdev /mnt/.shapshots

#run mount -m $par1 /mnt/boot/efi
run mount -m $par1 /mnt/efi

if [ $extra ] ; then
   run mount -m $par3 /mnt/$extra
fi

if [ ! -z $crypt_device ] ; then
   # Create key file
   key_file="/mnt/crypto_keyfile.bin"
   run dd bs=512 count=4 iflag=fullblock if=/dev/random of=$key_file
   run chmod 600 $key_file
   run cryptsetup luksAddKey ${par2} $key_file <<< $pass
fi

echo "Init pacman keys and pupulate them from archlinux"
run pacman-key --init
run pacman-key --populate archlinux

echo "Install essential packages (minimal)"
run pacstrap -K /mnt base linux linux-firmware sudo $cryptsetup_pkg

echo "Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab
[ $? -ne 0 ] && { echo "Cannot run 'genfstab -U /mnt >> /mnt/etc/fstab'"; exit -1; }

#echo "Save generated mirror list"
#run cp /mnt/etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.bak
#run cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
run cp -r ${dir} /mnt/root

( arch-chroot /mnt $HOME/$(basename $dir)/install_usr.sh "$host" "$user" "$pass" "$tz_local" "$boot_id" "$disk_rm" "$crypt_device" "$par2")

run touch /mnt/root/arch.exit.$?

exit 0

