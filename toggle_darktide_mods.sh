#!/bin/bash
pause() {
	read -rsn 1 -p "Press any key to continue"
	echo ""
}

countdown_from() {
	# default delay to 5 seconds
	local delay="${1:-5}"
	local i b back_str
	for ((i = delay; i > 0; i--)) do
		echo -en "${i}... "
		sleep 1
		back_str=""
		# +4 for "... " (e.g., "5... ")
		for ((b = 0; b < ${#i} + 4; b++)); do
			back_str+="\b"
		done
		echo -en "${back_str}"
	done
}

echo -e "Locating Warhammer 40,000: Darktide please wait..."

scan_paths=()
# first check in the user's $HOME directory for the game
scan_paths+=("$HOME/")
# next, check in the unified/SteamLibrary directory for the game
scan_paths+=("/unified/SteamLibrary/")
# lastly, check in the / (root directory) and below for the game
scan_paths+=("/")

darktide_found_dir="" # Variable to store the found directory path

for path_to_scan in "${scan_paths[@]}"; do
	current_find_args=("-type" "d" "-name" "Warhammer 40,000 DARKTIDE")

	if [[ "${path_to_scan}" == "/" ]]; then
		echo -e "    Initial checks failed to locate Darktide. Checking / (root directory), this may take a while..."
	elif [[ ! -d "${path_to_scan}" ]]; then
		# If a configured path (other than "/") doesn't exist or isn't a directory, skip it.
		# echo -e "    Configured scan path ${path_to_scan} not found or not a directory. Skipping."
		continue
	fi

	# Use -print -quit to stop find after the first match and output the path.
	# 2>/dev/null suppresses errors like "permission denied" during find.
	result=$(find "${path_to_scan}" "${current_find_args[@]}" -print -quit 2>/dev/null)

	if [[ -n "$result" ]]; then
		darktide_found_dir="$result"
		echo -e "Found Darktide in ${darktide_found_dir}."
		break # Exit the loop once found
	fi
done

# If we found Darktide, change directory...
if [[ -z "${darktide_found_dir}" ]]; then
	echo -e "All checks failed to locate Warhammer 40,000: Darktide."
	echo -e "Exiting."
	exit 1
else
	cd "${darktide_found_dir}" || { echo "Unable to change directory to '${darktide_found_dir}', exiting."; exit 1; }
fi

# successfully patched "bundle_database.data"
# successfully unpatched "bundle_database.data"
# "bundle_database.data" already patched
if [[ -d "./tools" ]] && [[ -f "./tools/dtkit-patch.exe" ]] && [[ -d "./bundle" ]]; then
	echo -e "Running patcher... Please see the patcher's popup message."
	readarray -t "patchlog_array" < <(wine "./tools/dtkit-patch.exe" --toggle ".\bundle" 2>&1)
	for line in "${patchlog_array[@]}"; do
		if [[ "${line,,}" =~ bundle_database.data ]]; then
			case "$(echo "${line,,}" | cut -d' ' -f2)" in
				"patched")   echo "Successfully patched the Darktide bundle database.";
							 countdown_from 5
							 ;;
				"unpatched") echo "Successfully unpatched the Darktide bundle database.";
							 countdown_from 5
							 ;;
				"already")   echo "The Darktide bundle database was already patched.";
							 countdown_from 5
							 ;;
				*) 			 echo "Error: Unusual message detected.";
							 echo "Message: ${line}"
							 pause
							 ;;
			esac
		fi
	done
else
	echo "I could not find the patcher or required directories, unable to run."
	echo  "I am in ${PWD}"
	if [[ -d "./tools" ]]; then
		echo -e "I could not find the tools directory"
	fi
	if [[ -f "./tools/dtkit-patch.exe" ]]; then
		echo -e "I could not find the patcher exe"
	fi
	if [[ -d "./bundle" ]]; then
		echo -e "I could not find the bundle directory"
	fi
fi

echo -e "Goodbye."
exit 0
