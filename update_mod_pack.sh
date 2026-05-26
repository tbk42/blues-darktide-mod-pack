#!/bin/bash

error() {
	local message=""
	message="${1}"
	if [[ "${message}" != "" ]]; then
		printf "%b\n" "${red}Error:${reset} ${message}"
	fi

	local do_exit=""
	do_exit="${2}"
	if [[ -n "${do_exit}" ]]; then
		printf "%b\n" "${red}Exiting${reset}"
		exit 1;
	fi
}

info() {
	local message=""
	message="${1}"
	if [[ "${message}" != "" ]]; then
		printf "%b\n" "${blue}Info:${reset} ${message}"
	fi
}

pause() {
	printf "%b" "Press any key to continue..."
	read -rsn 1
	printf "%s\n" ""
}

# color constants
reset="\e[0m"
blue="\e[38;5;21m"
cyan="\e[38;5;51m"
green="\e[38;5;34m"
# magenta="\e[38;5;165m"
# purple="\e[38;5;57m"
red="\e[38;5;124m"
yellow="\e[38;5;226m"

# Variables
# Important Locations
game_name="Warhammer 40,000: DARKTIDE"

# Configurable paths — adjust these for your system
steam_library="/unified/SteamLibrary"

# Derived paths — do not change
steam_common="${steam_library}/steamapps/common"
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
# notes=()

clear
printf "%b\n" "${blue}${this_pack_name}${reset}"

if [[ ! -d "${user_home}" ]]; then
	error "Home directory not found. (${cyan}${user_home}${reset})" "exit"
fi
if [[ ! -d "${user_home}/${games}" ]]; then
	error "Games directory not found. (${cyan}${games}${reset})" "exit"
fi

# printf "%b\n" "Changing directory to ${cyan}${user_home}/${games}${reset}"
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
		if (( $(find "./${working}/" -mindepth 1 -maxdepth "1" 2>/dev/null | wc -l) > 0 )); then
			error "Working directory found and not empty, continuing to process previous run."
		else
			error "Empty working directory found."
			printf "%b\n" "Removing and exiting: ${cyan}${working}${reset}"
			rm -rf "${working}"
			exit 1
		fi
	else
		printf "%b" "Making directory: ${cyan}${working}${reset} ... "
		mkdir -p "${working}"
		printf "%b\n" "${green}done${reset}."
	fi
 fi

