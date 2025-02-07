#!/bin/bash

move_dir()
{
   [ ! -d $1 ] && return
   mv "$1" "$2"; [ $? -ne 0 ] && { echo "Cannot move $1 to $2";  exit 1; }
}

make_dir()
{
   mkdir -p "$1"; [ $? -ne 0 ] && { echo "Cannot make $1";  exit 1; }
}

dir=$HOME/nvim.bakup/$(date '+%y.%m.%d_%H.%M.%S')

echo "Backup current nvim settings/share/state/cache to $dir"

make_dir $dir/config
make_dir $dir/share
make_dir $dir/state
make_dir $dir/cache

move_dir $HOME/.config/nvim            $dir/config
move_dir $HOME/.local/share/nvim       $dir/share
move_dir $HOME/.local/state/nvim       $dir/state
move_dir $HOME/.cache/nvim             $dir/cache
move_dir $HOME/.cache/cmake_tools_nvim $dir/cache

exit 0
