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
  #pacman -Qq | grep -qw '^'$1'$'; return $?
  apt list | grep -qw '^'$1'$'; return $?
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


install()
{
  local c1="●"
  local c2="○●"

  for p in $@
  do
    #pacman -Q $p &> /dev/null && { echo "$p is already installed"; continue; }
    #echo "Install $p"
    #sudo pacman -Sq --noconfirm --needed $p
    m_sec=0
    m_min=0
    tput civis
    while true
    do
      if [ $m_sec -ge 60 ] ; then
        m_sec=0; ((m_min++))
      fi
      if [ $m_sec -eq 0 ] ; then
        printf "\r%s" "$(tmsg Installing 3) $(tmsg $p 2) $m_min min $(tmsg $c1 5)"
      fi
      if [ $m_min -ge 3 ] ; then
         break
      fi
      #sleep 1
      sleep 0.1
      printf "\b%s" "$(tmsg $c2 5)"
      ((m_sec++))
    done
    printf "\r%-160s\n" "$(tmsg Installing 3) $(tmsg $p 2) -> $(tmsg Done! 5)"
    tput cnorm
  done
}
