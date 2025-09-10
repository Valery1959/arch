#!/bin/bash

lspci -nnk | grep -E -i --color 'vga|3d|2d' -A3 | grep 'in use'

