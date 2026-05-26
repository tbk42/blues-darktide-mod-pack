#!/bin/bash
####################################################################################################
# Blue's Mod Pack Scripts - Toggle Darktide Mods
# 
# First things first, exit the game!
# 
# Run this script to activate or deactivate mods in Darktide.
# 
# This script locates Darktide on your drive and deploys the mod pack or individual
# core mods (DML, DMF, AMLAO) to the game directory. It then runs the Darktide Mod
# Loader's patcher to toggle mod support on or off. I did not create nor do I maintain
# any of these mods — they are the IP of their respective authors. My script just
# automates detection and deployment.
# 
# Preferred deployment: place "Blue's Darktide Mod Pack*.zip" next to this script.
# The mod pack is a complete deployment containing everything needed.
# 
# Fallback: place the three individual mod zips in the same directory as this script.
#   Darktide Mod Loader ------------- https://www.nexusmods.com/warhammer40kdarktide/mods/19
#   Darktide Mod Framework ---------- https://www.nexusmods.com/warhammer40kdarktide/mods/8
#   Auto Mod Loading and Ordering --- https://www.nexusmods.com/warhammer40kdarktide/mods/246
# 
# Run this script again to toggle mods back off via the patcher. 
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

function find_zip_in_search_paths() {
	local pattern="${1}"
	local search_paths=()
	search_paths+=("${PWD}")
	search_paths+=("$(dirname "${0}")")
	search_paths+=("$(dirname "$(realpath "${0}")")")

	for search_path in "${search_paths[@]}"; do
		if [[ ! -d "${search_path}" ]]; then continue; fi
		local found=
		found="$(find "${search_path}" -maxdepth 1 -type "f" -name "${pattern}" -print -quit 2>/dev/null)"
		if [[ -n "${found}" ]]; then
			printf "%s\n" "${found}"
			return 0
		fi
	done
	printf "%s\n" ""
	return 1
}

function deploy_zip_to_game() {
	local zip_file="${1}"
	local display_name="${2}"
	local target="${3:-${darktide_found_dir}}"
	if [[ -z "${zip_file}" ]] || [[ ! -f "${zip_file}" ]]; then
		printf "%b\n" "    ${display_name} zip not found at '${zip_file}'."
		return 1
	fi
	printf "%b" "    Extracting ${display_name} ... "
	unzip -qo "${zip_file}" -d "${target}"
	local ret=$?
	if (( ret == 0 )); then
		printf "%b\n" "done."
	else
		printf "%b\n" "failed (exit code ${ret})."
	fi
	return ${ret}
}

function clean_mod_loader() {
	printf "%b\n" "    Cleaning up old Darktide Mod Loader files ..."
	local items=()
	items+=("binaries/mod_loader")
	items+=("bundle/9ba626afa44a3aa3.patch_999")
	items+=("mods/base")
	items+=("tools/dtkit-patch.exe")
	for item in "${items[@]}"; do
		if [[ -f "${darktide_found_dir}/${item}" ]]; then
			rm -f "${darktide_found_dir}/${item}"
		elif [[ -d "${darktide_found_dir}/${item}" ]]; then
			rm -rf "${darktide_found_dir}/${item}"
		fi
	done
	printf "%b\n" "    done."
}

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

### Search for mod pack and individual core mod zips ###
printf "%b\n" "Searching for mod pack and core mod zip files ..."
mod_pack_zip="$(find_zip_in_search_paths "Blue's Darktide Mod Pack*.zip")"
dml_zip="$(find_zip_in_search_paths "Darktide Mod Loader-19-*.zip")"
dmf_zip="$(find_zip_in_search_paths "Darktide Mod Framework-8-*.zip")"
amlao_zip="$(find_zip_in_search_paths "Auto Mod Loading and Ordering-246-*.zip")"

### Mod Pack (full deployment) ###
if [[ -n "${mod_pack_zip}" ]]; then
	printf "%b\n" "Mod pack found. Deploying full mod pack to game directory ..."
	clean_mod_loader
	deploy_zip_to_game "${mod_pack_zip}" "Mod pack"
else
	printf "%b\n" "No mod pack zip found. Deploying from individual mod zips ..."

	### Darktide Mod Loader ###
	dml_deployed="$(check_for_mod_loader "${darktide_found_dir}")"
	if [[ "${dml_deployed}" == "false" ]]; then
		if [[ -n "${dml_zip}" ]]; then
			printf "%b\n" "Darktide Mod Loader is not deployed. Installing from zip ..."
			clean_mod_loader
			deploy_zip_to_game "${dml_zip}" "Darktide Mod Loader"
		else
			printf "%b\n" "Darktide Mod Loader is not deployed and no zip was found."
			printf "%b\n" "  Download from: https://www.nexusmods.com/warhammer40kdarktide/mods/19"
			printf "%b\n" "  Place the zip next to this script and run again."
			pause
		fi
	else
		printf "%b\n" "Darktide Mod Loader is already deployed."
	fi

	### Darktide Mod Framework ###
	if [[ ! -d "${darktide_found_dir}/mods/dmf" ]]; then
		if [[ -n "${dmf_zip}" ]]; then
			printf "%b\n" "Darktide Mod Framework not found. Installing from zip ..."
			deploy_zip_to_game "${dmf_zip}" "Darktide Mod Framework" "${darktide_found_dir}/mods"
		else
			printf "%b\n" "Darktide Mod Framework zip not found. Skipping."
			printf "%b\n" "  Download from: https://www.nexusmods.com/warhammer40kdarktide/mods/8"
		fi
	else
		printf "%b\n" "Darktide Mod Framework is already deployed."
	fi

	### Auto Mod Loading and Ordering ###
	if [[ ! -f "${darktide_found_dir}/mods/base/base.mod" ]]; then
		if [[ -n "${amlao_zip}" ]]; then
			printf "%b\n" "Auto Mod Loading and Ordering not found. Installing from zip ..."
			deploy_zip_to_game "${amlao_zip}" "Auto Mod Loading and Ordering" "${darktide_found_dir}/mods"
		else
			printf "%b\n" "Auto Mod Loading and Ordering zip not found. Skipping."
			printf "%b\n" "  Download from: https://www.nexusmods.com/warhammer40kdarktide/mods/246"
		fi
	else
		printf "%b\n" "Auto Mod Loading and Ordering is already deployed."
	fi
fi

### Validate deployment ###
printf "%b\n" "Verifying mod loader deployment ..."
dml_deployed="$(check_for_mod_loader "${darktide_found_dir}")"
if [[ "${dml_deployed}" == "false" ]]; then
	printf "%s\n" "Mod loader verification failed. Required files are missing."
	printf "%s\n" "Exiting."
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
