#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

echo "Install AstroNvim settings"
echo "    backup current nvim settings"
run $script_dir/backup.sh

localnvim="$HOME/.config/nvim"
remotenvim="https://github.com/AstroNvim/template" 

echo "    clone $remotenvim to $localnvim"
git clone --depth 1 $remotenvim $localnvim
[ ! -d $localnvim ] && { echo "Cannot clone $remotenvim"; exit 1; }
run rm -rf $localnvim/.git

echo "    copy user settings"
run rsync -lrpt $script_dir/plugins $localnvim/lua

file=$localnvim/lua/plugins/user_cpp.lua
if [ -f $file ] ; then
  echo "Updating hostname in $file with $(hostname -s)"
  if [[ $sdir == "macos" ]] ; then
    sed -i '' "s/build.myhostname/build.$(hostname -s)/g" "$file"
  else
    sed -i "s/build.myhostname/build.$(hostname -s)/g" "$file"
  fi
fi

exit 0

