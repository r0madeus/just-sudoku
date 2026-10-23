#!/bin/bash
# Runs every tests/test_*.gd, four at a time, each in its own empty user:// folder, so no suite
# leans on data another one (or an earlier run) left behind. Prints the failing suites and exits 1
# if there are any. Logs go to $LOG_DIR (default: a temporary folder).
#   GODOT=/path/to/godot tools/run_tests.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
godot=${GODOT:-godot}
logs=${LOG_DIR:-$(mktemp -d)}
jobs=${JOBS:-4}
mkdir -p "$logs"
run_one() {
	local t=$1 name; name=$(basename "$t" .gd)
	local user; user=$(mktemp -d)
	local out rc
	out=$(cd "$repo" && XDG_DATA_HOME=$user timeout 600 xvfb-run -a -s "-screen 0 1100x2400x24" \
		"$godot" --rendering-driver opengl3 --resolution 540x960 --path . -s "$t" 2>&1); rc=$?
	rm -rf "$user"
	echo "$out" > "$logs/$name.log"
	if [ $rc -ne 0 ] || grep -q "✗ FAIL\|-> FAILED\|SCRIPT ERROR" <<< "$out"; then echo "FAIL $name"; fi
}
export -f run_one; export repo godot logs
failed=$(ls "$repo"/tests/test_*.gd | xargs -P"$jobs" -I{} bash -c 'run_one {}' | sort)
total=$(ls "$repo"/tests/test_*.gd | wc -l)
if [ -n "$failed" ]; then
	echo "$failed"; echo "$(grep -c . <<< "$failed") of $total suites failed (logs: $logs)"; exit 1
fi
echo "All $total suites passed (logs: $logs)"
