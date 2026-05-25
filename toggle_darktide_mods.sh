#!/bin/bash
####################################################################################################
# Blue's Mod Pack Scripts - Toggle Darktide Mods
# 
# First things first, exit the game!
# 
# Run this script to activate the ability to use mods in Darktide.
# 
# This script locates Darktide on your drive. If needed and available locally (in the same directory
# as this script), it will copy in the Darktide Mod Loader, Darktide Mod Framework, and Auto Mod
# Loading and Ordering. Together, these three mods make using mods in Darktide possible, consistent,
# and easy to manage. I did not create nor do I maintain any of these. They are the IP of their
# respective authors. My script just makes it as easy as I can for you, the player, by automating
# detection and deploymeent. In other words, run this script and it does the minimal work for you.
# Nexus Mods prevents us from automatically downloading the latest copy, so if you need them, here
# are the URLs for each of the mods. Place the three zips in the same directory as this script, then
# run this script.
# 
#   Darktide Mod Loader ------------- https://www.nexusmods.com/warhammer40kdarktide/mods/19
#   Darktide Mod Framework ---------- https://www.nexusmods.com/warhammer40kdarktide/mods/8
#   Auto Mod Loading and Ordering --- https://www.nexusmods.com/warhammer40kdarktide/mods/246
# 
# After seeing that these three are deployed, this script checks for a mod pack zip and compares it
# to the current mod deployment. If the mod directory is otherwise empty (except the three
# previously mentioned mods) then it deploys the pack from the zip) into the game's mod directory.
# 
# Most importantly, this script will trigger the Darktide Mod Loader's patcher.
# 
# The patcher will pop up a dialog on your screen either notifying you that it activated the patch,
# or asking if you want to remove the patch or not.
# 
# Once activated, the mods load with the game.
# 
# To toggle ALL mods back off entirely, run this script again to activate the unpatch feature. 
# 
####################################################################################################

### Configuration ###
scan_paths=()
# first check in the user's $HOME directory for the game
scan_paths+=("$HOME/")
# next, check in the unified/SteamLibrary directory for the game
scan_paths+=("/unified/SteamLibrary/")
# lastly, check in the / (root directory) and below for the game
scan_paths+=("/")

### Function and Subroutine Library ###
pause() {
	read -rsn 1 -p "Press any key to continue"
	printf "%s\n" ""
}

countdown_from() {
	# default delay to 5 seconds
	local delay="${1:-5}"
	local i b back_str
	for ((i = delay; i > 0; i--)) do
		printf "%b" "${i}... "
		sleep 1
		back_str=""
		# +4 for "... " (e.g., "5... ")
		for ((b = 0; b < ${#i} + 4; b++)); do
			back_str+="\b"
		done
		printf "%b" "${back_str}"
	done
}

function find_darktide_in() {
	local path_to_scan="${1}"
	if [[ -z "${path_to_scan}" ]]; then return 1; fi
	if [[ ! -d "${path_to_scan}" ]]; then return 2; fi

	# Use -print -quit to stop find after the first match and output the path.
	# 2>/dev/null suppresses errors like "permission denied" during find.
	darktide_found_dir=$(find "${path_to_scan}" "${current_find_args[@]}" -print -quit 2>/dev/null)

	if [[ -z "$darktide_found_dir" ]]; then return 3; fi

	printf "%s\n" "${darktide_found_dir}"
	return 0
}

# deploy_loader() {}
# deploy_framework() {}
# deploy_ordering() {}

### Main Script ###
current_find_args=("-type" "d" "-name" "Warhammer 40,000 DARKTIDE")

# Variable to store the found directory path
printf "%b\n" "Locating Warhammer 40,000: Darktide please wait..."

# clear any previous result
darktide_found_dir=""

for path_to_scan in "${scan_paths[@]}"; do
	if [[ -z "${path_to_scan}" ]]; then continue; fi

	printf "%b" "  Checking ${path_to_scan} ..."

	if [[ ! -d "${path_to_scan}" ]]; then
		printf "%b\n" " directory not found."
		continue
	fi

	if [[ "${path_to_scan}" == "/" ]]; then
		printf "%b\n" ""
		printf "%b" "    Initial checks failed to locate Darktide. Checking / (root directory), this may take a while..."
	fi

	darktide_found_dir="$(find_darktide_in "${path_to_scan}")"

	case "$?" in
		0) printf "%b\n" "Found Darktide in ${darktide_found_dir}."; break;; # good return
		1) ;; # no value passed to function; should never happen
		2) ;; # passed path was not a directory; should never happen
		3) printf "%b\n" "Darktide not found here.";; # game not found in passed path
		*) ;; # unexpected return value
	esac
done

if [[ -z "${darktide_found_dir}" ]]; then
	printf "%b\n" "All checks failed to locate Warhammer 40,000: Darktide."
	printf "%b\n" "Exiting."
	exit 1
fi

# Since we found Darktide, change directory...
cd "${darktide_found_dir}" || { printf "%s\n" "Unable to change directory to '${darktide_found_dir}', exiting."; exit 1; }


