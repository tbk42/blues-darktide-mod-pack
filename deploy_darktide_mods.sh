#!/bin/bash
####################################################################################################
# Blue's Mod Pack Scripts - Deploy Darktide Mods
#
# First things first, exit the game!
#
# Run this script to deploy mods to Darktide and toggle the mod loader's patch.
#
# This script locates Darktide on your drive, then deploys all Nexus mod zips from
# a given directory. It extracts them in dependency order:
#   1. Darktide Mod Loader (DML) — extracted to the game root
#   2. Darktide Mod Framework (DMF) — extracted to mods/
#   3. Auto Mod Loading and Ordering (AMLAO) — extracted to mods/ (overwrites base/)
#   4. All remaining mods — extracted to mods/
#
# After deployment it runs the Darktide Mod Loader patcher to enable or disable mods.
#
# Usage: ./deploy_darktide_mods.sh [zips_directory]
#   If no directory is given, looks for zips alongside this script.
#
# Nexus Mods prevents automatic downloads. Place the required zips in the directory
# alongside this script before running.
#   Darktide Mod Loader ------------- https://www.nexusmods.com/warhammer40kdarktide/mods/19
#   Darktide Mod Framework ---------- https://www.nexusmods.com/warhammer40kdarktide/mods/8
#   Auto Mod Loading and Ordering --- https://www.nexusmods.com/warhammer40kdarktide/mods/246
#
# Run this script again to toggle mods back off via the patcher.
#
####################################################################################################

### Configuration ###
scan_paths=()
scan_paths+=("$HOME/")
scan_paths+=("/unified/SteamLibrary/")
scan_paths+=("/")

### Function and Subroutine Library ###
pause() {
	read -rsn 1 -p "Press any key to continue"
	printf "%s\n" ""
}

countdown_from() {
	local delay="${1:-5}"
	local i b back_str
	for ((i = delay; i > 0; i--)) do
		printf "%b" "${i}... "
		sleep 1
		back_str=""
		for ((b = 0; b < ${#i} + 4; b++)); do
			back_str+="\b"
		done
		printf "%b" "${back_str}"
	done
}

find_darktide_in() {
	local path_to_scan="${1}"
	if [[ -z "${path_to_scan}" ]]; then return 1; fi
	if [[ ! -d "${path_to_scan}" ]]; then return 2; fi

	darktide_found_dir=$(find "${path_to_scan}" "${current_find_args[@]}" -print -quit 2>/dev/null)

	if [[ -z "$darktide_found_dir" ]]; then return 3; fi

	printf "%s\n" "${darktide_found_dir}"
	return 0
}

check_for_mod_loader() {
	local path="${1}"
	if [[ -z "${path}" ]]; then printf "%s\n" "false"; return 1; fi

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

	if (( dml_counter == ${#mod_loader[@]} )); then
		printf "%s\n" "true"
	else
		printf "%s\n" "false"
	fi
	return 0
}

clean_mod_loader() {
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

deploy_zip() {
	local zip_file="${1}"
	local display_name="${2}"
	local target="${3:-${darktide_found_dir}}"
	if [[ -z "${zip_file}" ]] || [[ ! -f "${zip_file}" ]]; then
		printf "%b\n" "    ${display_name} zip not found."
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

###

current_find_args=("-type" "d" "-name" "Warhammer 40,000 DARKTIDE")

printf "%b\n" "Locating Warhammer 40,000: Darktide please wait..."

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
		0) printf "%b\n" "Found Darktide in ${darktide_found_dir}."; break;;
		1) ;;
		2) ;;
		3) printf "%b\n" "Darktide not found here.";;
		*) ;;
	esac
done

if [[ -z "${darktide_found_dir}" ]]; then
	printf "%b\n" "All checks failed to locate Warhammer 40,000: Darktide."
	printf "%b\n" "Exiting."
	exit 1
fi

cd "${darktide_found_dir}" || { printf "%s\n" "Unable to change directory to '${darktide_found_dir}', exiting."; exit 1; }

### Determine zips directory ###
if [[ -n "${1}" ]]; then
	zips_dir="${1}"
else
	zips_dir="$(dirname "$(realpath "${0}")")"
fi

if [[ ! -d "${zips_dir}" ]]; then
	printf "%b\n" "Zips directory not found: ${zips_dir}"
	printf "%b\n" "Usage: ./deploy_darktide_mods.sh [zips_directory]"
	exit 1
fi

printf "%b\n" "Reading zips from: ${zips_dir}"

### Categorize zips ###
dml_zip=""
dmf_zip=""
amlao_zip=""
other_zips=()

while IFS= read -r -d '' zip_file; do
	filename="$(basename "${zip_file}")"
	case "${filename}" in
		Darktide\ Mod\ Loader-19-*) dml_zip="${zip_file}" ;;
		Darktide\ Mod\ Framework-8-*) dmf_zip="${zip_file}" ;;
		Auto\ Mod\ Loading\ and\ Ordering-246-*) amlao_zip="${zip_file}" ;;
		*) other_zips+=("${zip_file}") ;;
	esac
