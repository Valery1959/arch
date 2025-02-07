#!/bin/bash

file=$HOME/.config/nvim/lazy-lock.json; [ ! -f $file ] && { echo "File $file does not exist"; exit 1; }

echo "Restore vim plugins"

restore_plugin_version()
{
  echo "Restore \"$1\" to commit: $2"
  sed -i "s/\(\"${1}.*commit\": \)\".*\"/\1 \"${2}\"/g" $file
}

restore_plugin_version cmake-tools.nvim f1f917b584127b673c25138233cebf1d61a19f35

exit 0

