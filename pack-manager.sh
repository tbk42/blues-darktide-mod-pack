#!/bin/bash
####################################################################################################
# Blue's Mod Pack Scripts - Pack Manager
#
# Unified tool for maintaining the mod pack: import new mods, remove mods, clean up duplicates,
# rebuild the pack directory, and build the distributable zip.
#
# Run this from ~/Games/Darktide/ (or your Games/Darktide directory).
#
# Usage:
#   ./pack-manager.sh import              Import new mod zips from import/
#   ./pack-manager.sh --remove <name>     Remove mod by partial zip filename match
#   ./pack-manager.sh --cleanup           Remove duplicate zips, keep latest version
#   ./pack-manager.sh --rebuild           Rebuild Blue's Darktide Mod Pack/ from source zips/
#   ./pack-manager.sh --build-pack        Build the distributable zip with versioning
#   ./pack-manager.sh --update-mod-list   Generate mod_list.txt from source zips/
#
####################################################################################################

set -euo pipefail

### Config ###
game_name="Warhammer 40,000: DARKTIDE"
steam_library="/unified/SteamLibrary"
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

### Colors ###
reset="\e[0m"
blue="\e[38;5;21m"
cyan="\e[38;5;51m"
green="\e[38;5;34m"
red="\e[38;5;124m"
yellow="\e[38;5;226m"

### Helpers ###
error() {
	printf "%b\n" "${red}Error:${reset} ${1}" >&2
	if [[ -n "${2:-}" ]]; then exit 1; fi
}

info() {
	printf "%b\n" "${blue}Info:${reset} ${1}"
}

pause() {
	printf "%b" "Press any key to continue..."
	read -rsn 1
	printf "%s\n" ""
}

