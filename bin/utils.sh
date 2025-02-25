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

  case $os_base in
    macos)  s_cmd="";     p_cmd=brew;   u_cmd1="";                 u_cmd2=""        ;;
    ubuntu) s_cmd="sudo"; p_cmd=apt;    u_cmd1="update";           u_cmd2="upgrade" ;;
    fedora) s_cmd="sudo"; p_cmd=dnf;    u_cmd1="update";           u_cmd2=""        ;;
    opensu) s_cmd="sudo"; p_cmd=zypper; u_cmd1="ref";              u_cmd2="up"      ;;
    arch)   s_cmd="sudo"; p_cmd=pacman; u_cmd1="-Syu --noconfirm"; u_cmd2=""        ;;
    *) echo "Unsupported version $version of $os_name"; exit 1 ;;
  esac

  case $os_base in
    macos)  i_cmd="install";                  r_cmd="remove -y" ;;
    ubuntu) i_cmd="install -y";               r_cmd="remove -y" ;;
    fedora) i_cmd="install -y";               r_cmd="remove -y" ;;
    opensu) i_cmd="--non-interactive in";     r_cmd="--non-interactive rm";;
    arch)   i_cmd="-Sq --noconfirm --needed"; r_cmd="Rq --noconfirm" ;;
    *) echo "Unsupported version $version of $os_name"; exit 1 ;;
  esac

  case $os_base in
    macos)  l_cmd="brew";     l_opt="info"             ;;
    ubuntu) l_cmd="dpkg";     l_opt="-l"               ;;
    fedora) l_cmd="dnf";      l_opt="info --installed" ;;
    opensu) l_cmd="zypper";   l_opt="se -i"            ;;
    arch)   l_cmd=pacman;     l_opt="-Qq"              ;;
    *) echo "Unsupported version $version of $os_name"; exit 1 ;;
  esac

  pkg_path=$(command -v $p_cmd 2>/dev/null)

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

log_init()
{
  [ -d $1 ] || err "Script directory $1 does not exist ?"
  LOG=$1/log_$(date +%Y.%m.%d_%H.%M.%S).log
}

exit_error()
{
  err "$@, see $LOG"
}

check_root()
{
  [ $(id -u) -eq 0 ] && err "This script must not be run under root user"
}

check_service()
{
  systemctl is-active --quiet $1; return $?
}

check_sddm()
{
   [[ $sddm != [yY] ]] && return

   local services="gdm.service gdm3.service lightdm.service lxdm.service"
   local service
   for service in $services
   do
     check_service $service && err "$service is active. It should be inactive to install sddm service"
   done
}

check_sudo()
{
  sudo echo -n &> /dev/null
}

check_init()
{
  if [ -z "$s_cmd" ] || [ -z "$p_cmd" ] || [ -z "$i_cmd" ] || [ -z "$r_cmd" ] ; then
    utils_init
  fi
}

install_pkg()
{
  check_init; run $s_cmd $p_cmd $i_cmd $@
}

remove_pkg()
{
  check_init; run $s_cmd $p_cmd $r_cmd $@
}

check_pkg()
{
  $s_cmd $l_cmd $l_opt $1 &> /dev/null; return $? # check packages one-by-one
}

check_rust()
{
  check_init

  [ -z "$(command -v rustup 2>/dev/null)" ] && { echo "Cannot find rustup, install rust"; exit 1; }

  [ -z $@ ] && return 0

  for arg in $@
  do
    app="$(command -v $arg 2>/dev/null)"
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
  command "$1" &> /dev/null; return $?
}

package_installed()
{
  $s_cmd $p_cmd $l_cmd $1 &> /dev/null; return $? 
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
  printf "%s %s %4s %s" $1 min ${2}.${3} sec
}

t_mesg()
{
  printf "%s" "$m_rarr $(tmsg "$(t_time $1 $2 $3)" 6) $4"
}

t_skip()
{
  printf "%s" "$m_rarr $(tmsg "$1" 6) $m_larr"
}

