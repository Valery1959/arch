#!/bin/bash

host=$(hostname -s)

case $host in
   kio|tio) ;;
   *) echo "Should be run on kio or tio hosts only"; exit 1 ;;
esac

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

dst=$1
src="/shared"

dir="dtree libvirt scripts"
tar="wxWidgets_fedora wxWidgets_mint wxWidgets_opensu wxWidgets_ubuntu"

[   -z $dst ] && { echo "You should pass target dir as first argument"; exit 1; }
[ ! -d $dst ] && { echo "Target directory $dst does not exist"; exit 1; }
[ ! -d $src ] && { echo "Source directory $src does not exist"; exit 1; }

if [[ "$dst" =~ "/mars/" ]] ; then
  dir="dtree libvirt scripts"
  tar="wxWidgets_fedora wxWidgets_mint wxWidgets_opensu wxWidgets_ubuntu"
else
  dir="dtree libvirt scripts wxWidgets_fedora wxWidgets_mint wxWidgets_opensu wxWidgets_ubuntu"
  tar=""
fi

for d in $dir
do
  run sudo rsync -a "$src/$d" "$dst"
done

#for d in $tar
#do
#  tar cvf "$src/${d}.tar" "$src/$d"
#  run sudo rsync -a "$src/${d}.tar" "$dst"
#  rm "$src/${d}.tar"
#done

dir="projects"
for d in $dir
do
  run $script_dir/sync_project.sh "$src/$d" "$dst"
done

exit 0

