#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

[ ! -f $HOME/.zshrc ] && { echo "Install zsh first"; exit 1; }

echo "Install tmux config"
dir=$HOME/.config/tmux; [ -d $dir ] && run rm -rf $dir
run mkdir -p $dir
run cp $script_dir/config/tmux/tmux.conf $dir

echo "Install tmux pluginmanager"
tpm="$HOME/.tmux/plugins/tpm"; [ -d $tpm ] && run rm -rf $tpm
run git clone https://github.com/tmux-plugins/tpm $tpm

run rm -rf $tpm/.git
run rm $tpm/.travis.yml
run rm $tpm/.git*

exit 0

