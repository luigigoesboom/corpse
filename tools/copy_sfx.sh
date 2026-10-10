#!/usr/bin/env bash
# Copies the chosen sounds from Ovani Sound's "Sound FX Starter Pack Vol. 1"
# into assets/audio/sfx/<game sound>.wav, where the Sfx autoload finds them.
#
# The pack's license allows the sounds in a game but not sharing the original
# files, and this repo is public, so the copies are NOT committed (.gitignore).
# Missing files are fine: Sfx then plays its generated placeholder instead.
#
# Usage, from the repo root, with the pack folder in the repo root (or pass its path):
#   tools/copy_sfx.sh ["path/to/Sound FX Starter Pack Vol. 1"]
cd "$(dirname "$0")/.." || exit 1
PACK="${1:-Sound FX Starter Pack Vol. 1}"
OUT="assets/audio/sfx"
mkdir -p "$OUT"

# game sound | file in the pack
MAP="
swing|Medieval/Weapon Whoosh.wav
hit|Medieval/Arrow Hit.wav
hurt|Hollywood/Deathpunch.wav
die|Horror/Pain Glitch.wav
enemy_die|Community Requests/Animal Pain.wav
pickup|Medieval/Equip.wav
eat|Magic/Necromantic Healing.wav
spit|Magic/Acid Attack.wav
dash|Motions and Impacts/Whoosh Medieval.wav
"

missing=0
while IFS='|' read -r name file; do
	[ -z "$name" ] && continue
	if [ -f "$PACK/$file" ]; then
		cp "$PACK/$file" "$OUT/$name.wav"
		echo "  $name  <-  $file"
	else
		echo "  missing: $PACK/$file" >&2
		missing=1
	fi
done <<< "$MAP"
exit $missing
