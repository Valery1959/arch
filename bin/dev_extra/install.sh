#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

echo "Install .zshrc"
run $script_dir/install_zsh.sh

echo "Install .bashrc"
run $script_dir/install_bashrc.sh

echo "Install ~/bin"
run mkdir -p ~/bin
run cp $script_dir/up ~/bin
run cp $script_dir/nv ~/bin
run cp $script_dir/po ~/bin
run cp $script_dir/fix_compile_commands_json_link ~/bin

echo "Install nerd fonts"
run $script_dir/install_nerdfont.sh Mononoki.zip
run $script_dir/install_nerdfont.sh JetBrainsMono.zip JetBrainsMonoNerdFont
run $script_dir/install_nerdfont.sh Meslo.zip MesloLGSNerdFont

echo "Install Rust"
run $script_dir/install_rust.sh

echo "Install Astro nvim"
run $script_dir/install_astro.sh

exit 0