is_numeric() {
	local number="${1:-}"
	if [[ "${number}" == "" ]]; then printf "false"; return; fi
	for ((i=0; i<${#number}; i++)); do
		case "${number:i:1}" in
			"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9") ;;
			*) printf "false"; return; ;;
		esac
	done
	printf "true"
}

ensure_dirs() {
	mkdir -p "${import}" "${zips}" "${mod_pack_home}/mods" "${previous}"
}

ensure_steam_link() {
	if [[ ! -L "${steam_link_name}" ]]; then
		info "Creating symlink: ${steam_link_name} -> ${steam_common}/${steam_game_home}"
		ln -s "${steam_common}/${steam_game_home}" "${steam_link_name}"
	fi
}

clean_mod_pack_dirs() {
	# Clean DML core files and mods from the mod pack
	local items=()
	items+=("README.md")
	items+=("toggle_darktide_mods.bat")
	items+=("toggle_darktide_mods.sh")
	items+=("binaries/mod_loader")
	items+=("bundle/9ba626afa44a3aa3.patch_999")
	items+=("mods")
	items+=("tools/dtkit-patch.exe")
	items+=("tools/README.md")
	items+=("tools")

	for item in "${items[@]}"; do
		if [[ -f "${mod_pack_home}/${item}" ]]; then
			rm -f "${mod_pack_home}/${item}"
		elif [[ -d "${mod_pack_home}/${item}" ]]; then
			rm -rf "${mod_pack_home}/${item}"
		fi
	done
	mkdir -p "${mod_pack_home}/mods"
}

version_file="${mod_pack_home}/version.txt"

get_new_version() {
	local today last_date last_num new_date new_num
	today=$(date +%+4Y-%m-%d)

	if [[ ! -f "${version_file}" ]]; then
		printf "%s\n%s\n" "${today}" "0" > "${version_file}"
	fi

	readarray -t version < "${version_file}"
	last_date="${version[0]:-}"
	last_num="${version[1]:-0}"

	new_date="${today}"
	new_num="0"
	if [[ "${last_date}" == "${today}" ]]; then
		new_num=$(( last_num + 1 ))
	fi

	printf "%s\n%s\n" "${new_date}" "${new_num}" > "${version_file}"

	local alphabet=("" {a..z})
	local letter=""
	if (( new_num >= 0 && new_num <= 26 )); then
		letter="${alphabet[new_num]}"
	else
		letter="-${new_num}"
	fi

	printf "%s" "${new_date}${letter}"
}

find_zip_name_by_dir() {
	# Given a mod directory name, find the matching zip in source zips/
	local dirname="${1}"
	local found=""
	while IFS= read -r -d '' zip_file; do
		local match
		match=$(unzip -l "${zip_file}" 2>/dev/null | grep -E "^.*${dirname}/?" | head -1) || true
		if [[ -n "${match}" ]]; then
			found="${zip_file}"
			break
		fi
	done < <(find "./${zips}/" -maxdepth "1" -type "f" -name "*.zip" -print0 2>/dev/null)
	printf "%s" "${found}"
}

###############################################################################
# COMMAND: import
###############################################################################
cmd_import() {
	ensure_dirs
	ensure_steam_link

	readarray -t import_zips < <(find "./${import}/" -maxdepth "1" -type "f" -name "*.zip" 2>/dev/null | sort)
	if (( ${#import_zips[*]} == 0 )); then
		info "No zips found in ${import}/. Nothing to import."
		return
	fi

	if [[ -d "${working}" ]]; then
		rm -rf "${working}"
	fi
	mkdir -p "${working}"

	local added=()
	local updated=()

	for zip_path in "${import_zips[@]}"; do
		local filename
		filename="$(basename "${zip_path}")"
		printf "%b\n" "Processing: ${yellow}${filename}${reset}"

		# Extract to working
		unzip -q "${zip_path}" -d "${working}"

		# Move zip to source zips
		mv "${zip_path}" "./${zips}/"

		# Get mod directory name
		local mod_dir
		mod_dir=""
		readarray -t working_dirs < <(find "./${working}/" -mindepth 1 -maxdepth 1 -type "d" 2>/dev/null)
		if (( ${#working_dirs[*]} == 1 )); then
			mod_dir="$(basename "${working_dirs[0]}")"
		fi

		if [[ -z "${mod_dir}" ]]; then
			error "Could not detect mod directory name in ${working}" "exit"
		fi
		printf "%b\n" "  Mod directory: ${cyan}${mod_dir}${reset}"

		# Remove old version from mod pack
		local update_flag="false"
		if [[ -d "${mod_pack_home}/mods/${mod_dir}" ]]; then
			rm -rf "${mod_pack_home}/mods/${mod_dir}"
			update_flag="true"
			updated+=("${filename}")
		fi

		# Remove old version from game deployment
		if [[ -d "${steam_link_name}/mods/${mod_dir}" ]]; then
			rm -rf "${steam_link_name}/mods/${mod_dir}"
		fi

		# Copy to mod pack
		cp --preserve=all --recursive "${working}/${mod_dir}" "${mod_pack_home}/mods/"
		if [[ "${update_flag}" == "false" ]]; then
			added+=("${filename}")
		fi

		# Also deploy to game
		cp --preserve=all --recursive "${working}/${mod_dir}" "${steam_link_name}/mods/"

		# Clean working
		rm -rf "${working:?}/${mod_dir:?}"

		printf "%s\n" ""
	done

	rm -rf "${working}"

	# Print summary
	printf "%b\n" "Import complete."
	printf "%b\n" "  Added:   ${#added[*]}"
	printf "%b\n" "  Updated: ${#updated[*]}"

	# Auto-cleanup and rebuild after import
	cmd_cleanup
	cmd_update_mod_list
}

###############################################################################
# COMMAND: --remove <partial_name>
###############################################################################
cmd_remove() {
	local search="${1:-}"
	if [[ -z "${search}" ]]; then
		error "Usage: pack-manager.sh remove <partial_zip_name>"
		return
	fi

	ensure_dirs

	local found_zips=()
	while IFS= read -r -d '' zip_file; do
		local filename
		filename="$(basename "${zip_file}")"
		if [[ "${filename,,}" == *"${search,,}"* ]]; then
			found_zips+=("${zip_file}")
		fi
	done < <(find "./${zips}/" -maxdepth "1" -type "f" -name "*.zip" -print0 2>/dev/null)

	if (( ${#found_zips[*]} == 0 )); then
		error "No zips matching '${search}' found in ${zips}/"
		return
	fi

	for zip_path in "${found_zips[@]}"; do
		local filename
		filename="$(basename "${zip_path}")"
		printf "%b\n" "Removing: ${yellow}${filename}${reset}"

		# Find directory name inside zip
		local mod_dir
		mod_dir=$(unzip -l "${zip_path}" 2>/dev/null | grep -E "^.*/[^/]+/$" | head -1 | awk '{print $4}' | cut -d/ -f1) || true

		if [[ -n "${mod_dir}" ]]; then
			# Remove from mod pack
			if [[ -d "${mod_pack_home}/mods/${mod_dir}" ]]; then
				rm -rf "${mod_pack_home}/mods/${mod_dir}"
				printf "%b\n" "  Removed from pack: ${cyan}${mod_dir}${reset}"
			fi
			# Remove from game
			if [[ -d "${steam_link_name}/mods/${mod_dir}" ]]; then
				rm -rf "${steam_link_name}/mods/${mod_dir}"
				printf "%b\n" "  Removed from game: ${cyan}${mod_dir}${reset}"
			fi
		fi

		# Remove the zip
		rm -f "${zip_path}"
		printf "%b\n" "  Deleted zip."
	done

	cmd_update_mod_list
}

###############################################################################
# COMMAND: --cleanup
###############################################################################
cmd_cleanup() {
	if [[ ! -d "./${zips}" ]]; then
		info "Source zips directory not found. Nothing to clean."
		return
	fi

	printf "%b\n" "Cleaning duplicate zips in ${zips}/"

	readarray -t source_zips < <(find "./${zips}/" -maxdepth "1" -type "f" 2>/dev/null | sort)
	local removed_count=0

	for ((i=0; i<${#source_zips[*]}; i++)); do
		local filename nextfile
		filename="$(basename "${source_zips[i]}")"

		local base="${filename%.zip}"
		local temp="${base%-*}"
		local mod_name="$(printf "%s" "${temp}" | cut -d- -f1)"
		local mod_id="$(printf "%s" "${temp}" | cut -d- -f2)"

		if [[ "$(is_numeric "${mod_id}")" != "true" ]]; then
			continue
		fi

		nextfile=""
		if (( i + 1 < ${#source_zips[*]} )); then
			nextfile="$(basename "${source_zips[i+1]}")"
		fi

		if [[ -z "${nextfile}" ]]; then
			continue
		fi

		local next_base="${nextfile%.zip}"
		local next_temp="${next_base%-*}"
		local next_name="$(printf "%s" "${next_temp}" | cut -d- -f1)"
		local next_id="$(printf "%s" "${next_temp}" | cut -d- -f2)"

		if [[ "$(is_numeric "${next_id}")" == "true" ]] && \
		   [[ "${mod_name}" == "${next_name}" ]] && \
		   [[ "${mod_id}" == "${next_id}" ]]; then
			printf "%b\n" "  Removing older: ${yellow}${filename}${reset} (keeping ${cyan}${nextfile}${reset})"
			rm "${source_zips[i]}"
			((removed_count++))
		fi
	done

	printf "%b\n" "Cleanup complete. Removed ${removed_count} duplicate(s)."
}

###############################################################################
# COMMAND: --rebuild
###############################################################################
cmd_rebuild() {
	ensure_dirs
	ensure_steam_link

	# Clean existing pack
	clean_mod_pack_dirs

	# Find all zips in dependency order: DML -> DMF -> AMLAO -> rest
	local dml_zip=""
	local dmf_zip=""
	local amlao_zip=""
	local other_zips=()

	while IFS= read -r -d '' zip_file; do
		local filename
		filename="$(basename "${zip_file}")"
		case "${filename}" in
			Darktide\ Mod\ Loader-19-*) dml_zip="${zip_file}" ;;
			Darktide\ Mod\ Framework-8-*) dmf_zip="${zip_file}" ;;
			Auto\ Mod\ Loading\ and\ Ordering-246-*) amlao_zip="${zip_file}" ;;
			*) other_zips+=("${zip_file}") ;;
		esac
	done < <(find "./${zips}/" -maxdepth "1" -type "f" -name "*.zip" -print0 2>/dev/null)

	# Deploy DML to pack root
	if [[ -n "${dml_zip}" ]]; then
		printf "%b\n" "Deploying Darktide Mod Loader ..."
		unzip -qo "${dml_zip}" -d "${mod_pack_home}"
	fi

	# Deploy DMF to mods/
	if [[ -n "${dmf_zip}" ]]; then
		printf "%b\n" "Deploying Darktide Mod Framework ..."
		unzip -qo "${dmf_zip}" -d "${mod_pack_home}/mods"
	fi

	# Deploy AMLAO to mods/ (overwrites base/)
	if [[ -n "${amlao_zip}" ]]; then
		printf "%b\n" "Deploying Auto Mod Loading and Ordering ..."
		unzip -qo "${amlao_zip}" -d "${mod_pack_home}/mods"
	fi

	# Deploy rest to mods/
	for zip_file in "${other_zips[@]}"; do
		local filename
		filename="$(basename "${zip_file}")"
		printf "%b\n" "Deploying ${filename} ..."
		unzip -qo "${zip_file}" -d "${mod_pack_home}/mods"
	done

	printf "%b\n" "Rebuild complete."
}

###############################################################################
# COMMAND: --build-pack
###############################################################################
cmd_build_pack() {
	ensure_dirs

	local version
	version="$(get_new_version)"
	local pack_zip="${this_pack_name} ${version}.zip"
	local pack_sha="${pack_zip}.sha256"

	printf "%b\n" "Building pack: ${cyan}${pack_zip}${reset}"

	# Move old packs to previous
	while IFS= read -r -d '' old_zip; do
		local filename
		filename="$(basename "${old_zip}")"
		printf "%b\n" "  Archiving old pack: ${yellow}${filename}${reset}"
		mv "${old_zip}" "${previous}/"
	done < <(find "./" -maxdepth "1" -type "f" -name "${this_pack_name}*.zip" -print0 2>/dev/null)

	while IFS= read -r -d '' old_sha; do
		mv "${old_sha}" "${previous}/"
	done < <(find "./" -maxdepth "1" -type "f" -name "${this_pack_name}*.sha256" -print0 2>/dev/null)

	# Zip the pack
	if [[ -d "${mod_pack_home}" ]]; then
		[[ -f "${pack_zip}" ]] && rm -f "${pack_zip}"
		zip -rq "${pack_zip}" "${mod_pack_home}"
		if [[ -f "${pack_zip}" ]]; then
			sha256sum "${pack_zip}" > "${pack_sha}"
			printf "%b\n" "  Created: ${green}${pack_zip}${reset}"
			printf "%b\n" "  SHA256:  ${cyan}$(cut -d' ' -f1 < "${pack_sha}")${reset}"
		fi
	fi

	# Changelog output
	printf "%b\n" ""
	printf "%b\n" "Version: ${version}"
	printf "%b\n" "Pack ready for distribution."
}

###############################################################################
# COMMAND: --update-mod-list
###############################################################################
cmd_update_mod_list() {
	local list_file="mod_list.txt"

	printf "%b\n" "Generating ${list_file} ..."

	> "${list_file}"

	local dml_entry=""
	local dmf_entry=""
	local amlao_entry=""
	local other_names=()
	local other_urls=()

	while IFS= read -r -d '' zip_file; do
		local filename
		filename="$(basename "${zip_file}")"

		local base="${filename%.zip}"
		local mod_id=""
		local name_parts=()
		local found_id=false

		IFS='-' read -ra parts <<< "${base}"
		for part in "${parts[@]}"; do
			if [[ "${found_id}" == false ]] && [[ "$(is_numeric "${part}")" == "true" ]]; then
				mod_id="${part}"
				found_id=true
			elif [[ "${found_id}" == false ]]; then
				name_parts+=("${part}")
			fi
		done

		local name=""
		if (( ${#name_parts[*]} > 0 )); then
			name="${name_parts[0]}"
			for ((i=1; i<${#name_parts[*]}; i++)); do
				name+="-${name_parts[i]}"
			done
		fi

		local url=""
		if [[ "$(is_numeric "${mod_id}")" == "true" ]]; then
			url="https://www.nexusmods.com/warhammer40kdarktide/mods/${mod_id}"
		fi

		case "${name}" in
			"Darktide Mod Loader")               dml_entry="${name}|${url}" ;;
			"Darktide Mod Framework")            dmf_entry="${name}|${url}" ;;
			"Auto Mod Loading and Ordering")     amlao_entry="${name}|${url}" ;;
			*)
				other_names+=("${name}")
				other_urls+=("${url}")
				;;
		esac
	done < <(find "./${zips}/" -maxdepth "1" -type "f" -name "*.zip" -print0 2>/dev/null)

	# Sort others by name (insertion sort keeps other_names/other_urls aligned)
	for ((i=1; i<${#other_names[*]}; i++)); do
		local key_name="${other_names[i]}"
		local key_url="${other_urls[i]}"
		local j=$(( i - 1 ))
		while (( j >= 0 )) && [[ "${other_names[j]}" > "${key_name}" ]]; do
			other_names[j+1]="${other_names[j]}"
			other_urls[j+1]="${other_urls[j]}"
			j=$(( j - 1 ))
		done
		other_names[j+1]="${key_name}"
		other_urls[j+1]="${key_url}"
	done

	# Write in dependency order: DML, DMF, AMLAO, then alphabetical rest
	for entry in "${dml_entry}" "${dmf_entry}" "${amlao_entry}"; do
		if [[ -n "${entry}" ]]; then
			local ename eurl
			ename="${entry%%|*}"
			eurl="${entry#*|}"
			printf "%s\n" "${ename}" >> "${list_file}"
			printf "%s\n" "${eurl}" >> "${list_file}"
			printf "%s\n" "" >> "${list_file}"
		fi
	done

	for ((i=0; i<${#other_names[*]}; i++)); do
		printf "%s\n" "${other_names[i]}" >> "${list_file}"
		printf "%s\n" "${other_urls[i]}" >> "${list_file}"
		printf "%s\n" "" >> "${list_file}"
	done

	printf "%b\n" "Wrote ${list_file}"
}

###############################################################################
# Main
###############################################################################
usage() {
	printf "%b\n" "Usage:"
	printf "%b\n" "  $(basename "${0}") import              Import new mod zips from import/"
	printf "%b\n" "  $(basename "${0}") remove <name>       Remove mod by partial zip name"
	printf "%b\n" "  $(basename "${0}") cleanup             Remove duplicate zips"
	printf "%b\n" "  $(basename "${0}") rebuild             Rebuild mod pack from source zips"
	printf "%b\n" "  $(basename "${0}") build-pack          Build distributable zip"
	printf "%b\n" "  $(basename "${0}") update-mod-list     Generate mod_list.txt"
}

# clear
printf "%s\n" ""
printf "%b\n" "${blue}${this_pack_name} - Pack Manager${reset}"
printf "%s\n" ""

if (( $# == 0 )); then
	usage
	exit 0
fi

# Verify we're in the right directory
if [[ ! -d "${import}" ]] && [[ ! -d "${zips}" ]] && [[ ! -d "${mod_pack_home}" ]]; then
	if [[ -d "${HOME}/${games}" ]]; then
		cd "${HOME}/${games}"
		printf "%b\n" "Changed to working directory: ${cyan}${HOME}/${games}${reset}"
	else
		error "Please run this script from within your ${HOME}/${games} directory."
		exit 1
	fi
fi

case "${1}" in
	import)           cmd_import ;;
	remove)           shift; cmd_remove "${@}" ;;
	cleanup)          cmd_cleanup ;;
	rebuild)          cmd_rebuild ;;
	build-pack)       cmd_build_pack ;;
	update-mod-list)  cmd_update_mod_list ;;
	help|-h)          usage; exit 0 ;;
	*)                error "Unknown command: ${1}"; exit 1 ;;
esac

printf "%b\n" "${green}Done.${reset}"