function check_for_mod_loader() {
	# Check for Darktide Mod Loader in the supplied path

	local path="${1}"
	if [[ -z "${path}" ]]; then printf "%s\n" "false"; return 1; fi

	# Set up Mod Loader array
	local mod_loader=()
	mod_loader+=("directory" "binaries")
	mod_loader+=("file" "binaries/mod_loader")
	mod_loader+=("directory" "bundle")
	mod_loader+=("file" "bundle/9ba626afa44a3aa3.patch_999")
	mod_loader+=("directory" "mods")
	mod_loader+=("directory" "mods/base")
	mod_loader+=("file" "mods/base/mod_manager.lua")
	mod_loader+=("directory" "tools")
	mod_loader+=("file" "tools/dtkit-patch.exe")

	# Check the mod_loader array to be sure everything is there.
	local dml_counter=0
	for index in "${!mod_loader[@]}"; do
		local type=${mod_loader[$index]}
		local object=""
		if (( index+1 < ${#mod_loader[@]} )); then
			object=${mod_loader[$((index+1))]}
		fi
		if [[ "${type}" == "directory" ]]; then
			if [[ -d "${object}" ]]; then
				((dml_counter++))
			fi
		elif [[ "${type}" == "file" ]]; then
			if [[ -f "${object}" ]]; then
				((dml_counter++))
			fi
		fi
	done

	# compare the tests to the checks
	if (( dml_counter == ${#mod_loader[@]} )); then
		printf "%s\n" "true"
	else
		printf "%s\n" "false"
	fi
	return 0
}

dml_zip_filename="$(find ./ -maxdepth 1 -type "f" -name "Darktide Mod Loader-19-*.zip" -print -quit 2>/dev/null | cut -d/ -f2)"
dmf_zip_filename="$(find ./ -maxdepth 1 -type "f" -name "Darktide Mod Framework-8-*.zip" -print -quit 2>/dev/null | cut -d/ -f2)"
amlao_zip_filename="$(find ./ -maxdepth 1 -type "f" -name "Auto Mod Loading and Ordering-246-*.zip" -print -quit 2>/dev/null | cut -d/ -f2)"

dml_flag="$(check_for_mod_loader "${darktide_found_dir}")"
if [[ "${dml_flag}" == "false" ]]; then
	if [[ -n "${dml_zip_filename}" ]]; then
	else
	fi
else
fi




# Check for Darktide Mod Loader
# Set up Mod Loader array
mod_loader=()
mod_loader+=("d" "binaries")
mod_loader+=("f" "binaries/mod_loader")
mod_loader+=("d" "bundle")
mod_loader+=("f" "bundle/9ba626afa44a3aa3.patch_999")
mod_loader+=("d" "mods")
mod_loader+=("d" "mods/base")
mod_loader+=("f" "mods/base/mod_manager.lua")
mod_loader+=("d" "tools")
mod_loader+=("f" "tools/dtkit-patch.exe")

# Check the mod_loader array to be sure everything is there.
dml_flag=0
for i in "${!mod_loader[@]}"; do
    t=${mod_loader[$i]}
    if (( i+1 < ${#mod_loader[@]} )); then
        o=${mod_loader[$((i+1))]}
    else
        o=""
    fi
	if [[ "${t}" == "d" ]]; then
		if [[ -d "${o}" ]]; then
			((dml_flag++))
		fi
	elif [[ "${t}" == "f" ]]; then
		if [[ -f "${o}" ]]; then
			((dml_flag++))
		fi
	fi
done

if (( dml_flag != ${#mod_loader[@]} )); then
	clean_mod_loader
	deploy_mod_loader
fi



if [[ "${exit_flag}" == "true" ]]; then
	printf "%s\n" "I could not find the patcher or required directories and files, unable to run."
	printf "%s\n" "I am in ${PWD}"
	exit 1
fi




# Check for Darktide Mod Framework
# Check for Auto Mod Loading and Ordering








# Check the mod_loader array to be sure everything is there.
exit_flag="false"
for i in "${!mod_loader[@]}"; do
    t=${mod_loader[$i]}
    if (( i+1 < ${#mod_loader[@]} )); then
        o=${mod_loader[$((i+1))]}
    else
        o=""
    fi
	if [[ "${t}" == "d" ]]; then
		if [[ ! -d "${o}" ]]; then
			printf "%b\n" "I could not find the ${o} directory"
			exit_flag="true"
		fi
	elif [[ "${t}" == "f" ]]; then
		if [[ ! -f "${o}" ]]; then
			printf "%b\n" "I could not find the file named ${o}"
			exit_flag="true"
		fi
	fi
done
if [[ "${exit_flag}" == "true" ]]; then
	printf "%s\n" "I could not find the patcher or required directories and files, unable to run."
	printf "%s\n" "I am in ${PWD}"
	exit 1
fi

printf "%b\n" "Running patcher... Please see the patcher's popup message."
readarray -t "patchlog_array" < <(wine "./tools/dtkit-patch.exe" --toggle ".\bundle" 2>&1)
for line in "${patchlog_array[@]}"; do
	if [[ "${line,,}" =~ bundle_database.data ]]; then
		# successfully patched "bundle_database.data"
		# successfully unpatched "bundle_database.data"
		# "bundle_database.data" already patched
		case "$(printf "%s\n" "${line,,}" | cut -d' ' -f2)" in
			"patched")   printf "%s\n" "Successfully patched the Darktide bundle database.";
							countdown_from 5
							;;
			"unpatched") printf "%s\n" "Successfully unpatched the Darktide bundle database.";
							countdown_from 5
							;;
			"already")   printf "%s\n" "The Darktide bundle database was already patched.";
							countdown_from 5
							;;
			*) 			 printf "%s\n" "Error: Unusual message detected.";
							printf "%s\n" "Message: ${line}"
							pause
							;;
		esac
	fi
done

printf "%b\n" "Goodbye."
exit 0
