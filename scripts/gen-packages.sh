#!/bin/bash

root="$(dirname "$0")/.."

usage() {
	cat <<EOF
$(basename "$0") n[ormal]|a[rchtrack]|p[seudo] [package]...
EOF
}

if (( $# == 0 )) ; then
	usage
	exit 1
fi

if (( $# > 1 )) ; then
	packages=("${@:2}")
else
	if [[ "$1" = p ]] ; then
		packages=("$root"/pseudo-packages/archtrack*)
	else
		packages=("$root"/packages/*)
	fi
fi

for package in "${packages[@]}" ; do
	if [[ ! -d $package ]] ; then
		echo >&2 "'$package' not found."
		continue
	fi

	if [[ "$1" = p ]] ; then
		for pseudo in "${packages[@]}" ; do
			depends=$(grep -l "^groups.*\<$(basename "$pseudo")\>" "$root"/packages/*/info |
			          sed -e 's#/info$##' -e 's#^.*/##g')
			sed \
			-e "/%DEPENDS%/r "<(echo "$depends") \
			-e "/%DEPENDS%/d" \
			-e "s|%PKGNAME%|$(basename "$pseudo")|" \
			-e "s|%PKGDESC%|$(< "$pseudo/description")|" \
			pseudo-packages/PKGBUILD.in > $pseudo/PKGBUILD
		done
	else
		info="$package/info"
		# File existence checks
		if [[ ! -r $info ]] ; then
			echo >&2 "'$package' info file unreadable."
			continue
		fi

		if [[ ! -r $package/PKGBUILD.in ]] ; then
			echo >&2 "'$package' PKGBUILD.in file unreadable."
			continue
		fi

		if grep -q "^working=false" $info ; then
			echo >&2 "Warning: '$package' is not working."
		fi

		case "$1" in
			n|normal)
				outdir=normal
				pkgname=$(grep '^upstream_name=' "$info" | cut -d'=' -f2)
				groups="()"
				name_suffix=
				;;
			a|archtrack)
				outdir=archtrack
				pkgname=$(basename "$package")
				groups=$(grep '^groups=' "$info" | cut -d'=' -f2)

				# We add the '-archtrack' suffix to package names if they exist in the
				#  official repositories.
				if ! grep -q 'upstream_repo=aur' $info ; then
					name_suffix='-archtrack'
				else
					name_suffix=
				fi
				;;
			*)
				usage
				exit 1
				;;
		esac
		pkgdesc=$(grep '^description=' "$info" | cut -d'=' -f2)

		#rm -rf "$package/$outdir"
		[[ -d "$package/$outdir" ]] || mkdir "$package/$outdir"

		# Field substitutions
		sed -e "s|%PKGNAME%|$pkgname$name_suffix|" \
		-e "s|%PKGDESC%|$pkgdesc|" \
		-e "s|%GROUPS%|$groups|" \
		"$package/PKGBUILD.in" > "$package/$outdir/PKGBUILD"

		# Link source files
		# Sorry for parsing ls output like this. extglob wasn't working for some
		#  reason. I made sure no source files contained strange characters in their
		#  names.
		ls "$package" | grep -Ev '^(normal|archtrack|PKGBUILD.in|info)$' |
		while read src ; do
			ln -fs "../$src" "$package/$outdir/$(basename "$src")"
			#cp "$package/$src" "$package/$outdir"
		done
	fi
done