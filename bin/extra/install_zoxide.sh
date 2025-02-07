#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

echo "Install zoxide"
update_file $HOME/.zshrc  'eval "$(zoxide init zsh)"'  'support zoxide'
update_file $HOME/.bashrc 'eval "$(zoxide init bash)"' 'support zoxide'

exit 0
