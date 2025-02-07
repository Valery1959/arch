#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

[ "$1" = "x11" ] && force_x11=1

source $script_dir/../utils.sh

echo "Configuring alacritty"
config=$HOME/.config/alacritty; [ -d $config/themes ] && run rm -rf $config/themes
run mkdir -p $config/themes
run git clone https://github.com/alacritty/alacritty-theme $config/themes
run cp $script_dir/config/alacritty/alacritty.toml $config

echo "Cleaning up"
run rm -rf $config/themes/.git

exit 0
