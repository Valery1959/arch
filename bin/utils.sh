#!/bin/bash

rel_file="/etc/os-release"

getAttribute()
{
    cat $1 | grep -E "$2" | sed -e "s/$2//g" -e 's/"//g'
}

getProduct()
{
    echo "$1" | grep "$2" | awk '{ print $2 }';
}

utils_init()
{
  os_family=$(uname -a | awk '{ print $1 }')

  case $os_family in
    Darwin) svers=$(sw_vers);
            os_name=$(getProduct "$svers" ProductName); version=$(getProduct "$svers" ProductVersion)    ;;
    Linux)  os_name=$(getAttribute $rel_file "^NAME="); version=$(getAttribute $rel_file "^VERSION_ID=") ;;
    *) echo "Unknown OS Family: $os_family"; exit 1 ;;
  esac

  case $os_name in
    "Arch Linux") os_base="arch";   wx_dir="arch"   ;;
    "Linux Mint") os_base="ubuntu"; wx_dir="mint"   ;;
    "Ubuntu")     os_base="ubuntu"; wx_dir="ubuntu" ;;
    "Fedora"*)    os_base="fedora"; wx_dir="fedora" ;;
    "openSU"*)    os_base="opensu"; wx_dir="opensu" ;;
    "macOS")      [[ "$version" ==  "13."* ]] && os_base="macos" ;;
    *) echo "Unknown OS version: $os_name"; exit 1 ;;
  esac

  # sudo pacman -Sq --noconfirm --needed $p &>> $LOG & # line buffered output for tail -f $LOG
  case $os_base in
    macos)  s_cmd=""      p_cmd=brew;   i_cmd="install";    r_cmd="remove -y" ;;
    ubuntu) s_cmd="sudo"; p_cmd=apt;    i_cmd="install -y"; r_cmd="remove -y" ;;
    fedora) s_cmd="sudo"; p_cmd=dnf;    i_cmd="install -y"; r_cmd="remove -y" ;;
    opensu) s_cmd="sudo"; p_cmd=zypper; i_cmd="--non-interactive in"; r_cmd="--non-interactive rm";;
    arch)   s_cmd="sudo"  p_cmd=pacman; i_cmd="-Sq --noconfirm --needed"; r_cmd="Rq --noconfirm" ;;
    *) echo "Unsupported version $version of $os_name"; exit 1 ;;
  esac

  pkg_path=$(which $p_cmd 2>/dev/null)

  [ -z $pkg_path ] && { echo "Cannot locate package mgr: $pkg"; exit 1; }

  [ ! -x $pkg_path ] && { echo "$pkg does not exist or executable"; exit 1; }
}

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

err()
{
  echo "$@"; exit 1;
}

check_init()
{
  if [ -z "$s_cmd" ] || [ -z "$p_cmd" ] || [ -z "$i_cmd" ] || [ -z "$r_cmd" ] ; then
    utils_init
  fi
}

remove_pkg()
{
  check_init; run $s_cmd $p_cmd $r_cmd $@
}

install_pkg()
{
  check_init; run $s_cmd $p_cmd $i_cmd $@
}

remove_pkg()
{
  check_init; run $s_cmd $p_cmd $r_cmd $@
}

check_rust()
{
  check_init

  [ -z "$(which rustup 2>/dev/null)" ] && { echo "Cannot find rustup, install rust"; exit 1; }

  [ -z $@ ] && return 0

  for arg in $@
  do
    app="$(which $arg 2>/dev/null)"
    if [ ! -z "$app" ] && [ $(dirname $app) != $HOME/.cargo/bin ] ; then
      echo "$arg is already installed by non rust, please uninstall it manually"
      failed=1
    fi
  done

  [ ! -z $failed ] && exit 1

  return 0
}

ensure_rust()
{
  check_rust $@

  echo "Ensure right Rust compiler installed"
  run rustup override set stable
  run rustup update stable
}

strip_rust()
{
   run strip $HOME/.cargo/bin/$1
}

