#!/bin/bash

lspci -k -d ::03xx

echo "modeset:"
sudo cat /sys/module/nvidia_drm/parameters/modeset
echo "fbdev:"
sudo cat /sys/module/nvidia_drm/parameters/fbdev

