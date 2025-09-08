#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

echo "Install ssh agent"
run systemctl enable --user ssh-agent.service

case $XDG_CURRENT_DESKTOP in
  KDE)   line='export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket' ;;
  GNOME) line='export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh' ;;
  *) echo "$XDG_CURRENT_DESKTOP is not supported"; exit 1 ;;
esac

echo "Update .zshrc and .bashrc with SSH_AUTH_SOCK"
update_file $HOME/.zshrc  "$line" 'support ssh-agent'
update_file $HOME/.bashrc "$line" 'support ssh-agent'

exit 0