update_file()
{
  file=$1
  line=$2
  cmnt=$3

  echo "Updating $file with '$line'"
  grep -qxF "$line" "$file" || echo -e "\n# $cmnt\n$line" >> "$file"
}

installed()
{
  which "$1" >/dev/null 2>&1; return $?
}

installed_grep()
{
  #pacman -Qq | grep -qw '^'$1'$'; return $?
  return 1
}

# man terminfo:
# String Capability   |  TI   | TC | Description
# --------------------|-------|----|----------------------------------------------
# exit_attribute_mode | sgr0  | me | turn off all attributes
# set_a_foreground    | setaf | AF | Set foreground color to #1, using ANSI escape
# set_a_background    | setab | AB | Set background color to #1, using ANSI escape
# cursor_invisible    | civis | vi | make cursor invisible
# cursor_normal       | cnorm | ve | make cursor appear normal (undo civis/cvvis)
# --------------------------------------------------------------------------------

tmsg()
{
  printf "%s" "$(tput setaf $2)${1}$(tput sgr0)"
}

t_time()
{
  printf "%s %s %2s %s" $1 min $2 sec
}

t_mesg()
{
  printf "%s" "$m_rarr $(tmsg "$(t_time $1 $2)" 4) $3"
}

progress_bar()
{
  local c1="● "; local c2="○●"; local c3="->"; local c4="<-"; local c5="|"
  local clock=0; local m_min=0; local m_int=0; local m_sec=0

  local m_inst=$(tmsg Installing 3)
  local m_tic1=$(tmsg "$c1" 5)
  local m_tic2=$(tmsg "$c2" 5)
  local m_rarr=$(tmsg "$c3" 5)
  local m_larr=$(tmsg "$c4" 5)
  local m_vert=$(tmsg "$c5" 5)
  local m_done=$(tmsg "done" 2)

  local pid=$1
  local pkg=$2

  tput civis
  while true
  do
    [ $clock -ge 60 ] && { clock=0; ((m_int++)); }
    [ $m_int -ge 10 ] && { m_int=0; ((m_min++)); }
    if [ $clock -eq 0 ] ; then
      ((m_sec = $m_int * 6))
      printf "\r%s %-25s %s\b" "$m_inst" "$(tmsg $pkg 2)" "$(t_mesg $m_min $m_sec "$m_tic1")"
    elif [ $clock -lt 30 ] ; then 
      printf "\b%s" "$m_tic2"
    elif [ $clock -eq 30 ] ; then 
      printf "%s\b" "$m_vert"
    elif [ $clock -eq 31 ] ; then 
      printf "%s\b" "$m_larr"
    else
      printf "\b\b\b%s" "$m_tic1"
    fi
    kill -s 0 $pid 2> /dev/null || break # check process by pid
    sleep 0.1
    ((clock++))
  done

  wait $pid; exit_status=$?; [ $exit_status -eq 0 ] || m_done=$(tmsg "fail" 1)

  ((m_sec = $m_int * 6 + $clock / 10))
    
  printf "\r%s %-25s %-92s\n" "$m_inst" "$(tmsg $pkg 2)" "$(t_mesg $m_min $m_sec $m_larr) $m_done (new)"

  tput cnorm

  return $exit_status
}

LOG=$script_dir/log_file


install_packages()
{
  sudo ls &> /dev/null
  #sudo apt list &> /dev/null
  #sudo pacman -Q $p &> /dev/null
  for p in $@
  do
    stdbuf -oL $s_cmd $p_cmd $i_cmd $p &>> $LOG & # line buffered output for tail -f $LOG
  # stdbuf -oL $script_dir/install_pack $p &>> $LOG & # line buffered output for tail -f $LOG
    progress_bar $! $p
    if [ $? -ne 0 ] ; then
      printf "%s" "Last command failed. Continue? (y|N) "; read -e answer
      if [[ $answer == [yY] ]] ; then
        tput cuu1; printf "\r%-40s\r" ""
      else
        echo "Aborting, see $LOG file for details"; break;
      fi
    fi
  done
}
