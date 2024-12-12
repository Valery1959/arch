#!/usr/bin/env bash

script_dir=$(cd $(dirname $0); pwd -P)

cp $script_dir/.functions.bash ~/

update_file()
{
  file=$1
  echo "Updating $file with .functions.bash"
  [ ! -f $file ] && run touch $file
  line='[ -f ~/.functions.bash ] && source ~/.functions.bash'
  grep -qxF "$line" "$file" || echo -e "\n# support fuzzy finder and tmux\n$line" >> "$file"
  tail -n 3 "$file"
}

update_path()
{
  file=$1
  echo "Updating $file with export PATH=\$HOME/bin:\$HOME/.cargo/bin:\$PATH"
  [ ! -f $file ] && run touch $file
  line='export PATH=$HOME/bin:$HOME/.cargo/bin:$PATH'
  grep -qxF "$line" "$file" || echo -e "\n# support user's home bin\n$line" >> "$file"
  tail -n 3 "$file"
}

update_file "$HOME/.bashrc"
update_path "$HOME/.bashrc"

if [ -f $HOME/.zshrc ] ; then
  update_file "$HOME/.zshrc"
  update_path "$HOME/.zshrc"
fi
