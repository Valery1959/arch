#!/bin/bash
# install packages on local or remote Arch Linux host

dir=$(cd $(dirname $0); pwd -P)
bin=$dir/bin

source $bin/utils.sh

[[ -z "$@" ]] && { echo "usage: $(basename $0) kvm|dev|kde|gnome|hyprland|snap"; exit -1; }

for arg in $@
do
  case $arg in
    kvm) kvm=1 ;;
    dev) dev=1 ;;
    kde) kde=1 ;;
    gnome) gnome=1 ;;
    hyprland) hyprland=1; dev=1; gnome=1 ;;
    snap) snap=1 ;;
    *) echo "Unknown arg: $arg"; exit -1 ;; 
  esac
done

[ ! -z $kde ] && [ ! -z $gnome ] && { echo "You should not install both gnome and kde"; exit -1; }

[ ! -z $kvm ] && run $bin/kvm
[ ! -z $kde ] && { run $bin/kde plasma; run $bin/kde apps; }
[ ! -z $gnome ] && { run $bin/gnome gnome; run $bin/gnome apps; }

[ ! -z $dev ] && run $bin/dev

[ ! -z $hyprland ] && run $bin/hyprland

[ ! -z $snap ] && run $bin/snap

exit 0

