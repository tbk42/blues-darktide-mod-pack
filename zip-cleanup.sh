#!/bin/bash
function is_numeric() {
	local number=""
	if [[ -n "${1}" ]]; then number="${1}"; fi
	if [[ "${number}" == "" ]]; then printf "%s\n" "false"; return; fi
	local i=0
	for ((i=0; i<${#number}; i++)) do
		case "${number:i:1}" in
			"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"|"-"|"+"|"."|",") ;;
			*) printf "%s\n" "false"; return; ;;
		esac
	done
	printf "%s\n" "true"
	return
}

if [[ -d "./source zips" ]]; then
	printf "%b\n" "Reading \e[38;2;0;128;255mSource Zips\e[0m directory"
	readarray -t "source_zips" < <(find "./source zips/" -maxdepth "1" -type "f" 2>/dev/null | sort | cut -d/ -f3-)
	for ((i=0; i<${#source_zips[*]}; i++)) do
		filename="${source_zips[i]}"
		printf "%b\n" "Processing \e[38;2;255;128;128m${filename}\e[0m"

		base="${filename%.zip}"
		temp="${base%-*}"
		mod_name="$(printf "%s\n" "${temp}" | cut -d- -f1)"
		mod_id="$(printf "%s\n" "${temp}" | cut -d- -f2)"
		# mod_ver="$(printf "%s\n" "${temp}" | cut -d- -f3-)"

		printf "%b\n" "Detected as \e[38;2;204;204;0m${mod_name} (${mod_id})\e[0m"

		if [[ "$(is_numeric "${mod_id}")" == "true" ]]; then
			nextfile=""
			if (( i < ${#source_zips[*]} )); then
				nextfile=${source_zips[i+1]}
			fi
			if [[ -n "${nextfile}" ]]; then
					base="${nextfile%.zip}"
			temp="${base%-*}"
				next_name="$(printf "%s\n" "${temp}" | cut -d- -f1)"
				next_id="$(printf "%s\n" "${temp}" | cut -d- -f2)"
				# next_ver="$(printf "%s\n" "${temp}" | cut -d- -f3-)"

				if [[ "$(is_numeric "${next_id}")" == "true" ]]; then
					if [[ "${mod_name}" == "${next_name}" ]] && [[ "${mod_id}" == "${next_id}" ]]; then
						printf "%b\n" "Removing \e[38;5;124m${filename}\e[0m in favor of \e[38;5;40m${nextfile}\e[0m"
						rm "source zips/${filename}"
					fi
				fi
			fi
		fi
	done
fi