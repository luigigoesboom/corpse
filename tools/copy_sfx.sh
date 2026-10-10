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
matron_roar|Community Requests/Animal Pain.wav
matron_slam|Motions and Impacts/Impact Vox Hammer.wav
matron_die|Horror/Reality Rift.wav
matron_phase|Horror/It Laughs At You.wav
grate|Steampunk/Mechanism Open Close.wav
latch|Medieval/Metal Twang.wav
alarm|Medieval/Parry.wav
ichor|Medieval/Loot Gold.wav
bank|Magic/Holy Healing.wav
boon|UI & Menus/Achievement.wav
key|Medieval/Power Up.wav
heart_root|Magic/Magic Seal.wav
mural|UI & Menus/Map.wav
theft|Jingles & Stingers/Fail.wav
death_sting|Jingles & Stingers/Game Over.wav
rebirth|Magic/Resurrection.wav
years|Motions and Impacts/Transition Solemn.wav
discover|Jingles & Stingers/Area Discovered.wav
ui_hover|UI & Menus/Hover Over.wav
ui_select|UI & Menus/Click Bounce.wav
ui_open|UI & Menus/Inventory.wav
ui_close|UI & Menus/Quit Out.wav
ui_tab|UI & Menus/Click Bounce.wav
"
# Ambience loops (week 40): into assets/audio/ambience/<layer>.wav. Layers
# without a line here (the body, settlements, rot) are always our own.
AMB_OUT="assets/audio/ambience"
AMB_MAP="
amb_flesh|Horror/Gore And Larvae Loop.wav
amb_bile|Environment/Ocean Loop.wav
amb_bruise|Environment/Nightmare Loop.wav
amb_bone|Environment/Wind Loop.wav
amb_boss|Horror/Dissonance.wav
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
mkdir -p "$AMB_OUT"
while IFS='|' read -r name file; do
	[ -z "$name" ] && continue
	if [ -f "$PACK/$file" ]; then
		cp "$PACK/$file" "$AMB_OUT/$name.wav"
		echo "  $name  <-  $file"
	else
		echo "  missing: $PACK/$file" >&2
		missing=1
	fi
done <<< "$AMB_MAP"
exit $missing
