#!/usr/bin/env bash

script_dir=$(cd $(dirname $0); pwd -P)

source $script_dir/../utils.sh

run rustup default stable

exit 0
