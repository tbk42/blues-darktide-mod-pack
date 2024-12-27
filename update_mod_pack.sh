#!/bin/bash

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

this_pack_name="Blue's Darktide Mod Pack"
mod_pack_home="${this_pack_name}"

user_home="${HOME}"
games="Games/Darktide"
import="import"
scripts="scripts"
working="working"
zips="source zips"
previous="previous"

added=()
updated=()
removed=()
notes=()

clear
echo -e "${blue}${this_pack_name}${reset}"

if [[ ! -d "${user_home}" ]]; then
	error "Home directory not found. (${cyan}${user_home}${reset})" "exit"
fi
if [[ ! -d "${user_home}/${games}" ]]; then
	error "Games directory not found. (${cyan}${games}${reset})" "exit"
fi

# echo -e "Changing directory to ${cyan}${user_home}/${games}${reset}"
cd "${user_home}/${games}" || error "Unable to change to the user's ${user_home}/${games} directory." "exit"
# pause

if [[ ! -d "${import}" ]]; then
	error "Import directory not found. Making directory: ${cyan}${import}${reset}"
	mkdir -p "${import}"
fi
if [[ ! -d "${scripts}" ]]; then
	error "Scripts directory not found. (${cyan}${scripts}${reset})" "exit"
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

if [[ ! -L "${steam_link_name}" ]]; then
	error "Link to Steam directory not found. Making link: ${cyan}${steam_link_name}${reset}"
	ln -s "${steam_common}/${steam_game_home}" "${steam_link_name}"
fi
if [[ ! -d "${steam_link_name}/mods" ]]; then
	error "Mods directory in Steam game directory not found. Making directory: ${cyan}${steam_link_name}/mods${reset}"
	mkdir -p "${steam_common}/${steam_game_home}/mods"
fi

# read contents of import directory
apply_mod_zips=()
readarray -t "apply_mod_zips" < <(find "./${import}/" -maxdepth "1" -type "f" -name "*.zip" 2>/dev/null | sort | cut -d/ -f3-)

