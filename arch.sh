#!/bin/bash
# run this script by following command
# bash <(curl -L https://raw.githubusercontent.com/Valery1959/arch/main/arch.sh) <disk> <host> <user> [passwd]
# bash <(curl -L https://raw.githubusercontent.com/Valery1959/arch/main/arch.sh) sda my_host my_user

run()
{
  echo "Run '$@'"; "$@"; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

install_dir="$HOME/arch"
install_cmd="$install_dir/install_iso.sh"
install_log="$HOME/install.log"
install_usr="/mnt/home/$3"
install_tag="/mnt/root/arch.exit.0"

pacman -Sy --noconfirm --needed git glibc 2>&1 |& tee -a $install_log 
if [ $? -ne 0 ] ; then
  echo "Cannot install git libc"; exit -1
fi

if [ ! -d $install_dir ] ; then
  git clone https://github.com/Valery1959/arch.git $install_dir > /dev/null 2>&1 
  if [ $? -ne 0 ] || [ ! -d $install_dir ] ; then
    echo "Cannot clone repository with arch installation scripts"; exit -1
  fi
fi

[ ! -f $install_cmd ] && { echo "File $install_cmd does not exist"; exit -1; }

$install_cmd $@ |& tee -a $install_log

[ ! -f "$install_tag" ] && { echo "Cannot run $install_cmd $1 $2 $3"; exit -1; }
[ ! -d "$install_usr" ] && { echo "Cannot create $install_usr"; exit -1; }

echo "Cleaning up ..." | tee -a $install_log
run rm "$install_tag" |& tee -a $install_log

echo "Moving $install_log and $install_dir to $install_usr ... '" | tee -a $install_log
echo "mv $install_dir $install_usr" |& tee -a $install_log
run mv $install_dir $install_usr
echo "mv $install_log $install_usr" |& tee -a $install_log
run mv $install_log $install_usr

run chown -R $install_usr/arch --reference $install_usr
run chown $install_usr/install.log --reference $install_usr
#run umount -A -R -q /mnt

#reboot

exit 0
