#!/bin/bash

# This script will rebuild the mod deployment for my personal darktide install and act as a prototype and
# model for a modpack install script.

error() {
	local message=""
	message="${1}"
	if [[ "${message}" != "" ]]; then
		echo -e "${red}Error:${reset} ${message}"
	fi

	local do_exit=""
	do_exit="${2}"
	if [[ -n "${do_exit}" ]]; then
		echo -e "${red}Exiting${reset}"
		exit 1;
	fi
}

info() {
	local message=""
	message="${1}"
	if [[ "${message}" != "" ]]; then
		echo -e "${blue}Info:${reset} ${message}"
	fi
}

pause() {
	echo -en "Press any key to continue..."
	read -rsn 1
	echo ""
}

# color constants
reset="\e[0m"
blue="\e[38;5;21m"
cyan="\e[38;5;51m"
green="\e[38;5;34m"
magenta="\e[38;5;165m"
purple="\e[38;5;57m"
red="\e[38;5;124m"
yellow="\e[38;5;226m"

# Variables
# Important Locations
game_name="Warhammer 40,000: DARKTIDE"
steam_common="/unified/SteamLibrary/steamapps/common"
steam_game_home="Warhammer 40,000 DARKTIDE"
steam_link_name="Link To ${steam_game_home}"

# General location Directories
user_home="${HOME}"
games="Games"

# Modpack Directories
WH40KDT="Darktide"
this_pack_name="Blue's Darktide Mod Pack"
mod_pack_home="${this_pack_name}"

# Modpack Maintenance Directories
import="import"
scripts="scripts"
working="working"
zips="source zips"
previous="previous"

clear
echo -e "${blue}${this_pack_name}${reset}"

# Type: Critical / Exit
if [[ ! -d "${user_home}" ]]; then
	error "Home directory not found. (${cyan}${user_home}${reset})" "exit"
fi
if [[ ! -d "${user_home}/${games}" ]]; then
	error "Games directory not found. (${cyan}${games}${reset})" "exit"
fi
if [[ ! -d "${user_home}/${games}/${WH40KDT}" ]]; then
	error "Warhammer directory not found. (${cyan}${WH40KDT}${reset})" "exit"
fi

# echo -e "Changing directory to ${cyan}${user_home}/${games}${reset}"
cd "${user_home}/${games}/${WH40KDT}" || error "Unable to change to the user's ${user_home}/${games}/${WH40KDT} directory." "exit"
# pause

if [[ ! -d "${scripts}" ]]; then
	error "Scripts directory not found. (${cyan}${scripts}${reset})" "exit"
fi



# Type: Warning / Self-fix
if [[ ! -d "${import}" ]]; then
	error "Import directory not found. Making directory: ${cyan}${import}${reset}"
	mkdir -p "${import}"
fi
if [[ ! -d "${zips}" ]]; then
	error "Zips directory not found. Making directory: ${cyan}${zips}${reset}"
	mkdir -p "${zips}"
fi
if [[ ! -d "${mod_pack_home}" ]]; then
	error "Mod Pack home directory not found. Making directory: ${cyan}${mod_pack_home}${reset}"
	mkdir -p "${mod_pack_home}"
fi
if [[ ! -d "${mod_pack_home}/mods" ]]; then
	error "Mods directory in Mod Pack home directory not found. Making directory: ${cyan}${mod_pack_home}/mods${reset}"
	mkdir -p "${mod_pack_home}/mods"
fi


# Type: Warning / Self-fix
if [[ ! -L "${steam_link_name}" ]]; then
	error "Link to Steam directory not found. Making link: ${cyan}${steam_link_name}${reset}"
	ln -s "${steam_common}/${steam_game_home}" "${steam_link_name}"
fi
if [[ ! -d "${steam_link_name}/mods" ]]; then
	error "Mods directory in Steam game directory not found. Making directory: ${cyan}${steam_link_name}/mods${reset}"
	mkdir -p "${steam_common}/${steam_game_home}/mods"
fi


# Copy the non-mod parts of the pack into place in case there was an update to any of it.
echo -e "Copying overhead of mod pack"
cp --preserve=all --recursive --verbose --force --target-directory="${steam_link_name}" "${this_pack_name}/binaries"
cp --preserve=all --recursive --verbose --force --target-directory="${steam_link_name}" "${this_pack_name}/bundle"
cp --preserve=all --recursive --verbose --force --target-directory="${steam_link_name}" "${this_pack_name}/tools"
cp --preserve=all --recursive --verbose --force --target-directory="${steam_link_name}" "${this_pack_name}/README.md"
cp --preserve=all --recursive --verbose --force --target-directory="${steam_link_name}" "${this_pack_name}/toggle_darktide_mods.bat"
cp --preserve=all --recursive --verbose --force --target-directory="${steam_link_name}" "${this_pack_name}/toggle_darktide_mods.sh"

echo -e "Removing mods from game"
rm -rf "${steam_link_name}/mods"

echo -e "Deploying mods to game"
cp --preserve=all --recursive --verbose --force --target-directory="${steam_link_name}" "${this_pack_name}/mods"

echo -en "Mod pack version: deployed."
exit
