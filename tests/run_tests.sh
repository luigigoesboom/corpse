#!/usr/bin/env bash
# Runs the tests. From the project folder, in Git Bash:
#   tests/run_tests.sh            all tests/test_*.gd, headless
#   tests/run_tests.sh --soak     also the 10 game-minute soak test (a minute or two)
#   tests/run_tests.sh --render   also the 60 s frame time test (opens a window)
# Finds Godot via $GODOT, then `godot` on PATH, then ~/Desktop/Godot_v4*.exe.
cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-$(command -v godot || ls ~/Desktop/Godot_v4*_win64.exe 2>/dev/null | head -1)}"
if [ -z "$GODOT" ]; then
	echo "Godot not found. Set GODOT to the Godot executable." >&2
	exit 1
fi

failed=0
run() {
	local name="$1"; shift
	echo "== $name"
	local out
	out=$("$GODOT" --path . "$@" 2>&1)
	local code=$?
	echo "$out" | grep -E "^(PASS|FAIL) |failed$|^(memory|nodes|orphan|frames) "
	# Script errors fail a test even if every check passed.
	if echo "$out" | grep -q "SCRIPT ERROR"; then
		echo "$out" | grep -A3 "SCRIPT ERROR"
		code=1
	fi
	[ $code -ne 0 ] && failed=1
}

"$GODOT" --headless --path . --import > /dev/null 2>&1
for test in tests/test_*.gd; do
	[ "$test" = tests/test_case.gd ] && continue  # The shared base, not a test.
	run "$(basename "$test")" --headless --script "res://$test"
done
[[ " $* " == *" --soak "* ]] && run soak.gd --headless --fixed-fps 60 --script res://tests/soak.gd
[[ " $* " == *" --render "* ]] && run perf_render.gd --windowed --resolution 1280x720 --script res://tests/perf_render.gd

if [ $failed -ne 0 ]; then
	echo "SOME TESTS FAILED"
	exit 1
fi
echo "ALL TESTS PASSED"
