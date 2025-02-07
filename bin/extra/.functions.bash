#!/usr/bin/env bash

[ -z $EDITOR ] && export EDITOR=nvim

export FZF_DEFAULT_COMMAND="fd --type d"

# fuzzy search directories or files with preview
# use tree or bat to preview directories or files 
___fuzzy_search_dir___() {

  fzf --query "${*:-}" \
    --prompt 'Dirs> ' \
    --color 'header:italic' \
    --header 'Ctrl-t: toggle Files/Dirs, Ctrl-o: toggle preview, Ctrl-p: preview up|down|right' \
    --bind 'ctrl-t:transform:[[ ! $FZF_PROMPT =~ Files ]] &&
            echo "change-prompt(Files> )+reload(fd --type f)" ||
            echo "change-prompt(Dirs> )+reload(fd --type d)"' \
    --bind 'ctrl-o:toggle-preview' \
    --bind 'ctrl-p:change-preview-window(up|down|right)' \
    --preview '[[ $FZF_PROMPT =~ Files ]] && bat --color=always {} || tree {}' \
    --preview-window '40%,border-sharp'
}

# change current directory / edit file / view file dependencies
ccd() {
  d=$(___fuzzy_search_dir___ $@); [ -z $d ] && return

  [ -d "$d" ] && { builtin cd -- $d; return; }

  f=$(file "$d")
  case "$f" in
     *ASCII*|*text*) builtin cd -- "$(dirname $d)"; $EDITOR "$(basename $d)" ;;
     *ELF*|*binary*) ldd "$d" ;;
     *) echo "Unknown file type: $f" ;;
  esac
}

# Two-phase file filtering with rg(ripgrep) and fzf
# 1. Search for text in files using rg
# 2. Interactively restart rg with reload action
# 3. Switch between Ripgrep mode and fzf filtering mode by Ctrl-t
# 4. Open the file in Vim
rff() {
  rm -f /tmp/rg-fzf-{r,f}
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case"
  INITIAL_QUERY="${*:-}"
  : | fzf --ansi --disabled --query "$INITIAL_QUERY" \
    --prompt 'rg> ' \
    --color "header:italic,hl:-1:underline,hl+:-1:underline:reverse" \
    --header 'Ctrl-t: toggle rg/fzf, Ctrl-o: toggle preview, Ctrl-p: preview up|down|right' \
    --delimiter : \
    --bind "start:reload:$RG_PREFIX {q}" \
    --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
    --bind 'ctrl-t:transform:[[ ! $FZF_PROMPT =~ rg ]] &&
      echo "rebind(change)+change-prompt(rg> )+disable-search+transform-query:echo \{q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r" ||
      echo "unbind(change)+change-prompt(fzf> )+enable-search+transform-query:echo \{q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f"' \
    --bind 'ctrl-o:toggle-preview' \
    --bind 'ctrl-p:change-preview-window(up|down|right)' \
    --preview 'bat --color=always {1} --highlight-line {2}' \
    --preview-window '60%,border-sharp' \
    --bind 'enter:become(nvim {1} +{2})'
}

cdp() {
  cd /shared/projects; ccd $1; nvim .
}

y() {
  which yazi > /dev/null 2>&1; [ $? -ne 0 ] && { echo "yazi not found"; return 1; }
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
  builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
