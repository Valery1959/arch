#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

update_file()
{
  file=$1
  line=$2
  cmnt=$3

  echo "Updating $file with '$line'"
  grep -qxF "$line" "$file" || echo -e "\n# $cmnt\n$line" >> "$file"
}

if [ ! -f $HOME/.zshrc ] ; then
   echo "Installing .zshrc"
   run "cp $script_dir/.zshrc $HOME"
fi

if [ ! -f $HOME/.config/zsh/zsh-autosuggestions ] ; then
   echo "Removing $HOME/.config/zsh/zsh-autosuggestions"
   run "rm -rf $HOME/.config/zsh/zsh-autosuggestions"
fi

if [ ! -f $HOME/.config/zsh/zsh-syntax-highlighting ] ; then
   echo "Removing $HOME/.config/zsh/zsh-syntax-highlighting"
   run "rm -rf $HOME/.config/zsh/zsh-syntax-highlighting"
fi

if [ ! -f $HOME/powerlevel10k ] ; then
   echo "Removing $HOME/powerlevel10k"
   run "rm -rf $HOME/powerlevel10k"
fi

echo "Installing zsh-autosuggestions"
run git clone https://github.com/zsh-users/zsh-autosuggestions ~/.config/zsh/zsh-autosuggestions
update_file $HOME/.zshrc 'source ~/.config/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh' 'support zsh autosuggections'

echo "Installing zsh-syntax-highlighting"
run git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.config/zsh/zsh-syntax-highlighting
update_file $HOME/.zshrc 'source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' 'support zsh syntax highlighting'

echo "Installing powerlevel10k"
run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
update_file $HOME/.zshrc 'source ~/powerlevel10k/powerlevel10k.zsh-theme' 'support powerlevel10k theme'

