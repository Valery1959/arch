#!/bin/bash

dir=$(cd $(dirname $0); pwd -P)
cmd=$(basename $0)

run()
{
  echo "Run '$@'"; "$@"; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

host_name="$1"
user_name="$2"
pass_word="$3"
time_zone="$4"
boot_id="$5"
disk_rm="$6"; [ ! -z $disk_rm ] && removable="--removable"
crypt_dev="$7"
root_part="$8"

echo "Installing arch chroot"
echo "Hostname: $host_name"
echo "Username: $user_name"
echo "Timezone: $time_zone"
echo "bootloader-id: $boot_id"

# no root password, add user to wheel group with sudo permission

echo "Adding user $user_name"
run useradd -m -G wheel,audio,video,optical,storage "$user_name"
echo "Changing passwor for $user_name"
echo "$user_name:$pass_word" | chpasswd
[ $? -ne 0 ] && { echo "Could not change passwd for $user_name"; exit 1; }
 
echo "Enabling sudo rights"
run sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "Adding host $host_name to /etc/hostname and /etc/hosts"
echo "$host_name" > /etc/hostname
echo "# Static table lookup for hostnames." > /etc/hosts
echo "# See hosts(5) for details."         >> /etc/hosts
echo "127.0.0.1        localhost"          >> /etc/hosts
echo "::1              localhost"          >> /etc/hosts
echo "127.0.1.1        ${host_name}.localdomain        $host_name" >> /etc/hosts

echo "Setting time zone to $time_zone"
run ln -s /usr/share/zoneinfo/${time_zone} /etc/localtime

echo "Enabling un_US, ru_RU locale settings, and generate locale"
run sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
run sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
run locale-gen

echo "Adding LANG and LC_TIME to /etc/locale.conf"
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_TIME=en_US.UTF-8" >> /etc/locale.conf

echo "Enable parallel downloading and multilib"
run sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
run sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

echo "Init pacman keys and append keys from archlinux.gpg"
run pacman-key --init
run pacman-key --populate archlinux

echo "Sync package database"
run pacman -Sy

# define microcode
microcode=""; vendor=$(lscpu | grep -E "^Vendor" | awk '{ print $3 }')
if [ $vendor = "GenuineIntel" ] ; then
  microcode="intel-ucode"
elif [ vendor = "AuthenticAMD" ] ; then
  microcode="amd-ucode"
fi

# networkmanager - to manage Internet connections (wired and wireless)
# btrfs-progs    - btrfs file system management
# grub           - bootloader
# grub-btrfs     - adds btrfs support for the grub bootloader and enables the user to directly boot from snapshots
# inotify-tools  - used by grub btrfsd deamon to automatically spot new snapshots and update grub entries
# efibootmgr     - to install grub
# openssh        - use ssh and manage keys
echo "Install other essential packages"
run pacman -S --noconfirm --needed networkmanager grub efibootmgr btrfs-progs openssh rsync vim $microcode

if [ ! -z $crypt_dev ] ; then
   # Create key file
   key_file="/crypto_keyfile.bin"
   run dd bs=512 count=4 iflag=fullblock if=/dev/random of=$key_file
   run chmod 600 $key_file
   run cryptsetup luksAddKey ${root_part} $key_file

   [ ! -f $key_file ] && { echo "File $key_file does not exist"; exit 1; }

   # Edit /etc/mkinitcpio.conf, and recreate the initramfs image
   # MODULES=(btrfs)
   # FILES=(/crypto_keyfile.bin)
   # HOOKS=(base udev keyboard autodetect keymap consolefont modconf block encrypt filesystems fsck)
   file="/etc/mkinitcpio.conf"; [ ! -f $file ] && { echo "File $file does not exist" ; exit 1; }

   grep -qE '^MODULES=' "$file" || { echo "Cannot find MODULES in $file"; exit 1; }
   grep -qE '^FILES='   "$file" || { echo "Cannot find FILES   in $file"; exit 1; }
   grep -qE '^HOOKS='   "$file" || { echo "Cannot find HOOKS   in $file"; exit 1; }

   grep -qE '^MODULES=\(\)' "$file" || p1=' '
   grep -qE '^FILES=\(\)'   "$file" || p2=' '

   module="btrfs"
   echo "--- Add module $module to $file"
   sed -i -e 's/\(^MODULES=.*\)\()\)/\1'"${p1}${module}"')/g' $file

   echo "--- Add path to $key_file to $file"
   sed -i -e 's/\(^FILES=.*\)\()\)/\1'"${p2}\\${key_file}"')/g' $file

   echo "--- Add hook encrypt to $file"
   sed -i -e 's/\(^HOOKS=.*\)\(filesystems\)/\1encrypt filesystems/g' $file

   echo "--- Recreate the initramfs image"
   run mkinitcpio -P

   # Edit /etc/default/grub
   # GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet cryptdevice=UUID=UUID_OF_ENCRYPTED_PARTITION:cryptdev"
   # GRUB_PRELOAD_MODULES="part_gpt part_msdos luks"
   # GRUB_ENABLE_CRYPTODISK=y
   file="/etc/default/grub"; [ ! -f $file ] && { echo "File $file does not exist" ; exit 1; }

   echo "--- Add crypt device to $file"
   line="cryptdevice=UUID=$(blkid -s UUID -o value ${root_part}):$crypt_dev"
   sed -i -e 's/\(^GRUB_CMDLINE_LINUX_DEFAULT=.*\)\(\"\)/\1 '$line'\"/g' $file

   echo "--- Add luks to preload modules to $file"
   line="luks"
   sed -i -e 's/\(^GRUB_PRELOAD_MODULES=.*\)\(\"\)/\1 '$line'\"/g' $file

   echo "--- Enable crypto disk in $file"
   line="y"
   sed -i -e 's/\(#.*\)\(GRUB_ENABLE_CRYPTODISK=\)\(.*\)/\2'$line'/g' $file
fi

#echo "Create initial ramdisk environment"
#run mkinitcpio -p linux

echo "Install grub and configure grub"
run grub-install --efi-directory=/efi --boot-directory=/efi --bootloader-id=$boot_id "$removable"

echo "Verify that a GRUB entry has been added to the UEFI bootloader"
run efibootmgr

echo "Configure grub"
grub_cfg="/efi/grub/grub.cfg"
run grub-mkconfig -o $grub_cfg

if [ ! -z $crypt_dev ] ; then
   echo "Verify that grub.cfg has entries for insmod cryptodisk and insmod luks"
   grep 'cryptodisk\|luks' $grub_cfg
   grep 'cryptodisk' $grub_cfg &> /dev/null || { echo "cryptodisk does not exist in $grub_cfg"; exit 1; }
   grep 'luks'       $grub_cfg &> /dev/null || { echo "luks entry does not exist in $grub_cfg"; exit 1; }
fi

#run grub-install --target=x86_64-efi --bootloader-id=$boot_id --efi-directory=/boot/efi "$removable"
#run grub-mkconfig -o /boot/grub/grub.cfg

echo "Enable network nanager"
run systemctl enable NetworkManager.service

echo "Enable sshd"
run systemctl enable sshd

# post install after reboot
# localectl set-keymap us
# timedatectl set-ntp true
# timedatectl status
# hwclock --systohc

exit 0 

