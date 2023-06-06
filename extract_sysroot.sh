#!/bin/bash

set -eu

declare -r processor="$(uname -p)"

if [ "${processor}" == 'x86' ]; then
	declare -r sysroot_directory='i586-unknown-haiku'
elif [ "${processor}" == 'x86_64' ]; then
	declare -r sysroot_directory='x86_64-unknown-haiku'
else
	echo "Unrecognized system processor: ${processor}" 1>&2
fi

declare -r tarball_filename="${sysroot_directory}.tar.xz"

[ -d "${sysroot_directory}/system" ] || mkdir --parent "${sysroot_directory}/system"
[ -d "${sysroot_directory}/system/develop" ] || mkdir "${sysroot_directory}/system/develop"
[ -d "${sysroot_directory}/boot" ] || mkdir "${sysroot_directory}/boot"

cp --recursive '/system/lib' "${sysroot_directory}/system"
cp --recursive '/system/develop/headers' "${sysroot_directory}/system/develop"
cp --recursive '/system/develop/lib' "${sysroot_directory}/system/develop"

pushd "${sysroot_directory}/boot" 1>/dev/null

ln --symbolic '../system' './system'

pushd  1>/dev/null

declare -ra directories=(
	"${sysroot_directory}/system/develop/lib"
	"${sysroot_directory}/system/lib"
)

# Remove unneeded directories
for directory in "${directories[@]}"; do
	while read name; do
		rm --recursive "${name}"
	done <<< "$(find ${directory}/* -prune -type 'd')"
done

# Strip debug symbols from shared libraries
while read name; do
	if [[ "$(file --brief --mime-type "${name}")" != 'application/x-sharedlib' ]]; then
		continue
	fi

	strip --discard-all "${name}"
done <<< "$(find "${sysroot_directory}" -type 'f' -name '*.so')"

# Remove libraries that are not part of the standard library
while read source; do
	IFS='.' read -ra parts <<< "${source}"
	
	declare part="${parts[0]}"
	declare name="$(basename "${part}")"
	
	declare exists='0'
	
	# Check whether there is a matching library in the develop directory
	ls "${sysroot_directory}/system/develop/lib/${name}."* 1>/dev/null 2>/dev/null || exists='1'
	
	if [ "${exists}" != 0 ]; then
		rm "${part}."* 2>/dev/null || true
	fi
done <<< "$(ls "${sysroot_directory}/system/lib/"*.so*)"

# Update permissions
while read name; do
	if [ -f "${name}" ]; then
		chmod 644 "${name}"
	elif [ -d "${name}" ]; then
		chmod 755 "${name}"
	fi
done <<< "$(find "${sysroot_directory}")"

tar --create --file=- "${sysroot_directory}" |  xz --threads=0 --compress -9 > "${tarball_filename}"
sha256sum "${tarball_filename}" > "${tarball_filename}.sha256"

exit 0
