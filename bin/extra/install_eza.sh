#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

echo "Install eza"

tmp_dir="/tmp"; [ -d $tmp_dir/eza ] && run rm -rf $tmp_dir/eza

run git clone https://github.com/eza-community/eza.git $tmp_dir/eza
run rm -rf $HOME/.config/eza
run mkdir $HOME/.config/eza
run rsync -lvrpt $tmp_dir/eza/completions $HOME/.config/eza
run rm -rf $tmp_dir/eza 

update_file $HOME/.zshrc 'export FPATH="$HOME/.config/eza/completions/zsh:$FPATH"' 'support eza zsh completions'

run rsync -lvrpt $script_dir/config/eza/aliases.sh $HOME/.config/eza

update_file $HOME/.zshrc  'source "$HOME/.config/eza/aliases.sh"' 'support eza aliases'
update_file $HOME/.bashrc 'source "$HOME/.config/eza/aliases.sh"' 'support eza aliases'

run git clone https://github.com/eza-community/eza-themes.git $HOME/.config/eza/eza-themes
run rm -rf $HOME/.config/eza/eza-themes/.git
run ln -sf "$HOME/.config/eza/eza-themes/themes/dracula.yml" $HOME/.config/eza/theme.yml

exit 0
