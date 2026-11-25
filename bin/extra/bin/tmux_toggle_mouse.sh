#!/bin/bash
# toggle tmux mouse

out=$(tmux show -g mouse 2>/dev/null) || { echo "tmux is not running"; exit 1; }

case $out in
  "mouse on")  echo "tmux mouse off"; tmux set -g mouse off ;;
  "mouse off") echo "tmux mouse on";  tmux set -g mouse on  ;;
  *) echo "Unknown: $out"; exit 1 ;;
esac

exit 0
