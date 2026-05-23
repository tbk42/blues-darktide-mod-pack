#!/bin/bash

# This script will rebuild the mod deployment for my personal darktide install and act as a prototype and
# model for a modpack install script.

usage() {
    clear
    echo -e "${blue}${this_pack_name}${reset}"
	echo -e "Rebuild & Redeploy Pack"
	echo -e "Usage:"
	echo -e "    --help              | Display this help"
	echo -e "    --none              | Perform no actions"
	echo -e "    --check             | Perform check only"
	echo -e "    --remove-only       | Perform remove only (no check)"
	echo -e "    --remove            | Perform check and remove"
	echo -e "    --deploy-only       | Perform deploy only (no check)"
	echo -e "    --deploy            | Perform check and deploy"
	echo -e "    --remove-and-deploy | Perform remove and deploy (no check)"
	echo -e "    --all               | Perform all tasks"
	echo -e "    --delay #           | Delay # seconds between steps"
	exit 0
}

error() {
	local message=""
	message="${1}"
	if [[ "${message}" != "" ]]; then
		echo -e "${red}Error:${reset} ${message}" >&2
	fi

	local do_exit=""
	do_exit="${2}"
	if [[ -n "${do_exit}" ]]; then
		echo -e "${red}Exiting${reset}" >&2
		exit 1;
	fi
}

# info() {
# 	local message=""
# 	message="${1}"
# 	if [[ "${message}" != "" ]]; then
# 		echo -e "${blue}Info:${reset} ${message}"
# 	fi
# }

