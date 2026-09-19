"""
CharacterBuilder Blocky: Minecraft/Hytale box-language body
(geometry/body_blocky.py + geometry/equipment_blocky.py). Same contract
as every other builder -- (StyleDefinition, preset dict, seed) in, one
joined rigid-vertex-grouped mesh out -- and the same skeleton/rig/
animation/export/preview pipeline, since bone names and joint positions
are unchanged. V1/V2/V3 stay independently runnable.
"""

import bpy

from character.params import compute_measurements, apply_seed_variation
from geometry import body_blocky as body
from geometry import equipment_blocky as gear
from geometry import primitives as prim
from style.palette import MaterialLibrary


def build_character_blocky(name: str, style, preset: dict, seed: int, excluded_parts=None):
    palette_cfg = preset.get("palette", {})
    civilization = palette_cfg.get("civilization", "human_default")
    # Per-character skin/hair override for a non-human species (goblin,
    # orc, ...) -- see MaterialLibrary's own comment. list -> tuple since
    # JSON has no tuple type.
    skin_color = tuple(palette_cfg["skin_color"]) if "skin_color" in palette_cfg else None
    hair_color = tuple(palette_cfg["hair_color"]) if "hair_color" in palette_cfg else None
    eye_color = tuple(palette_cfg["eye_color"]) if "eye_color" in palette_cfg else None
    mat_lib = MaterialLibrary(civilization, skin_color=skin_color, hair_color=hair_color, eye_color=eye_color)

    measurements = compute_measurements(style)
    apply_seed_variation(measurements, seed)

    equipment_cfg = preset.get("equipment", {})
    wears_helmet = equipment_cfg.get("helmet", True)
    # armor defaults True -- every character built before this flag existed
    # (the guard) wore the metal cuirass/pauldrons unconditionally, this
    # keeps that. A civilian (Colonizador: attack 0.0, no combat role) sets
    # it false in their own preset instead. Every cloth surface (torso,
    # skirt, sleeves) ties its team-color to this same flag: team-colored
    # cloth head to toe with nothing else breaking it up read as a
    # solid-color hoodie on an unarmored civilian, not clothing. Belt is
    # the one exception -- everybody wears one (see build_belt_parts).
    wears_armor = equipment_cfg.get("armor", True)
    # A different SPECIES (goblin/orc) whose reference shows bare hide
    # instead of a shirt -- separate from `armor`/`wears_armor` (a
    # civilian human still wears cloth, just undyed; a goblin wears
    # nothing at all over its own skin). See body_blocky.build_torso_
    # parts/build_arm_parts/build_leg_parts `bare`/sleeve_material="skin".
    bare_skin = equipment_cfg.get("bare_skin", False)
    # A unique (non-tiled) muscle-definition overlay on chest/bicep/
    # forearm/thigh/calf front faces -- see body_blocky.build_torso_
    # parts' own docstring for why this can't be part of the tiled hide
    # texture. Only meaningful together with bare_skin.
    muscles = equipment_cfg.get("muscles", False)
    # Mottled hide texture vs. a flat skin color for a bare-skinned
    # species (only meaningful with bare_skin) -- the whole texturing
    # pass got tried on the Goblin and then asked reverted wholesale
    # ("tire todas as texturas ai, deixe ele com texturas solidas, ficou
    # horrivel"), so this needs to be a single flag that flattens EVERY
    # bare surface (torso/arms/legs/feet/head) and the debris pieces at
    # once, not something to toggle per body part.
    textured = equipment_cfg.get("textured_skin", True)
    # Ribcage/bone-segment overlay instead of muscle definition (a
    # Skeleton has bone structure, not muscle) -- see body_blocky.py's
    # build_torso_parts/build_arm_parts/build_leg_parts docstrings.
    # Independent of `textured`: unlike muscles (which sits on top of the
    # tiled hide base and makes no sense without it), this replaces a
    # FLAT bare surface that would otherwise be a plain colored box.
    bone_marks = equipment_cfg.get("bone_marks", False)

    all_parts = []
    all_parts += body.build_torso_parts(measurements, style, mat_lib, faction=wears_armor, bare=bare_skin,
                                         pelvis_material=equipment_cfg.get("pelvis_material"), muscles=muscles,
                                         textured=textured, bone_marks=bone_marks)
    all_parts += body.build_head_parts(measurements, style, mat_lib, wears_helmet=wears_helmet,
                                        beard=equipment_cfg.get("beard", True),
                                        teeth=equipment_cfg.get("fangs", False),
                                        hair=equipment_cfg.get("hair", True),
                                        textured_skin=bare_skin and textured,
                                        eye_style=equipment_cfg.get("eye_style", "round"),
                                        nose=equipment_cfg.get("nose", False))
    # "cloth" sleeves for a non-combat character -- bare mail with no
    # cuirass over it (armor: false) read as a costume mistake, not a
    # civilian. See body_blocky.build_arm_parts/build_leg_parts.
    if bare_skin:
        sleeve_material = "skin"
    else:
        sleeve_material = "chainmail" if wears_armor else "cloth"
    all_parts += body.build_arm_parts(measurements, style, mat_lib, sleeve_material=sleeve_material, muscles=muscles,
                                       textured=textured, bone_marks=bone_marks)
    all_parts += body.build_leg_parts(measurements, style, mat_lib, sleeve_material=sleeve_material,
                                       foot_material=equipment_cfg.get("foot_material", "leather"), muscles=muscles,
                                       textured=textured, bone_marks=bone_marks)
    # Real 3D debris (torn cloth remnant / leaf clusters), not a texture
    # -- see equipment_blocky.build_debris_parts' own docstring.
    if equipment_cfg.get("torn_cloth") or equipment_cfg.get("leaves"):
        all_parts += gear.build_debris_parts(measurements, style, mat_lib,
                                              torn_cloth=equipment_cfg.get("torn_cloth", False),
                                              leaves=equipment_cfg.get("leaves", False),
                                              textured=textured)
    # Not tied to `armor` -- a belted robe reads as a soldier's uniform on
    # a civilian ("parecendo um soldado do exercito nao um colono", user),
    # so the Colonizador's own preset turns it off explicitly instead of
    # inheriting "false" from armor the way cloth color/sleeves do.
    if equipment_cfg.get("belt", True):
        all_parts += gear.build_belt_parts(measurements, style, mat_lib)
    if wears_armor:
        all_parts += gear.build_armor_parts(measurements, style, mat_lib)
    if equipment_cfg.get("skirt", True):
        all_parts += gear.build_skirt_parts(measurements, style, mat_lib, faction=wears_armor,
                                             material=equipment_cfg.get("skirt_material", "cloth"))
    if equipment_cfg.get("headband"):
        all_parts += gear.build_headband_parts(measurements, style, mat_lib)
    if equipment_cfg.get("sash"):
        all_parts += gear.build_sash_parts(measurements, style, mat_lib,
                                            material=equipment_cfg.get("sash_material", "cloth"),
                                            side=equipment_cfg.get("sash_side", 1))

    if wears_helmet:
        all_parts += gear.build_helmet_parts(measurements, style, mat_lib,
                                              material=equipment_cfg.get("helmet_material", "metal"))
    if equipment_cfg.get("gloves", True):
        all_parts += gear.build_gloves_parts(measurements, style, mat_lib)
    if equipment_cfg.get("shield"):
        all_parts += gear.build_shield_parts(measurements, style, mat_lib)
    if equipment_cfg.get("pack"):
        all_parts += gear.build_pack_parts(measurements, style, mat_lib)
    weapon = equipment_cfg.get("weapon")
    if weapon == "sword":
        all_parts += gear.build_sword_parts(measurements, style, mat_lib)
    elif weapon in ("halberd", "poleaxe"):
        all_parts += gear.build_halberd_parts(measurements, style, mat_lib)
    elif weapon == "staff":
        all_parts += gear.build_staff_parts(measurements, style, mat_lib)
    elif weapon == "club":
        all_parts += gear.build_club_parts(measurements, style, mat_lib)
    elif weapon == "troll_club":
        all_parts += gear.build_troll_club_parts(measurements, style, mat_lib)

    # The shared skeleton builder (rig/skeleton.py) places shoulder/elbow/
    # wrist/hip/knee/ankle bones from measurements.shoulder_x/hip_x (plus
    # a small arm_out_x/leg_out_x lean) -- the ORGANIC style's numbers.
    # body_blocky.py's mesh never used those for X placement (arm_x()/
    # leg_x() above use the blocky torso's own width instead, and no
    # lean), so the bones were landing wherever the organic ratios put
    # them: outside the actual blocky limbs. Compute the override from
    # the STILL-ORIGINAL shoulder_x (arm_x()/leg_x() derive chest/torso
    # width from it) before overwriting it, so this doesn't feed back
    # into the mesh functions above, which already ran.
    measurements.shoulder_x = body.arm_x(measurements, 1)
    measurements.hip_x = body.leg_x(measurements, 1)
    measurements.arm_out_x = 0.0
    measurements.leg_out_x = 0.0

    # Editor-only "delete this part" support (rig/bones.py names, e.g.
    # "Neck", "UpperArm.L") -- ANYTHING tagged for a removed bone goes,
    # body part or equipment alike (a removed arm's own glove/sleeve would
    # otherwise float on nothing). The skeleton itself is untouched: it
    # always gets every bone regardless (rig/skeleton.py doesn't look at
    # this), a removed part just has no mesh riding on its bone anymore.
    if excluded_parts:
        kept_parts = []
        for obj, bone_name in all_parts:
            if bone_name in excluded_parts:
                bpy.data.objects.remove(obj, do_unlink=True)
            else:
                kept_parts.append((obj, bone_name))
        all_parts = kept_parts
        if not all_parts:
            raise RuntimeError("Todas as partes foram removidas -- nao sobrou nada pra gerar")

    for obj, bone_name in all_parts:
        prim.assign_vertex_group(obj, bone_name)

    objs = [o for o, _ in all_parts]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = name
    merged.data.name = name

    tri_count = sum(max(0, len(poly.vertices) - 2) for poly in merged.data.polygons)
    stats = {
        "vertices": len(merged.data.vertices),
        "faces": len(merged.data.polygons),
        "triangles_estimate": tri_count,
        "materials": len(merged.data.materials),
    }

    return merged, measurements, mat_lib, stats
