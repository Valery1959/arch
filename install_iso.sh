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
extra=$6; [ $extra ] && [ $rsize -eq 0 ] && { echo "To create extra partition, you should pass size of root parttion"; exit 1; }

# set up boolean flag to create optional boot partion
[ ! -z $7 ] && create_boot=1

# partitions, n is incremental count started form 1
# /dev/sdXn - mandatory - EFI, 550M default size
# /dev/sdXn - optional  - boot, 1G  default size
# /dev/sdXn - mandatory - root, size is optional, size is til the end of disk by defalt
# /dev/sdXn - optional  - <name>,  mounted to /, size is til the end of disk

echo "$disks" | grep -E "^${disk}$" > /dev/null 2>&1
[ $? -ne 0 ] && { echo "Disk $disk is not found"; exit -1; }

# Check if disk is empty
lsblk -n -l -o type,name | grep -E "^part\s+$disk" > /dev/null 2>&1
if [ $? -eq 0 ] ; then
  lsblk /dev/$disk -o "name,partlabel,label,size,fsused,UUID,model"
  read -r -p "Disk $disk has partitions (see above), remove them? (y|n)" answer
  [[ $answer == [yY] ]] || exit 1
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
# run reflector -a 48 -c $country -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

umount -A -R -q /mnt # just for sure, exits with code 1 if no mount

# set full disk name and partitons:
[[ $disk == "nvme"* ]] && p=p
disk="/dev/$disk"
par1=${disk}${p}1
par2=${disk}${p}2
par3=${disk}${p}3
par4=${disk}${p}4

echo "Disk $disk will be partitioned as follows"
if [ $create_boot ] ; then
  echo " EFI: $par1 : vfat"
  echo "BOOT: $par2 : ext4"
  echo "ROOT: $par3 : ext4"
  expar=$par4
  exnum=4
else
  echo " EFI: $par1 : vfat"
  echo "ROOT: $par2 : ext4"
  expar=$par3
  exnum=3
fi

[ $extra ] && echo "$extra: $expar : ext4"

# formatting disk, as follows:
# 1. Zap (destroy) the GPT and MBR data structures
# 2. Create new gpt disk 2048 alignment
# 3. Create EFI partition
# 4. Create BOOT partition (kernels)
# 5. Create ROOT partition 
# 6. Inform the OS of partition table changes (partprobe)
# 7. Format EFI, BOOT and ROT partitions
#    Notes: -c option is partlabel, -n and -L options are labels
echo "Format $disk and mound partitions"
run sgdisk -Z ${disk}
run sgdisk -a 2048 -o ${disk} 
run sgdisk -n 1::+550M -t 1:ef00 -c 1:EFI ${disk}

if [ $create_boot ] ; then
  run sgdisk -n 2::+1G   -t 2:8300 -c 2:BOOT ${disk}
  run sgdisk -n 3::${rs} -t 3:8300 -c 3:ROOT ${disk}
else
  run sgdisk -n 2::${rs} -t 2:8300 -c 2:ROOT ${disk}
fi

if [ $extra ] ; then
  run sgdisk -n ${exnum}::-0 -t ${exnum}:8300 -c ${exnum}:${extra} ${disk}
fi

run partprobe ${disk} 

run mkfs.fat -F32 -n EFI $par1
if [ $create_boot ] ; then
  run mkfs.ext4 -L BOOT $par2
  run mkfs.ext4 -L ROOT $par3
else
  run mkfs.ext4 -L ROOT $par2
fi

if [ $extra ] ; then
  run mkfs.ext4 -L $extra $expar
fi

if [ $create_boot ] ; then
  run mount $par3 /mnt
  run mount -m $par2 /mnt/boot
  run mount -m $par1 /mnt/boot/efi
else
  run mount $par2 /mnt
  run mount -m $par1 /mnt/boot/efi
fi

if [ $extra ] ; then
  run mount -m $expar /mnt/$extra
fi

echo "Install essential packages (minimal)"
run pacstrap -K /mnt base linux linux-firmware sudo

echo "Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab
[ $? -ne 0 ] && { echo "Cannot run 'genfstab -U /mnt >> /mnt/etc/fstab'"; exit -1; }

#echo "Save generated mirror list"
#run cp /mnt/etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.bak
#run cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
run cp -r ${dir} /mnt/root

( arch-chroot /mnt $HOME/$(basename $dir)/install_usr.sh "$host" "$user" "$pass" "$tz_local")

run touch /mnt/root/arch.exit.$?

exit 0