function is_numeric() {
	local number=""
	if [[ -n "${1}" ]]; then number="${1}"; fi
	if [[ "${number}" == "" ]]; then echo "false"; return; fi
	local i=0
	for ((i=0; i<${#number}; i++)) do
		case "${number:i:1}" in
			"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"|"-"|"+"|"."|",") ;;
			*) echo "false"; return; ;;
		esac
	done
	echo "true"
	return
}

pause() {
	local storage=""
	local d=0
	local delay="0"
	local prompt=""
	local trailer=""
	local default_prompt=()
		  default_prompt+=("Press any key to continue")
		  default_prompt+=("Continuing without delay")
		  default_prompt+=("Press any key to continue or wait")
	local default_trailer=()
		  default_trailer+=("...")
		  default_trailer+=(".")
		  default_trailer+=("seconds...")
	local default_index=0

	for ((i=1; i-1<$#; i++)) do
		case "${*:i:1}" in
			"-1"|[0-9][0-9][0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9]|[0-9]) delay="${*:i:1}"; ;;
			*)	if [[ -z "${prompt}" ]]; then
					prompt="${*:i:1}"
				elif [[ -z "${trailer}" ]]; then
					trailer="${*:i:1}"
				fi
				;;
		esac
	done

	if (( delay > 0 )); then
		default_index=2
	elif (( delay == 0 )); then
		default_index=1
	elif (( delay == -1 )); then
		default_index=0
	else # (( delay < -1 )); then

		default_index=0
	fi

	if [[ -z "${prompt}" ]]; then prompt="${default_prompt[default_index]}"; fi
	if [[ "${prompt:-1}" != " " ]]; then prompt="${prompt} "; fi
	if [[ -z "${trailer}" ]]; then trailer="${default_trailer[default_index]}"; fi
	if [[ "${trailer:-1}" != " " ]]; then trailer="${trailer} "; fi

	echo -en "\e[38;5;229m${prompt}\e[0m"

	if (( delay > 0 )); then
		echo -en ""
		for ((d=delay; d>0; d=$(( d - 1 )) )) do
			echo -en "\e[38;5;87m${d} ${trailer}\e[0m"
			read -p "" -rs -n 1 -t 1 "storage"
			echo -en "$(repeat "$(( ${#d} + 1 + ${#trailer} ))" "\b \b")"

			case "${storage}" in
				"") ;;
				*) break; ;;
			esac
		done
	elif (( delay == 0 )); then
		echo -en "${trailer}\e[0m"
		read -rsn 1 -t 0
	elif (( delay < 0 )); then
		echo -en "${trailer}\e[0m"
		read -rsn 1
	fi
	echo -e ""
}

# -----------------------------------------------------------------
# REPEAT ... repreats, the pattern count number of times.
# usage: varname=$(repeat "40" "_|\_/|_");
# -----------------------------------------------------------------
function repeat() {
    local count=1;
    local pattern="";
    local filled="";

    if [[ -n "$1" ]]; then
    	  count="$1";
    	  if [[ -n "$2" ]]; then
    	  	  pattern="$2";
    	  fi
    fi

    for ((i=0; i<count; i++)) do
        filled+="$pattern";
    done
    echo "$filled"
}

function check_mod_working_dirs() {
	# Type: Critical / Exit
	critical=()
	critical+=("User Home directory" "${user_home}")
	critical+=("Games directory" "${user_home}/${games}")
	critical+=("Warhammer directory" "${user_home}/${games}/${WH40KDT}")
	critical+=("Scripts directory" "${user_home}/${games}/${WH40KDT}/${scripts}")

	for ((i=0; i<${#critical[*]}; i=$(( i + 2 )) )) do
		if [[ ! -d "${critical[i+1]}" ]]; then
			error "${critical[i]} not found. (${cyan}${critical[i+1]}${reset})" "exit"
		fi
	done

	warning=()
	warning+=("Import directory" "${import}")
	warning+=("Zips directory" "${zips}")
	warning+=("Mod Pack home directory" "${mod_pack_home}")
	warning+=("Mods directory in Mod Pack home directory" "${mod_pack_home}/mods")

	# Type: Warning / Self-fix
	for ((i=0; i<${#warning[*]}; i=$(( i + 2 )) )) do
		if [[ ! -d "${warning[i+1]}" ]]; then
			error "${warning[i]} not found. Making directory: ${cyan}${warning[i+1]}${reset}"
			mkdir -p "${warning[i+1]}"
			if [[ ! -d "${warning[i+1]}" ]]; then
				error "${warning[i]} still not found after trying to make it. (${warning[i+1]})" "exit"
			fi
		fi
	done

	# Type: Warning / Self-fix
	link_warning=()
	link_warning+=("Link to Steam directory" "${steam_link_name}" "${steam_common}/${steam_game_home}")

	# Type: Link Warning / Self-fix Link
	for ((i=0; i<${#link_warning[*]}; i=$(( i + 3 )) )) do
		if [[ ! -L "${link_warning[i+1]}" ]]; then
			error "${link_warning[i]} not found. Making link: ${cyan}${link_warning[i+1]}${reset}"
			ln -s "${link_warning[i+2]}" "${link_warning[i+1]}"
			if [[ ! -L "${link_warning[i+1]}" ]]; then
				error "${link_warning[i]} still not found after trying to make it. (ln -s \"${warning[i+2]}\" \"${warning[i+1]}\")" "exit"
			fi
		fi
	done

	echo -e "All checks successful"
}

remove_modpack() {
	# Pack Structure
	local remove_pack_structure=()
		  remove_pack_structure+=("README.md")
		  remove_pack_structure+=("toggle_darktide_mods.bat")
		  remove_pack_structure+=("toggle_darktide_mods.sh")
		  remove_pack_structure+=("binaries/mod_loader")
		  remove_pack_structure+=("bundle/9ba626afa44a3aa3.patch_999")
		  remove_pack_structure+=("mods")
		  remove_pack_structure+=("tools/dtkit-patch.exe")
		  remove_pack_structure+=("tools/README.md")
		  remove_pack_structure+=("tools")

	echo -e "Removing mods from game"
	local i=0
	for ((i=0; i<${#remove_pack_structure[*]}; i++)) do
		if [[ -f "${steam_link_name}/${remove_pack_structure[i]}" ]]; then
			echo -e "    Removing file: ${yellow}${remove_pack_structure[i]}${reset}"
			rm -rf "${steam_link_name:?}/${remove_pack_structure[i]}"
			if [[ -f "${steam_link_name}/${remove_pack_structure[i]}" ]]; then
				error "File remains after removal: \"${steam_link_name}/${remove_pack_structure[i]}\""
			fi
		elif [[ -d "${steam_link_name}/${remove_pack_structure[i]}" ]]; then
			echo -e "    Removing folder: ${yellow}${remove_pack_structure[i]}${reset}"
			rm -rf "${steam_link_name:?}/${remove_pack_structure[i]}"
			if [[ -d "${steam_link_name}/${remove_pack_structure[i]}" ]]; then
				error "Folder remains after removal: \"${steam_link_name}/${remove_pack_structure[i]}\""
			fi
		fi
	done
}

place_modpack() {
	local dirs=()
		  dirs+=("binaries")
		  dirs+=("bundle")
		  dirs+=("mods")
		  dirs+=("tools")

	cd "${user_home}/${games}/${WH40KDT}" || error "Unable to change to the user's ${user_home}/${games}/${WH40KDT} directory." "exit"

	echo -e "Making mod pack directories"
	local i=0
	for ((i=0; i<${#dirs[*]}; i++)) do
		if [[ ! -d "${steam_link_name}/${dirs[i]}" ]]; then
			echo -en "    Making directory: ${yellow}${dirs[i]}${reset} ... "
			# echo -e "mkdir \"${steam_link_name}/${dirs[i]}\""
			mkdir "${steam_link_name}/${dirs[i]}"
			if [[ -d "${steam_link_name}/${dirs[i]}" ]]; then
				echo -e "${green}Done.${reset}"
			else
				echo -e "${red}Failed!${reset}"
				error "Directory creation failed: ${dirs[i]}"
			fi
		fi
	done

	local deploy_pack_structure+=(         "/" "README.md")
		  deploy_pack_structure+=(         "/" "toggle_darktide_mods.bat")
		  deploy_pack_structure+=(         "/" "toggle_darktide_mods.sh")
		  deploy_pack_structure+=("/binaries/" "mod_loader")
		  deploy_pack_structure+=(  "/bundle/" "9ba626afa44a3aa3.patch_999")
		  deploy_pack_structure+=(   "/tools/" "dtkit-patch.exe")
		  deploy_pack_structure+=(   "/tools/" "README.md")

	echo -e "Deploying mod pack structure and core files to game"
	for ((i=0; i<${#deploy_pack_structure[*]}; i=$(( i + 2 )) )) do
		echo -en "    ${yellow}.${deploy_pack_structure[i]}${deploy_pack_structure[i+1]}${reset} ... "
		cp --preserve=all --recursive --force --target-directory="${steam_link_name}${deploy_pack_structure[i]}" "${this_pack_name}${deploy_pack_structure[i]}${deploy_pack_structure[i+1]}"
		if [[ -f "${steam_link_name}${deploy_pack_structure[i]}${deploy_pack_structure[i+1]}" ]]; then
			echo -e "${green}Done.${reset}"
		else
			echo -e "${red}Failed!${reset}"
			error "File not found after attempted copy: .${deploy_pack_structure[i]}${deploy_pack_structure[i+1]}"
		fi
	done

	echo -e "Deploying mods to game"
	cp --preserve=all --recursive --force --target-directory="${steam_link_name}" "${this_pack_name}/mods"

	readarray -t "version" < <(cat "version.txt")
	echo -en "    Mod pack version: ${yellow}${version[0]}-${version[1]}${reset} ... ${green}deployed.${reset}"
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

# Important Locations
# game_name="Warhammer 40,000: DARKTIDE"
steam_common="/home/eric/.local/share/Steam/steamapps/common"
steam_game_home="Warhammer 40,000 DARKTIDE"
steam_link_name="Link To ${steam_game_home}"

# General Location Directories
user_home="${HOME}"
games="Games"

# Modpack Directories
WH40KDT="Darktide"
this_pack_name="Blue's Darktide Mod Pack"
mod_pack_home="${this_pack_name}"

# Modpack Maintenance Directories
import="import"
scripts="scripts"
# working="working"
zips="source zips"
# previous="previous"

# command line parameters
check="true"
remove="true"
deploy="true"
delay=-1

if (( $# == 0 )); then
	usage
fi

for ((i=1; i-1<$#; i++)) do
	case "${*:i:1}" in
		"--help") usage; ;;
		"--none")						 check="false";	remove="false";	deploy="false";	;;
		"--check-mod-only"|"--check")	 				remove="false";	deploy="false";	;;
		"--remove-only")				 check="false";					deploy="false";	;;
		"--deploy-only")				 check="false";	remove="false";					;;
		"--check-and-remove"|"--remove") 								deploy="false";	;;
		"--check-and-deploy"|"--deploy") 				remove="false";					;;
		"--remove-and-deploy")			 check="false";									;;
		"--all")						 												;;
		"-1"|[0-9][0-9][0-9]|[0-9][0-9]|[0-9]) delay="${*:i:1}"; ;;
		"--delay"*)	param="${*:i:1}";
					if [[ "${param:7:1}" == "=" ]]; then
						if [[ "$(is_numeric "${param:8}")" == "true" ]]; then
							delay="${param:8}"
						fi
					elif (( i < $# )); then
						if [[ "$(is_numeric "${*:i+1:1}")" == "true" ]]; then
							delay="${*:i+1:1}"
							i=$(( i + 1 ));
						fi
					fi
					;;
		*) ;;
	esac
done

clear
echo -e "${blue}${this_pack_name}${reset}"

if [[ "${check}" == "true" ]]; then
	echo "$(check_mod_working_dirs)"
	if [[ "${check}" == "true" ]] && [[ "${remove}" == "true" || "${deploy}" == "true" ]]; then
		pause "${delay}"
	fi
fi

if [[ "${remove}" == "true" ]]; then
	remove_modpack
	if [[ "${remove}" == "true" ]] && [[ "${deploy}" == "true" ]]; then
		pause "${delay}"
	fi
fi

if [[ "${deploy}" == "true" ]]; then
	place_modpack
fi

echo ""
echo -e "Exiting Script."
exit
