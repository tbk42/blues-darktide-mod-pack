#!/bin/bash

echo -e "Warhammer 40,000: Darktide"
echo -e ""

# move to multiplayer unless $1 is "solo"
direction="multiplayer"
if [[ "${1,,}" == "solo" ]]; then
	direction="solo"
fi
echo "direction: ${direction}"

# clean up old backup
if [[ -e "backup.tar.xz" ]]; then
	echo -e "remove old backup"
	rm -rf "backup.tar.xz"
fi

# backup current mods
if [[ -d "mods" ]]; then
	echo -e "backing up mods"
	tar -acf "backup.tar.xz" "mods"
	echo -e "removing old mods"
	rm -rf "mods"
fi

# deploy mods
if [[ -f "${direction}.tar.xz" ]]; then
	echo -e "exactracting mods"
	tar -xf "${direction}.tar.xz"
fi

exit 0;
