#!/bin/bash
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

if [[ -d "./source zips" ]]; then
	readarray -t "source_zips" < <(find "./source zips/" -maxdepth "1" -type "f" 2>/dev/null | sort | cut -d/ -f3-)
	for ((i=0; i<${#source_zips[*]}; i++)) do
		filename="${source_zips[i]}"

		temp="$(echo "${filename}" | rev | cut -b15- | rev)"
		mod_name="$(echo "${temp}" | cut -d- -f1)"
		mod_id="$(echo "${temp}" | cut -d- -f2)"
		# mod_ver="$(echo "${temp}" | cut -d- -f3-)"

		if [[ "$(is_numeric "${mod_id}")" == "true" ]]; then
			nextfile=""
			if (( i < ${#source_zips[*]} )); then
				nextfile=${source_zips[i+1]}
			fi
			if [[ -n "${nextfile}" ]]; then
				temp="$(echo "${nextfile}" | rev | cut -b15- | rev)"
				next_name="$(echo "${temp}" | cut -d- -f1)"
				next_id="$(echo "${temp}" | cut -d- -f2)"
				# next_ver="$(echo "${temp}" | cut -d- -f3-)"

				if [[ "$(is_numeric "${next_id}")" == "true" ]]; then
					if [[ "${mod_name}" == "${next_name}" ]] && [[ "${mod_id}" == "${next_id}" ]]; then
						echo -e "Removing \e[38;5;124m${filename}\e[0m in favor of \e[38;5;40m${nextfile}\e[0m"
						rm "source zips/${filename}"
					fi
				fi
			fi
		fi
	done
fi