"""Week 39 art pass, step 2: replaces the Polygon2D placeholders in the prop
scenes with Sprite2D nodes showing the PNGs tools/art/make_props.gd made.

    python tools/art/swap_props.py

Reads tools/art/props_manifest.json. For every group of polygons it adds
"Art" (body), "ArtGlow" (unshaded) and "Cloth" (tinted in game) sprites
where the first polygon was, and removes the polygons. Run it once after
make_props.gd; a scene with no polygons left is skipped, so running it
again does nothing.
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
UNSHADED = "res://assets/materials/unshaded.tres"
NAMES = {"body": "Art", "glow": "ArtGlow", "cloth": "Cloth"}


def res_to_path(res):
    return os.path.join(ROOT, res.replace("res://", ""))


def split_blocks(text):
    """The header and every [section] as its own string, in order."""
    parts = re.split(r"(?m)^(?=\[)", text)
    return [p for p in parts if p]


def main():
    manifest = json.load(open(os.path.join(ROOT, "tools/art/props_manifest.json"), encoding="utf-8"))
    for scene, entries in manifest.items():
        path = res_to_path(scene)
        text = open(path, encoding="utf-8").read()
        if 'type="Polygon2D"' not in text:
            print("skip (already swapped)", scene)
            continue
        blocks = split_blocks(text)
        ext_ids = set(re.findall(r'id="([^"]+)"', text))
        new_ext = []

        def ext(kind, res_path):
            for b in blocks + new_ext:
                m = re.match(r'\[ext_resource type="[^"]+" path="%s" id="([^"]+)"\]' % re.escape(res_path), b)
                if m:
                    return m.group(1)
            n = 1
            while "art_%d" % n in ext_ids:
                n += 1
            new_id = "art_%d" % n
            ext_ids.add(new_id)
            new_ext.append('[ext_resource type="%s" path="%s" id="%s"]\n' % (kind, res_path, new_id))
            return new_id

        groups = {}
        for e in entries:
            groups.setdefault(e["parent"], {"sprites": [], "polygons": []})
            if "polygons" in e:
                groups[e["parent"]]["polygons"] = e["polygons"]
            else:
                groups[e["parent"]]["sprites"].append(e)

        out = []
        for block in blocks:
            m = re.match(r'\[node name="([^"]+)" type="Polygon2D"(?: parent="([^"]*)")?', block)
            if not m:
                out.append(block)
                continue
            name, parent = m.group(1), m.group(2) or ""
            group = groups.get(parent if parent else ".")
            if group is None or name not in group["polygons"]:
                out.append(block)
                continue
            if group["sprites"]:
                # The first polygon of the group: the sprites go here.
                for s in sorted(group["sprites"], key=lambda s: ["body", "cloth", "glow"].index(s["kind"])):
                    tex = ext("Texture2D", s["png"])
                    lines = ['[node name="%s" type="Sprite2D" parent="%s"]\n' % (NAMES[s["kind"]], parent if parent else ".")]
                    if s["kind"] == "glow":
                        lines.append('material = ExtResource("%s")\n' % ext("Material", UNSHADED))
                    lines.append('texture = ExtResource("%s")\n' % tex)
                    lines.append("centered = false\n")
                    lines.append("offset = Vector2(%d, %d)\n\n" % (s["offset"][0], s["offset"][1]))
                    out.append("".join(lines))
                group["sprites"] = []
        # New ext_resources go after the last existing one.
        last_ext = max(i for i, b in enumerate(out) if b.startswith("[ext_resource") or b.startswith("[gd_scene"))
        out = out[: last_ext + 1] + new_ext + out[last_ext + 1:]
        if not out[last_ext + len(new_ext)].endswith("\n\n") and new_ext:
            out[last_ext + len(new_ext)] += "\n"
        result = "".join(out)
        result = re.sub(r"\[gd_scene load_steps=\d+ ", "[gd_scene ", result)
        open(path, "w", encoding="utf-8", newline="\n").write(result)
        print("swapped", scene)


main()
