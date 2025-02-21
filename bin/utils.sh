#!/bin/bash

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
 a=1; return 1
  #pacman -Qq | grep -qw '^'$1'$'; return $?
  #apt list | grep -qw '^'$1'$'; return $?
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

progress()
{
  local c1="● "; local c2="○●"; local c3="->"; local c4="<-"; local c5="|"
  local m_tic=0; local m_min=0; local m_int=0; local m_sec=0

  local pid=$1
  local p=$2

  tput civis

    while true
    do
      [ $m_tic -ge 60 ] && { m_tic=0; ((m_int++)); }
      [ $m_int -ge 10 ] && { m_int=0; ((m_min++)); }
      if [ $m_tic -eq 0 ] ; then
        ((m_sec = $m_int * 6))
        printf "\r%s %-25s %s\b" "$(tmsg Installing 3)" "$(tmsg $p 2)" "$(tmsg $c3 5) $(tmsg "$(t_time $m_min $m_sec)" 4) $(tmsg "$c1" 5)"
      elif [ $m_tic -lt 30 ] ; then 
        printf "\b%s" "$(tmsg $c2 5)"
      elif [ $m_tic -eq 30 ] ; then 
        printf "%s\b" "$(tmsg $c5 5)"
      elif [ $m_tic -eq 31 ] ; then 
        printf "%s\b" "$(tmsg $c4 5)"
      else
        printf "\b\b\b%s" "$(tmsg "$c1" 5)"
      fi
      ps -p $pid &> /dev/null || break
      #[ $m_int -ge 1 ] && [ $m_tic = 40 ] && break
      sleep 0.1
      ((m_tic++))
    done
    ((m_sec = $m_int * 6 + $m_tic / 10))
    printf "\r%s %-25s %-160s\n" "$(tmsg Installing 3)" "$(tmsg $p 2)" "$(tmsg $c3 5) $(tmsg "$(t_time $m_min $m_sec)" 4) $(tmsg $c4 5) $(tmsg "done" 2)"

  tput cnorm
}

install_pack()
{
  sudo apt install $p -y > /dev/null 2>&1
  #sudo pacman -Sq --noconfirm --needed $p  > /dev/null 2>&1
}

install()
{

  for p in $@
  do
    apt show $p &> /dev/null  && { echo "$p is already installed"; continue; }
    #pacman -Q $p &> /dev/null && { echo "$p is already installed"; continue; }
    #echo "Install $p"
    #sudo pacman -Sq --noconfirm --needed $p
    install_pack $p &
    progress $! $p
  done
}
