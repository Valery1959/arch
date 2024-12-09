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
typeset -i rsize=$5; [ $rsize -ne 0 ] && rp=yes; [ $rp ] && rs="+${rsize}G" || rs="-${rsize}"

echo "$disks" | grep -E "^${disk}$" > /dev/null 2>&1
[ $? -ne 0 ] && { echo "Disk $disk is not found"; exit -1; }

lsblk -n -l -o type,name | grep -E "^part\s+$disk" > /dev/null 2>&1
#[ $? -eq 0 ] && { echo "Disk $disk has partitions, remove them manually before run"; exit -1; }

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
#par4=${disk}${p}4

echo "Disk $disk will be partitioned as follows"
echo " EFI: $par1 : vfat"
#echo "BOOT: $par2 : ext4"
echo "ROOT: $par2 : ext4"
[ $rp ] && echo "shared: $par3 : ext4"

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
#run sgdisk -n 2::+1G   -t 2:8300 -c 2:BOOT ${disk}
run sgdisk -n 2::${rs} -t :8300 -c 2:ROOT ${disk}
[ $rp ] && run sgdisk -n 3::-0 -t 3:8300 -c 3:shared ${disk}
run partprobe ${disk} 

run mkfs.fat -F32 -n EFI $par1
#run mkfs.ext4 -L BOOT $par2
run mkfs.ext4 -L ROOT $par2
[ $rp ] && run mkfs.ext4 -L shared $par3

run mount $par2 /mnt
#run mount -m $par2 /mnt/boot
run mount -m $par1 /mnt/boot/efi 
[ $rp ] && run mount -m $par3 /mnt/shared

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

