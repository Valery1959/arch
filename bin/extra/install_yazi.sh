#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

cfg="$HOME/.config"

[ -d $cfg/yazi ] && run rm -r $cfg/yazi

# setup packages for yazi preview, find, change dir
# zoxide p7zip fzf fd ripgrep already have to be installed,
# skip the following packages
# run sudo apt install ffmpegthumbnailer ffmpeg jq poppler imagemagick

echo "Install Yazi plugins and flavors"
run mkdir $cfg/yazi
run ya pack -a yazi-rs/flavors:catppuccin-mocha
run ya pack -a yazi-rs/plugins:smart-enter
run rsync -lvrpt $script_dir/config/yazi/*.toml $cfg/yazi

exit 0
