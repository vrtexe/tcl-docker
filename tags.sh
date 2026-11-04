#!/usr/bin/env bash
# Print the tags of one image: ./tags.sh 8.6.18 trixie [dev]
# Minor (8.6), major (8) and latest aliases go to the newest matching version.
set -euo pipefail
cd "$(dirname "$0")"
version=$1 variant=$2 target=${3:-runtime}

jq -r --arg v "$version" --arg var "$variant" --arg target "$target" '
	def vkey: split(".") | map(tonumber);
	(.versions | keys | sort_by(vkey)) as $all
	| ($v | split(".")) as $p
	| ($p[0:2] | join(".")) as $minor
	| $p[0] as $major
	| def newest(f): [$all[] | select(f)] | last == $v;
	  ([$v]
	   + (if newest(split(".")[0:2] | join(".") == $minor) then [$minor] else [] end)
	   + (if newest(split(".")[0] == $major) then [$major] else [] end)) as $names
	| (if $var == "trixie" then ["", "-trixie"]
	   elif $var == "slim-trixie" then ["-slim", "-slim-trixie"]
	   elif ($var | startswith("alpine")) then ["-alpine", "-\($var)"]
	   else ["-\($var)"] end) as $suffixes
	| [$names[] as $n | $suffixes[] as $s | $n + $s]
	  + (if newest(true) then [$suffixes[] | if . == "" then "latest" else ltrimstr("-") end] else [] end)
	| if $target == "dev" then map(. + "-dev") else . end
	| join(" ")
' versions.json
