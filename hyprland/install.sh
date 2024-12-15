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

#echo "Update package database"
#run sudo pacman -Syu

# Additional hyprland essential packages (dev packages have to be already installed)
# hyprland (tiling window manager)
# kitty (default terminal for tiling window manager)
# hyprpaper (Wallpaper utility for Hyprland)
# hyprlock (screen lock for Hyprland)
# hypridle (hyprland’s idle daemon)
# waybar (Wayland bar for Sway and Wlroots based compositors)
# wofi (GTK-based customizable launcher for Wayland)
# rofi-wayland (A window switcher, fork with wayland support)
# alacritty (additional terminal, installed as other apps in gnome or kde scripts)
# starship (The cross-shell prompt for astronauts), use powerlevel10k in zsh instead
# swaync (GTK based notification daemon for Sway)
# brightnessctl (Lightweight brightness control tool)
# stow (GNU Stow - Manage installation of multiple softwares in the same directory tree)
# ttf-font-awesome (Iconic font designed for Bootstrap)
# ttf-cascadia-code-nerd (Patched font Cascadia Code (Caskaydia) from nerd fonts library)
# papirus-icon-theme (Papirus icon theme for rofi application launcher)

packages="hyprland kitty"
packages="$packages hyprpaper hyprlock hypridle waybar rofi-wayland wofi"
packages="$packages starship swaync brightnessctl stow"
#packages="$packages ttf-font-awesome ttf-cascadia-code-nerd papirus-icon-theme"
packages="$packages ttf-font-awesome ttf-cascadia-code-nerd"

run sudo pacman -S --noconfirm --needed $packages

# AUR hyprland essential packages
aur_packages="papirus-icon-theme"
run yay -S --noconfirm --needed $aur_packages

cur_date=$(date '+%Y.%m.%d_%H.%M.%S')

if [ -d $HOME/dotfiles ] ; then # Backup existing dotfiles
  [ ! -d $HOME/backups ] && run mkdir $HOME/backups
  run mv $HOME/dotfiles $HOME/backups/dotfiles_$cur_date
fi

run cp -r $script_dir/dotfiles ~/

# stow configuration packages
stow_packages="backgrounds hyprlock hyprmocha hyprpaper kitty rofi starship waybar wofi"

for p in $stow_packages
do
  n=$HOME/.config/$p

  if [ -h $n ] ; then
    run rm $n
  elif [ -d $n ] ; then
    run mv $p $HOME/backups/$p_$cur_date
  fi
done

echo "enable hyprland configuration"
( 
  cd ~/dotfiles
  run stow $stow_packages
)

echo "copy hypridle.conf, hyprland.conf - as cannot stow them"
run rsync -lvrpt  $script_dir/dotfiles/hypr ~/.config 

# eval "$(starship init bash)"

exit 0
