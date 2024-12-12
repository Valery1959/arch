#!/bin/bash
# install development packages
# git clone https://github.com/typecraft-dev/dotfiles.git

script_dir=$(cd $(dirname $0); pwd -P)

run()
{
  echo "Run '$@'"; "$@"; [ $? -ne 0 ] && { echo "Cannot run '$@'"; exit 1; }
}

which yay >/dev/null 2>&1; [ $? -ne 0 ] && { echo "Please install dev packages"; exit 1; }
which git >/dev/null 2>&1; [ $? -ne 0 ] && { echo "Please install dev packages"; exit 1; }

echo "Update package database"
run sudo pacman -Syu

# Additional hyprland essential packages (dev packages have to be already installed)
# hyprland (tiling window manager)
# kitty (default terminal for tiling window manager)
# alacritty (additional terminal, installed as other apps in gnone or kde scripts)
# waybar (Wayland bar for Sway and Wlroots based compositors)
# wofi (GTK-based customizable launcher for Wayland)
# ttf-font-awesome (Iconic font designed for Bootstrap)
# ttf-cascadia-code-nerd (Patched font Cascadia Code (Caskaydia) from nerd fonts library)
# stow (GNU Stow - Manage installation of multiple softwares in the same directory tree)
# hyperpaper (Wallpaper utility for Hyprland)
# starship (The cross-shell prompt for astronauts)
# swaync (GTK based notification daemon for Sway)
# hyprlock (screen lock for Hyprland)
# hypridle (hyprland’s idle daemon)
# brightnessctl (Lightweight brightness control tool)

packages="hyprland kitty alacritty waybar wofi ttf-font-awesome ttf-cascadia-code-nerd stow hyperpaper starship swaync hyprlock hypridle brightnessctl"

run sudo pacman -S --noconfirm --needed $packages

# AUR hyprland essential packages
# aur_packages=""
# run yay -S $aur_packages
 
# rm -r ~/.config/waybar

run cp -r $script_dir/dotfiles ~/


# Enable configuration
( 
  cd ~/dotfiles
  run stow hyprlock
  run stow hyprmocha
  run stow hyperpaper
  run stow kitty
  run stow rofi
  run stow starship
  run stow waybar
  run stow wofi
)

echo "copy hypridle.conf, hyprland.conf - as cannot stow them"
run rsync -lvrpt  $script_dir/dotfiles/hypr ~/.config 

# eval "$(starship init bash)"

exit 0
