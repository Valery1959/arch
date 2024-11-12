#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

if [ ! -f $HOME/.zshrc ] ; then
   echo "Installing .zshrc"
   run "cp $script_dir/.zshrc $HOME"
fi

if [ ! -f $HOME/powerlevel10k ] ; then
   echo "Removing $HOME/powerlevel10k"
   run "rm -rf $HOME/powerlevel10k"
fi

echo "Installing powerlevel10k"
run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc

