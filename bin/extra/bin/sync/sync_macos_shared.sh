#!/bin/bash

host=$(hostname -s)

case $host in
   kio|tio) ;;
   *) echo "Should be run on kio or tio hosts only"; exit 1 ;;
esac

script_dir=$(cd $(dirname $0); pwd -P)

source /shared/scripts/utils.sh

syncto=$1; [ -z $syncto ] && syncto="to"

#domain=$2; [ -z $domain ] && domain="Ventura"

#macaddr=$(virsh dumpxml $domain | grep "mac address" | awk -F\' '{ print $2}') 

#[ -z $macaddr ] && { echo "Cannot get mac address for $domain"; exit 1; }

#ip=$(virsh net-dhcp-leases default | grep $macaddr | awk '{ print $5 }' | cut -d/ -f1)

#[ -z $ip ] && { echo "Cannot get ip for $domain"; exit 1; }

case $syncto in
  from) dst="/shared"; src="vio:/Users/valery/shared" ;;
  to)   src="/shared"; dst="vio:/Users/valery/shared"   ;;
  *) echo "Unknown job: $syncto, should be to or from"; exit 1 ;;
esac

dir="dtree scripts"

for d in $dir
do
  run rsync -lrpt "$src/$d" "$dst"
done

dir="projects"
for d in $dir
do
  run $script_dir/sync_project.sh "$src/$d" "$dst"
done

exit 0

