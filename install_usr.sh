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

echo "Installing arch chroot"
echo "Hostname: $host_name"
echo "Username: $user_name"
echo "Timezone: $time_zone"

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
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    ${host_name}.localdomain    $host_name" >> /etc/hosts

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

echo "Install other essential packages"
run pacman -S --noconfirm --needed networkmanager grub efibootmgr openssh rsync vim $microcode

# echo "Create initial ramdisk environment"
# run mkinitcpio -p linux

echo "Install grub and configure grub"
run grub-install --efi-directory /boot/efi
run grub-mkconfig -o /boot/grub/grub.cfg

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