# if =0 zips in import, do not make working directory
# if >0 zips in import, make working directory
if (( ${#apply_mod_zips[*]} > 0 )); then
	if [[ -d "${working}" ]]; then
		if (( $(find "./${working}/" -maxdepth "1" 2>/dev/null | grep -c "") > 1 )); then
			error "Working directory found and not empty, continuing to process previous run."
		else
			error "Empty working directory found."
			echo -e "Removing and exiting: ${cyan}${working}${reset}"
			rm -rf ${working}
			"exit"
		fi
	else
		echo -en "Making directory: ${cyan}${working}${reset} ... "
		mkdir -p "${working}"
		echo -e "${green}done${reset}."
	fi
 fi

for ((z=0; z<${#apply_mod_zips[*]}; z++)) do
	if (( z == 0 )); then
    	echo -e "----------------------------------------------------------------------------------------------------"
    fi

	# Read working directory before extracting zip
	working_dir_listing_before=()
	readarray -t "working_dir_listing_before" < <(find "./${working}/" -maxdepth "1" -type "d" 2>/dev/null | sort | cut -d/ -f3-)

	# step 3: process each zip
	echo -e "Processing zip: ${yellow}${apply_mod_zips[z]}${reset}"
	if [[ -f "${import}/${apply_mod_zips[z]}" ]]; then
		# step 2: extract zip to working
		echo -en "    Extracting contents... "
		unzip -q "${import}/${apply_mod_zips[z]}" -d "${working}"
		echo -e "${green}done${reset}."
		echo -en "    Moving mod's zip file to completed zips directory... "
		mv "${import}/${apply_mod_zips[z]}" "${zips}"
		echo -e "${green}done${reset}."
		echo ""
	fi
	# pause

	# Read working directory after extracting zip
	working_dir_listing_after=()
	readarray -t "working_dir_listing_after" < <(find "./$working/" -maxdepth "1" -type "d" 2>/dev/null | sort | cut -d/ -f3-)

	# step 4: Get unzipped mod directory name
	before=${#working_dir_listing_before[*]}
	after=${#working_dir_listing_after[*]}
	if (( after > before )); then
		for ((i=1; i<(after - before) ; i++)) do
			working_dir_listing_before+=("")
		done
	fi

	apply_mod_directory_name=""
	for ((i=1; i<after; i++)) do
		if [[ "${working_dir_listing_after[i]}" != "${working_dir_listing_before[i]}" ]]; then
			apply_mod_directory_name="$(echo "${working_dir_listing_after[i]}" | rev | cut -d/ -f1 | rev)"
			if [[ -n "${apply_mod_directory_name}" ]]; then
				break
			fi
		fi
	done

	if [[ -z "${apply_mod_directory_name}" ]]; then
		error "Unable to detect mod's directory name in working directory (${cyan}${user_home}/${games}/${working}${reset})" "exit"
	else
		echo -e "Mod directory is named: ${cyan}${apply_mod_directory_name}${reset}"
	fi
	# pause

	# step 5: Check for old version of mod directory, clean
	echo -e "Removing previous versions, as needed"
	update_flag="false"
	blank_line_flag="false"

	# Process the mod pack
	if [[ -d "${mod_pack_home}/mods/${apply_mod_directory_name}" ]]; then
		echo -en "    ...from mod pack: ${yellow}${mod_pack_home}${reset} ... "
		rm -rf "${mod_pack_home}/mods/${apply_mod_directory_name}"
		update_flag="true"
		updated+=("${apply_mod_zips[z]}")
		echo -e "${green}done${reset}."
		blank_line_flag="true"
	fi

	# Process my personal deployment in game
	if [[ -d "${steam_link_name}/mods/${apply_mod_directory_name}" ]]; then
		echo -en "    ...from Steam game: ${yellow}${game_name}${reset} ... "
		rm -rf "${steam_link_name}/mods/${apply_mod_directory_name}"
		echo -e "${green}done${reset}."
		blank_line_flag="true"
	fi

	if [[ "${blank_line_flag}" == "true" ]]; then
		echo -e ""
	fi

	# Process the mod pack
	# step 6: copy mod directory to pack mods
	echo -e "Copying mod directory ..."
	echo -en "    ...to mod pack: ${yellow}${mod_pack_home}${reset} ... "
	cp --preserve=all --recursive "${working}/${apply_mod_directory_name}" "${mod_pack_home}/mods"
	if [[ "${update_flag}" == "false" ]]; then
		added+=("${apply_mod_zips[z]}")
	fi
	echo -e "${green}done${reset}."
	# echo ""
	# pause

	# Process my personal deployment in game
	# step 6: copy mod directory to steam mods
	echo -en "    ...to Steam game: ${yellow}${game_name}${reset} ... "
	cp --preserve=all --recursive "${working}/${apply_mod_directory_name}" "${steam_link_name}/mods"
	echo -e "${green}done${reset}."
	echo ""
	# pause

	# step 8: delete mod directory from working
	echo -e "Cleaning up mod directory from working"
	rm -rf "${working:?}/${apply_mod_directory_name:?}"
	echo ""

	echo ""
   	echo -e "----------------------------------------------------------------------------------------------------"
	# pause
	sleep 2
done

if [[ -d "${working}" ]]; then
	echo -e "Removing directory: ${cyan}${working}${reset}"
	rm -rf ${working}
fi

# Upate version
today=$(date +%+4Y-%m-%d)

version=()
if [[ -f "version.txt" ]]; then
	readarray -t "version" < <(cat "version.txt")
else
	touch "version.txt"
	echo "" > "version.txt"
	echo "" >> "version.txt"
fi

last_version_date=""
if (( ${#version[*]} > 0 )); then
	last_version_date="${version[0]}"
fi
last_version_number=""
if (( ${#version[*]} > 1 )); then
	last_version_number="${version[1]}"
fi

new_version_date="${today}"
new_version_number="0"
if [[ "${last_version_date}" == "${today}" ]]; then
	new_version_number=$(( (last_version_number*1) + 1 ))
fi

echo "${new_version_date}" > "version.txt"
echo "${new_version_number}" >> "version.txt"

# echo -e "Last Version: ${last_version_date}-${last_version_number}"
# echo -e "New Version:  ${new_version_date}-${new_version_number}"
echo -e "New Version Stored In: ${yellow}version.txt${reset}"

alphabet=()
alphabet+=("")
alphabet+=({a..z})
new_version_letter=""
if [[ -n "${new_version_number}" ]]; then
	if (( new_version_number >= 0 && new_version_number <= 26 )); then
		new_version_letter="${alphabet[new_version_number]}"
	else
		error "Version number/letter exceeds 26/z, using just a number."
		new_version_letter="-${new_version_number}"
	fi
fi

# move old zips and sha256 files to previous directory
readarray -t "listing_zip" < <(find "./" -maxdepth "1" -type "f" -name "*.zip" 2>/dev/null | sort)
if (( ${#listing_zip[*]} > 0 )); then
	echo -e "Moving old mod packs to ${previous} directory"
	mv ./*.zip "${previous}"
fi
readarray -t "listing_sha256" < <(find "./" -maxdepth "1" -type "f" -name "*.sha256" 2>/dev/null | sort)
if (( ${#listing_sha256[*]} > 0 )); then
	echo -e "Moving old sha256 files to ${previous} directory"
	mv ./*.sha256 "${previous}"
fi

# step 9: zip up pack
echo -e "Zipping mod pack"
if [[ -d "${mod_pack_home}" ]]; then
	zip -rq "${this_pack_name} ${new_version_date}${new_version_letter}.zip" "${mod_pack_home}"
	if [[ -f "${this_pack_name} ${new_version_date}${new_version_letter}.zip" ]]; then
		sha256sum "${this_pack_name} ${new_version_date}${new_version_letter}.zip" > "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256"
	fi
fi

# Generate text for change log with discord md formatting
echo -e ""
echo -e "Version: **${new_version_date}${new_version_letter}**"
if [[ -f "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256" ]]; then
	echo -e "sha256: **$(cat "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256" | cut -d\  -f1)** $(cat "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256" | cut -d\  -f2-)"
else
	error "No sha256 file found for the file: ${this_pack_name} ${new_version_date}${new_version_letter}.zip"
fi

echo -e "Note: *None*"
if (( ${#added[*]} == 0 )); then
	echo -e "Added: *None*"
else
	for ((a=0; a<${#added[*]}; a++)) do
		echo -e "Added: __${added[a]}__"
	done
fi
if (( ${#updated[*]} == 0 )); then
	echo -e "Updated: *None*"
else
	for ((u=0; u<${#updated[*]}; u++)) do
		echo -e "Updated: __${updated[u]}__"
	done
fi
if (( ${#removed[*]} == 0 )); then
	echo -e "Removed: *None*"
else
	for ((r=0; r<${#removed[*]}; r++)) do
		echo -e "Removed: __${removed[r]}__"
	done
	echo -e ":diamond_shape_with_a_dot_inside: *note: whenever mods are removed from the pack, it is best to eliminate the mods folder before placing this pack.*"
fi
echo -e "Download: **🗹** ***__Latest Version__***"

echo -e ""
echo -e "${green}Complete!${reset}"
echo -e ""
exit 0
