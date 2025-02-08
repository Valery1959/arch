#!/bin/bash

run()
{
  echo "Run '$@'"; $@; [ $? -ne 0 ] && { echo "Cannot run '$@'";  exit 1; }
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
