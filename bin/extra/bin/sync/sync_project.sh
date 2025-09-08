#!/bin/bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

check_dir()
{
   host=$(echo $1 | cut -d: -f 1 )
   path=$(echo $1 | cut -d: -f 2-)

   [ $host = $path ] && { test -d $path; return $?; }

   ssh $host "test -d $path"
}

[ -z "$1" ] || ! check_dir "$1"  && { echo "Source directory does not exist: $1"; exit 1; }
[ -z "$2" ] || ! check_dir "$2"  && { echo "Target directory does not exist: $2"; exit 1; }

run rsync -lrptm --exclude='*/build.*/*' --exclude='*/.vscode/*' --exclude='*/out/*' \
                 --include='*/' --include='*.h' --include='*.hpp' --include='*.cpp' --include='*.txt' --include='*.sh' \
                 --include="CMakeKits.json" --include="LICENSE" --include="README*" --include=".gitignore" \
                 --exclude='*'  "$1" "$2"

exit 0

