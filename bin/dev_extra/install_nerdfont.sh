#!/bin/bash

# Download (mono)font from https://www.nerdfonts.com/ , for example Mononoki

script_dir=$(cd $(dirname $0); pwd -P)

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1"

[ -z "$1" ] && file="Mononoki.zip" || file=$1

font="/tmp/$file"

run curl -Lo $font $url/$file

[ ! -f $font ] && { echo "font file $font does not exists"; exit 1; }

# unzip and install font
run unzip -o $font -d ~/.fonts
run rm $font
run fc-cache -fv

# check font installed
name=$(basename $font | cut -d. -f1)
echo "Check installed font $name"
fc-list | grep $name

echo "Gnome Terminal -> Preferences -> active profile - > Text tab -> Custom font -> <font>"