progress_bar()
{
  local pid="$1"
  local pkg="$2"

  local c1="● "; local c2="○●"; local c3="->"; local c4="<-"; local c5="|"
  local clock=0; local m_min=0; local m_int=0; local m_sec=0

  local m_inst="$(tmsg "$3" 3)"
  local m_tic1=$(tmsg "$c1" 5)
  local m_tic2=$(tmsg "$c2" 5)
  local m_rarr=$(tmsg "$c3" 5)
  local m_larr=$(tmsg "$c4" 5)
  local m_vert=$(tmsg "$c5" 5)
  local m_done=$(tmsg "done" 2)
  local m_dsec=0

  local m_note=; [ ! -z "$4" ] && m_note=$(tmsg " ($4)" 2) 
  local m_skip=; [ ! -z "$5" ] && m_skip="$5"

  tput civis

  if [ ! -z "$m_skip" ] ; then
    printf "\r%s %-28s %s\n" "$m_inst" "$(tmsg "$pkg" 2)" "$(t_skip "$m_skip")"
  fi

  while true
  do
    [ $clock -ge 60 ] && { clock=0; ((m_int++)); }
    [ $m_int -ge 10 ] && { m_int=0; ((m_min++)); }
    if [ -z "$m_skip" ] ; then
      if [ $clock -eq 0 ] ; then
        ((m_sec = $m_int * 6))
        printf "\r%s %-28s %s\b" "$m_inst" "$(tmsg "$pkg" 2)" "$(t_mesg $m_min $m_sec $m_dsec "$m_tic1")"
      elif [ $clock -lt 30 ] ; then 
        printf "\b%s" "$m_tic2"
      elif [ $clock -eq 30 ] ; then 
        printf "%s\b" "$m_vert"
      elif [ $clock -eq 31 ] ; then 
        printf "%s\b" "$m_larr"
      else
        printf "\b\b\b%s" "$m_tic1"
      fi
    fi
    kill -s 0 $pid 2> /dev/null || break # check process by pid
    sleep 0.1
    ((clock++))
  done

  wait $pid; exit_status=$?; [ $exit_status -eq 0 ] || m_done=$(tmsg "fail" 1)

  ((m_sec = $m_int * 6 + $clock / 10))
  ((m_dsec = $clock % 10))

  if [ ! -z "$m_skip" ] ; then
    tput cuu1
    printf "\r%-104s" ""
    tput cuu1
  fi

  printf "\r%s %-28s %-105s\n" "$m_inst" "$(tmsg "$pkg" 2)" "$(t_mesg $m_min $m_sec $m_dsec $m_larr) $m_done$m_note"

  tput cnorm

  return $exit_status
}

upgrade_packages()
{
  check_sudo
  exit_code=1
  if [ ! -z "$u_cmd1" ] ; then
    $s_cmd $p_cmd $u_cmd1 &>> "$LOG" &
    progress_bar $! "all packages" "Upgrading " "$p_cmd"
    if [ $? -eq 0 ] ; then
      if [ -z "$u_cmd2" ] ; then
        exit_code=0
      else
        $s_cmd $p_cmd $u_cmd2 &>> "$LOG"
        progress_bar $! "all packages" "Updating  " "$p_cmd"
        exit_code=$?
      fi
    fi
  fi
  [ $exit_code -eq 0 ] || exit_error "Cannot update packages"
}

install_packages()
{
  check_sudo
  for p in $@
  do
    check_pkg $p; [ $? -ne 0 ] && m_note="new" || m_note="update"
    stdbuf -oL $s_cmd $p_cmd $i_cmd $p &>> $LOG & # line buffered output for tail -f $LOG
  # stdbuf -oL $script_dir/install_pack $p &>> $LOG & # line buffered output for tail -f $LOG
    progress_bar $! $p "Installing" "$m_note"
    if [ $? -ne 0 ] ; then
      printf "%s" "Last command failed. Continue? (y|N) "; read -e answer
      if [[ $answer == [yY] ]] ; then
        tput cuu1; printf "\r%-40s\r" ""
      else
        exit_error "Aborting"
      fi
    fi
  done
}

install_phelpers()
{
  if [ $os_base = "arch" ]; then

    installed yay && return

    local yay="yay-bin"; [ -d "/tmp/$yay" ] && rm -rf "/tmp/$yay"

    git clone https://aur.archlinux.org/$yay.git "/tmp/$yay" &>> $LOG &
    progress_bar $! "$yay" "Cloning   " "clone"
    [ $? -ne 0 ] && exit_error "Cannot clone $yay"

    cd "/tmp/$yay" || exit_error "Failed to change dir to /tmp/$yay"

    makepkg -si --noconfirm --needed &>> $LOG &
    progress_bar $! "yay"  "Installing" "new" "please, wait "
    [ $? -ne 0 ] && exit_error "Cannot install $yay"

    cd "$script_dir" || exit_error "Failed to change dir to $script_dir"

    rm -rf "/tmp/$yay" || exit_error "Cannot remove /tmp/$yay"

    installed yay || exit_error "Cannot install yay"

    yay -Syu --noconfirm &>> $LOG &
    progress_bar $! "all packages"  "Upgrading " "yay"
    [ $? -ne 0 ] && exit_error "Cannot install $yay"
  fi
}

notwant_packages()
{
  local pkgs=""
  for p in $@
  do
    check_pkg $p && pkgs="$p $pkgs"
  done
  [[ -z $pkgs ]] || err "$(echo $pkgs | tr -s ' ') package(s) installed. Uninstall it before run."
}

grep_pci_devices()
{
  lspci | grep -i "$1" &> /dev/null; return $?
}

