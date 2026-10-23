#!/bin/bash
# Rebuilds assets/puzzles/<level>.txt for Medium, Hard and Expert, PER_LEVEL seeds each, split
# over JOBS Godot processes. A rebuilt bank changes which puzzle a given seed shows at these
# levels, so do it only when the generator or analyzer changes what a level means.
#   GODOT=/path/to/godot tools/build_puzzle_bank.sh      (LEVELS="Expert" for one level)
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd)
godot=${GODOT:-godot}
per_level=${PER_LEVEL:-300}
jobs=${JOBS:-4}
work=$(mktemp -d)
mkdir -p "$repo/assets/puzzles"
for level in ${LEVELS:-Medium Hard Expert}; do
	slice=$(( (per_level + jobs - 1) / jobs ))
	for j in $(seq 0 $((jobs - 1))); do
		LEVEL=$level FROM=$((j * slice)) COUNT=$slice OUT="$work/${level}_$j.txt" \
			"$godot" --headless --path "$repo" -s tools/build_puzzle_bank.gd &
	done
	wait
	# Keep the seed order, drop repeats
	cat "$work/${level}"_*.txt | awk 'length($0) == 81 && !seen[$0]++' \
		> "$repo/assets/puzzles/$(echo "$level" | tr '[:upper:]' '[:lower:]').txt"
	echo "$level: $(wc -l < "$repo/assets/puzzles/$(echo "$level" | tr '[:upper:]' '[:lower:]').txt") puzzles"
done
rm -r "${work:?}"
