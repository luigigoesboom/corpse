extends Node
## Serializes WorldData to user://saves/ and back. Owns save versioning and migrations.
##
## Implemented in roadmap week 3. Rules (see docs/ARCHITECTURE.md, "Saving"):
## store_var without full_objects, version header, temp file then rename.