for ((z=0; z<${#apply_mod_zips[*]}; z++)) do
	if (( z == 0 )); then
    	printf "%b\n" "----------------------------------------------------------------------------------------------------"
    fi

	# step 3: process each zip
	printf "%b\n" "Processing zip: ${yellow}${apply_mod_zips[z]}${reset}"
	if [[ -f "${import}/${apply_mod_zips[z]}" ]]; then
		# step 2: extract zip to working
		printf "%b" "    Extracting contents... "
		unzip -q "${import}/${apply_mod_zips[z]}" -d "${working}"
		printf "%b\n" "${green}done${reset}."
		printf "%b" "    Moving mod's zip file to completed zips directory... "
		mv "${import}/${apply_mod_zips[z]}" "${zips}"
		printf "%b\n" "${green}done${reset}."
		printf "%s\n" ""
	fi
	# pause

	# step 4: Get unzipped mod directory name
	readarray -t "working_dirs" < <(find "./${working}/" -mindepth 1 -maxdepth 1 -type "d" 2>/dev/null)
	apply_mod_directory_name=""
	if (( ${#working_dirs[*]} == 1 )); then
		apply_mod_directory_name="$(basename "${working_dirs[0]}")"
	fi

	if [[ -z "${apply_mod_directory_name}" ]]; then
		error "Unable to detect mod's directory name in working directory (${cyan}${user_home}/${games}/${working}${reset})" "exit"
	else
		printf "%b\n" "Mod directory is named: ${cyan}${apply_mod_directory_name}${reset}"
	fi
	# pause

	# step 5: Check for old version of mod directory, clean
	printf "%b\n" "Removing previous versions, as needed"
	update_flag="false"
	blank_line_flag="false"

	# Process the mod pack
	if [[ -d "${mod_pack_home}/mods/${apply_mod_directory_name}" ]]; then
		printf "%b" "    ...from mod pack: ${yellow}${mod_pack_home}${reset} ... "
		rm -rf "${mod_pack_home}/mods/${apply_mod_directory_name}"
		update_flag="true"
		updated+=("${apply_mod_zips[z]}")
		printf "%b\n" "${green}done${reset}."
		blank_line_flag="true"
	fi

	# Process my personal deployment in game
	if [[ -d "${steam_link_name}/mods/${apply_mod_directory_name}" ]]; then
		printf "%b" "    ...from Steam game: ${yellow}${game_name}${reset} ... "
		rm -rf "${steam_link_name}/mods/${apply_mod_directory_name}"
		printf "%b\n" "${green}done${reset}."
		blank_line_flag="true"
	fi

	if [[ "${blank_line_flag}" == "true" ]]; then
		printf "%b\n" ""
	fi

	# Process the mod pack
	# step 6: copy mod directory to pack mods
	printf "%b\n" "Copying mod directory ..."
	printf "%b" "    ...to mod pack: ${yellow}${mod_pack_home}${reset} ... "
	cp --preserve=all --recursive "${working}/${apply_mod_directory_name}" "${mod_pack_home}/mods"
	if [[ "${update_flag}" == "false" ]]; then
		added+=("${apply_mod_zips[z]}")
	fi
	printf "%b\n" "${green}done${reset}."
	# printf "%s\n" ""
	# pause

	# Process my personal deployment in game
	# step 6: copy mod directory to steam mods
	printf "%b" "    ...to Steam game: ${yellow}${game_name}${reset} ... "
	cp --preserve=all --recursive "${working}/${apply_mod_directory_name}" "${steam_link_name}/mods"
	printf "%b\n" "${green}done${reset}."
	printf "%s\n" ""
	# pause

	# step 8: delete mod directory from working
	printf "%b\n" "Cleaning up mod directory from working"
	rm -rf "${working:?}/${apply_mod_directory_name:?}"
	printf "%s\n" ""

	printf "%s\n" ""
   	printf "%b\n" "----------------------------------------------------------------------------------------------------"
	# pause
	sleep 2
done

if [[ -d "${working}" ]]; then
	printf "%b\n" "Removing directory: ${cyan}${working}${reset}"
	rm -rf "${working}"
fi


# -------------------------------------------------------------------------------------------------------------------------

function FindIndex() {
	local value="${1}"
	local array_name="${2}"
	local local_array=()
	local i=0

	case "${array_name}" in
		"alphabet") for ((i=0; i<${#alphabet[*]}; i++)) do
						local_array+=("${alphabet[i]}")
					done
					;;
		*)  printf "%s\n" "-2"
			return
			;;
	esac

	for ((i=0; i<${#local_array[*]}; i++)) do
		if [[ "${local_array[i]}" == "${value}" ]]; then
			break
		fi
	done

	if (( i == ${#local_array[*]} )); then
		printf "%s\n" "-1"
		return
	fi

	printf "%s\n" "${i}"
	return
}

function VersionToFile() {
	local version=""
	# local year=""
	# local month=""
	# local day=""
	local subversion_as_letter=""
	local subversion_as_number=0
	local alphabet=()
	# local filename=""

	version="${1,,}"
	# year="${version:0:4}"
	# month="${version:5:2}"
	# day="${version:8:2}"
	subversion_as_letter="${version:10:1}"

	alphabet=()
	alphabet+=({a..z})

	subversion_as_number=$(FindIndex "${subversion_as_letter,,}" "alphabet")

	printf "%s\n" "${subversion_as_number}"
	return
}

# Upate version
today=$(date +%+4Y-%m-%d)

if [[ ! -f "version.txt" ]]; then
	touch "version.txt"
	printf "%s\n" "" > "version.txt"
	printf "%s\n" "" >> "version.txt"
fi

version=()
if [[ -f "version.txt" ]]; then
	readarray -t "version" < "version.txt"
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

printf "%s\n" "${new_version_date}" > "version.txt"
printf "%s\n" "${new_version_number}" >> "version.txt"

# printf "%b\n" "Last Version: ${last_version_date}-${last_version_number}"
# printf "%b\n" "New Version:  ${new_version_date}-${new_version_number}"
printf "%b\n" "New Version Stored In: ${yellow}version.txt${reset}"

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

# -------------------------------------------------------------------------------------------------------------------------

# move old zips and sha256 files to previous directory
readarray -t "listing_zip" < <(find "./" -maxdepth "1" -type "f" -name "*.zip" 2>/dev/null | sort)
if (( ${#listing_zip[*]} > 0 )); then
	printf "%b\n" "Moving old mod packs to ${previous} directory"
	mv ./*.zip "${previous}"
fi
readarray -t "listing_sha256" < <(find "./" -maxdepth "1" -type "f" -name "*.sha256" 2>/dev/null | sort)
if (( ${#listing_sha256[*]} > 0 )); then
	printf "%b\n" "Moving old sha256 files to ${previous} directory"
	mv ./*.sha256 "${previous}"
fi

# step 9: zip up pack
printf "%b\n" "Zipping mod pack"
if [[ -d "${mod_pack_home}" ]]; then
	[[ -f "${this_pack_name} ${new_version_date}${new_version_letter}.zip" ]] && rm -f "${this_pack_name} ${new_version_date}${new_version_letter}.zip"
	zip -rq "${this_pack_name} ${new_version_date}${new_version_letter}.zip" "${mod_pack_home}"
	if [[ -f "${this_pack_name} ${new_version_date}${new_version_letter}.zip" ]]; then
		sha256sum "${this_pack_name} ${new_version_date}${new_version_letter}.zip" > "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256"
	fi
fi

# Generate text for change log with discord md formatting
printf "%b\n" ""
printf "%b\n" "Version: ${new_version_date}${new_version_letter}"
if [[ -f "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256" ]]; then
	printf "%b\n" "File: $(cat "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256" | cut -d\  -f2-)"
	printf "%b\n" "sha256: **$(cat "${this_pack_name} ${new_version_date}${new_version_letter}.zip.sha256" | cut -d\  -f1)**"
else
	error "No sha256 file found for the file: ${this_pack_name} ${new_version_date}${new_version_letter}.zip"
fi

printf "%b\n" "Note: *None*"
if (( ${#added[*]} == 0 )); then
	printf "%b\n" "Added: *None*"
else
	for ((a=0; a<${#added[*]}; a++)) do
		printf "%b\n" "Added: __$(printf "%s\n" "${added[a]}" | cut -d- -f1)__"
	done
fi
if (( ${#updated[*]} == 0 )); then
	printf "%b\n" "Updated: *None*"
else
	for ((u=0; u<${#updated[*]}; u++)) do
		printf "%b\n" "Updated: __$(printf "%s\n" "${updated[u]}" | cut -d- -f1)__"
	done
fi
if (( ${#removed[*]} == 0 )); then
	printf "%b\n" "Removed: *None*"
else
	for ((r=0; r<${#removed[*]}; r++)) do
		printf "%b\n" "Removed: __$(printf "%s\n" "${removed[r]}" | cut -d- -f1)__"
	done
	printf "%b\n" ":diamond_shape_with_a_dot_inside: *note: whenever mods are removed from the pack, it is best to eliminate the mods folder before placing this pack.*"
fi
printf "%b\n" "Download: **🗹** ***__Latest Version__***"

printf "%b\n" ""
printf "%b\n" "${green}Complete!${reset}"
printf "%b\n" ""
exit 0
