# Orc face UV repair

Twenty infantry, ranger, cavalry and rogue GLBs contained two UV sets. The
repainted body used `Metric_Pixel_UV`, while inherited ears, brows and some
equipment retained `UVMap`. Merging parts filled missing names with a corner
UV in the primary channel. A previous corner cleanup then moved those UVs to
a uniform pale swatch. The correct original mapping survived in `TEXCOORD_1`.

`repair_orc_face_uv.py --apply` restores those inherited coordinates to the
material's primary channel, with backups in `art_source/orc_face_uv_repair/`.
It verifies the six green ear parts and both dark brows where present; four
helmeted forms omit the original brow meshes. Every byte outside the repaired
UV coordinates stays identical, including geometry, skin, animation and atlas.
Editable Blender sources already have correct active UVs and remain intact.

The clothing exporter now copies a part's rendered UV layer into the primary
channel when that part uses a different layer name. A disposable Blender export
checks that newly exported faces no longer require repair.

Validation: `orc_face_uv_repair_validation.json`,
`orc_face_uv_godot_validation.json` (20 models and 93 clips),
`orc_face_uv_export_validation.json`, and `test_unit_art_catalog.gd`.
Godot closeups in `previews/orc_face_uv/` show matching before/after views;
generate them with `review_orc_face_uv.gd -- before` or `-- after`.
