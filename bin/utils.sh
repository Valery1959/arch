#!/bin/bash

#set -e

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
}

err()
{
  echo "$@"; exit 1;
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
    
  printf "\r%s %-25s %-160s\n" "$m_inst" "$(tmsg $pkg 2)" "$(t_mesg $m_min $m_sec $m_larr) $m_done"

  tput cnorm

  return $exit_status
}

LOG=$script_dir/log_file

install_packages()
{
  sudo apt list &> /dev/null
  #sudo pacman -Q $p &> /dev/null
  for p in $@
  do
    stdbuf -oL stdbuf -oL sudo apt install $p -y &>> $LOG & # line buffered output for tail -f $LOG
   #stdbuf -oL stdbuf -oL sudo apt install $p -y &>> $LOG & # line buffered output for tail -f $LOG
   #stdbuf -oL stdbuf -oL sudo pacman -Sq --noconfirm --needed $p &>> $LOG & # line buffered output for tail -f $LOG
   #stdbuf -oL $script_dir/install_pack $p &>> $LOG & # line buffered output for tail -f $LOG
    progress_bar $! $p
    if [ $? -ne 0 ] ; then
      printf "%s" "Last command failed. Continue? (y|N) "; read answer
      [[ ! $answer == [yY] ]] && { echo "Aborting execution, see $LOG file for details"; break; }
      printf "\r%-160s" ""
      tput cuu1
    fi
  done
}
