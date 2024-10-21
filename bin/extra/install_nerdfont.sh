#!/bin/bash

# Download (mono)font from https://www.nerdfonts.com/ , for example Mononoki

script_dir=$(cd $(dirname $0); pwd -P)

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

[ -z "$1" ] && font="Mononoki.zip" || font=$1

font=$script_dir/$font

[ ! -f $font ] && { echo "font file $font does not exists"; exit 1; }

# unzip font
run unzip $font -d ~/.fonts

# install font
run fc-cache -fv

# check font installed
name=$(basename $font | cut -d. -f1)
echo "Check installed font $name"
fc-list | grep $name

echo "Gnome Terminal -> Preferences -> active profile - > Text tab -> Custom font -> <font>"