done < <(find "${zips_dir}" -maxdepth 1 -type "f" -name "*.zip" -print0 2>/dev/null)

### Deploy in order ###

# 1. Darktide Mod Loader — game root
printf "%b\n" "Step 1: Darktide Mod Loader"
if [[ -n "${dml_zip}" ]]; then
	clean_mod_loader
	deploy_zip "${dml_zip}" "Darktide Mod Loader" "${darktide_found_dir}"
else
	printf "%b\n" "  DML zip not found."
	printf "%b\n" "  Download from: https://www.nexusmods.com/warhammer40kdarktide/mods/19"
fi

# 2. Darktide Mod Framework — mods/
printf "%b\n" "Step 2: Darktide Mod Framework"
if [[ -n "${dmf_zip}" ]]; then
	deploy_zip "${dmf_zip}" "Darktide Mod Framework" "${darktide_found_dir}/mods"
else
	printf "%b\n" "  DMF zip not found."
	printf "%b\n" "  Download from: https://www.nexusmods.com/warhammer40kdarktide/mods/8"
fi

# 3. Auto Mod Loading and Ordering — mods/ (overwrites base/)
printf "%b\n" "Step 3: Auto Mod Loading and Ordering"
if [[ -n "${amlao_zip}" ]]; then
	deploy_zip "${amlao_zip}" "Auto Mod Loading and Ordering" "${darktide_found_dir}/mods"
	rm -f "${darktide_found_dir}/mods/mod_load_order.txt"
else
	printf "%b\n" "  AMLAO zip not found."
	printf "%b\n" "  Download from: https://www.nexusmods.com/warhammer40kdarktide/mods/246"
fi

# 4. All remaining mods — mods/
printf "%b\n" "Step 4: Remaining mods"
if (( ${#other_zips[*]} > 0 )); then
	for zip_file in "${other_zips[@]}"; do
		filename="$(basename "${zip_file}")"
		deploy_zip "${zip_file}" "${filename}" "${darktide_found_dir}/mods"
	done
else
	printf "%b\n" "  No additional mod zips found."
fi

### Validate DML ###
printf "%b\n" "Verifying mod loader deployment ..."
dml_deployed="$(check_for_mod_loader "${darktide_found_dir}")"
if [[ "${dml_deployed}" == "false" ]]; then
	printf "%s\n" "Mod loader verification failed. Required files are missing."
	printf "%s\n" "Exiting."
	exit 1
fi

### Run patcher ###
printf "%b\n" "Running patcher... Please see the patcher's popup message."
readarray -t "patchlog_array" < <(wine "./tools/dtkit-patch.exe" --toggle ".\bundle" 2>&1)
for line in "${patchlog_array[@]}"; do
	if [[ "${line,,}" =~ bundle_database.data ]]; then
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
