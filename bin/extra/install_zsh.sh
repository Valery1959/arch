#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

if [ ! -f $HOME/.zshrc ] ; then
   echo "Installing .zshrc"
   run "cp $script_dir/config/.zshrc $HOME"
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

run cp $script_dir/config/.functions.bash $HOME

update_file $HOME/.zshrc '[ -f ~/.functions.bash ] && source ~/.functions.bash' "support fuzzy finder and tmux"
update_file $HOME/.zshrc 'export PATH=$HOME/bin:$HOME/.cargo/bin:$PATH' 'support home and cargo bin'

update_file $HOME/.bashrc '[ -f ~/.functions.bash ] && source ~/.functions.bash' 'support fuzzy finder and tmux'
update_file $HOME/.bashrc 'export PATH=$HOME/bin:$HOME/.cargo/bin:$PATH' 'support home and cargo bin'

