"""
Material / color system.

Separation the brief asks for:
    - base material (category: skin, cloth, metal, leather, wood, ...)
    - fixed color (skin, leather, wood, steel -- never re-tinted)
    - civilization/faction color (cloth, shield field, cape, banner -- IS
      re-tinted per civilization)

A preset only ever picks a `civilization` key from CIVILIZATION_PALETTES;
swapping that string reskins the whole character with no geometry change.
"""

import bpy

from style import textures

# Fixed categories that must NOT change with civilization. Punchier and
# more saturated than the first pass -- flat/matte should still read as
# "deliberately stylized", not "washed out and lifeless".
FIXED_COLORS = {
    "skin": (0.93, 0.68, 0.52),
    "skin_shadow": (0.74, 0.52, 0.40),
    "leather": (0.44, 0.27, 0.14),
    "wood": (0.34, 0.22, 0.12),
    "steel": (0.58, 0.60, 0.64),
    "steel_dark": (0.32, 0.34, 0.38),
    "eyes": (0.08, 0.07, 0.09),
    "hair": (0.28, 0.17, 0.10),
    # Undyed wool/burlap -- used for cloth with faction=False (a civilian's
    # tunic; dyeing cloth in a team color was the whole soldier/civilian
    # visual signal, a peasant wouldn't). Without this, get_cloth_textured
    # fell back to a flat (0.5, 0.5, 0.5) mid-gray -- close enough this
    # entry was worth naming explicitly instead of leaving as an
    # unlabeled fallback.
    "cloth": (0.62, 0.52, 0.36),
}

# Civilization/faction palettes. Only elements meant to carry team colors
# (cloth, shield field, cape, trim) read from these.
CIVILIZATION_PALETTES = {
    "human_default": {
        "cloth": (0.72, 0.07, 0.09),
        "cloth_trim": (0.92, 0.78, 0.30),
        "shield_field": (0.72, 0.07, 0.09),
        "shield_trim": (0.92, 0.78, 0.30),
    },
    "human_blue": {
        "cloth": (0.09, 0.24, 0.68),
        "cloth_trim": (0.85, 0.87, 0.92),
        "shield_field": (0.09, 0.24, 0.68),
        "shield_trim": (0.85, 0.87, 0.92),
    },
    "human_green": {
        "cloth": (0.10, 0.48, 0.18),
        "cloth_trim": (0.90, 0.84, 0.55),
        "shield_field": (0.10, 0.48, 0.18),
        "shield_trim": (0.90, 0.84, 0.55),
    },
}

ROUGHNESS_BY_CATEGORY = {
    "skin": 0.55,
    "cloth": 0.75,
    "leather": 0.62,
    "wood": 0.75,
    "metal": 0.40,
    "eyes": 0.15,
    "hair": 0.6,
}

METALLIC_BY_CATEGORY = {
    "metal": 0.75,
}


class MaterialLibrary:
    """Caches bpy materials by (category, color) so parts share slots."""

    def __init__(self, civilization: str = "human_default", skin_color=None, hair_color=None, eye_color=None):
        self.civilization = civilization
        self.palette = CIVILIZATION_PALETTES.get(
            civilization, CIVILIZATION_PALETTES["human_default"]
        )
        # Per-character override, not per-civilization: skin/hair are FIXED
        # (never civ-tinted, see FIXED_COLORS' own comment) because a
        # soldier's own skin tone has nothing to do with which army he's
        # in -- but a genuinely different SPECIES (a goblin, orc, ...)
        # does need its own skin color. Overriding here (not by adding
        # goblin-specific entries to FIXED_COLORS) keeps that dict meaning
        # "every human, any civilization" and puts the species-specific
        # color where the species-specific preset already lives.
        self.skin_color_override = skin_color
        self.hair_color_override = hair_color
        self.eye_color_override = eye_color
        self._cache = {}

    def _make(self, key: str, color, roughness: float, metallic: float):
        mat = bpy.data.materials.new(name=key)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        for spec_key in ("Specular IOR Level", "Specular"):
            if spec_key in bsdf.inputs:
                bsdf.inputs[spec_key].default_value = 0.25
                break
        mat.diffuse_color = (*color, 1.0)
        return mat

    def get(self, category: str, faction: bool = False):
        """category: skin / cloth / leather / wood / metal / eyes / hair.
        faction=True pulls the civilization-tinted variant of that slot
        (only meaningful for cloth/shield categories)."""
        cache_key = (category, faction, self.civilization)
        if cache_key in self._cache:
            return self._cache[cache_key]

        if faction:
            color = self.palette.get(category, FIXED_COLORS.get(category, (0.7, 0.7, 0.7)))
            base_category = category.split("_")[0]
        elif category == "skin" and self.skin_color_override:
            color = self.skin_color_override
            base_category = category
        elif category == "hair" and self.hair_color_override:
            color = self.hair_color_override
            base_category = category
        else:
            color = FIXED_COLORS.get(category)
            if color is None:
                # e.g. "metal" isn't in FIXED_COLORS by that exact name -> steel
                color = FIXED_COLORS.get("steel", (0.6, 0.6, 0.6))
            base_category = category

        roughness = ROUGHNESS_BY_CATEGORY.get(base_category, 0.7)
        metallic = METALLIC_BY_CATEGORY.get(base_category, 0.0)
        name = f"{category}{'_faction' if faction else ''}_{self.civilization}"
        mat = self._make(name, color, roughness, metallic)
        self._cache[cache_key] = mat
        return mat

    def get_metal(self, dark: bool = False):
        key = "metal_dark" if dark else "metal"
        if key in self._cache:
            return self._cache[key]
        color = FIXED_COLORS["steel_dark"] if dark else FIXED_COLORS["steel"]
        mat = self._make(key, color, ROUGHNESS_BY_CATEGORY["metal"], METALLIC_BY_CATEGORY["metal"])
        self._cache[key] = mat
        return mat

    def get_torn_cloth_flat(self):
        """Flat, muted worn-gray -- the flat-color counterpart to the
        tiled `torn_cloth_tiled` material equipment_blocky.
        build_debris_parts builds inline for the textured version.
        Deliberately NOT the same tone as the tan `cloth` category (a
        civilian robe) or the leather brown already elsewhere on a
        bare-skinned character -- needs to read as a distinct rag."""
        key = "torn_cloth_flat"
        if key in self._cache:
            return self._cache[key]
        mat = self._make(key, (0.42, 0.40, 0.36), 0.8, 0.0)
        self._cache[key] = mat
        return mat

    def get_leaf(self):
        """Fixed leaf-green -- never civ-tinted or skin-tinted, same
        reasoning as FIXED_COLORS itself. Used by equipment_blocky.
        build_debris_parts for actual 3D leaf geometry (not a texture
        speckle -- see build_hide_image's docstring for why)."""
        key = "leaf"
        if key in self._cache:
            return self._cache[key]
        mat = self._make(key, (0.24, 0.46, 0.16), 0.6, 0.0)
        self._cache[key] = mat
        return mat

    # --- Tiled/textured variants: material category-appropriate procedural
    # patterns (see style/textures.py) instead of a flat color. Used with
    # geometry.primitives.apply_tiled_material, not assign_material. ---

    def get_chainmail(self):
        cache_key = ("tiled", "chainmail")
        if cache_key in self._cache:
            return self._cache[cache_key]
        image = textures.build_chainmail_image("tex_chainmail", FIXED_COLORS["steel"])
        mat = textures.build_tiled_material("chainmail", image, roughness=0.42, metallic=0.7)
        self._cache[cache_key] = mat
        return mat

    def get_leather_textured(self):
        cache_key = ("tiled", "leather")
        if cache_key in self._cache:
            return self._cache[cache_key]
        image = textures.build_leather_image("tex_leather", FIXED_COLORS["leather"])
        mat = textures.build_tiled_material("leather_tiled", image, roughness=0.65)
        self._cache[cache_key] = mat
        return mat

    def get_hide_textured(self):
        """Mottled skin/hide BASE TONE (see textures.build_hide_image) for
        a bare-skinned species' large exposed panels (torso/arms/legs/
        head/feet) -- uses `skin_color_override` when set (a goblin/
        orc's own skin tone), same as the flat `get("skin")` used for a
        human's face/hands, just textured instead of flat. Muscle
        definition and vegetation/torn-cloth debris are NOT part of this
        -- see get_muscle_face (a unique per-body-part overlay) and
        equipment_blocky.build_debris_parts (real geometry) instead; a
        tiled/repeating image is the wrong tool for either (see
        build_hide_image's own docstring)."""
        cache_key = ("tiled", "hide", self.civilization, self.skin_color_override)
        if cache_key in self._cache:
            return self._cache[cache_key]
        base = self.skin_color_override or FIXED_COLORS["skin"]
        image = textures.build_hide_image(f"tex_hide_{self.civilization}", base)
        mat = textures.build_tiled_material(f"hide_tiled_{self.civilization}", image, roughness=0.55)
        self._cache[cache_key] = mat
        return mat

    def get_muscle_face(self, region: str):
        """A unique (non-tiled) muscle-definition texture for ONE
        specific body part -- see textures.build_muscle_image. Meant to
        be applied with geometry.primitives.tag_front_face, the same
        technique as the head's face texture, NOT apply_tiled_material
        (a muscle bulge that repeats every few centimeters up a limb
        reads as a fabric print, not anatomy)."""
        cache_key = ("muscle_face", region, self.civilization, self.skin_color_override)
        if cache_key in self._cache:
            return self._cache[cache_key]
        base = self.skin_color_override or FIXED_COLORS["skin"]
        image = textures.build_muscle_image(f"tex_muscle_{region}_{self.civilization}", base, region=region)
        mat = textures.build_face_material(f"muscle_mat_{region}_{self.civilization}", image)
        self._cache[cache_key] = mat
        return mat

    def get_bone_face(self, region: str):
        """Unique (non-tiled) ribcage/bone-segment texture for ONE body
        part -- see textures.build_bone_image. Same tag_front_face
        technique as get_muscle_face, independent of it (a Skeleton has
        bone structure, not muscle bulges) and NOT gated by the
        `textured` flag the way muscles is -- this is what actually
        makes bone read as bone instead of a flat colored box, so it
        should show up even when every other surface stays flat-colored."""
        cache_key = ("bone_face", region, self.civilization, self.skin_color_override)
        if cache_key in self._cache:
            return self._cache[cache_key]
        base = self.skin_color_override or FIXED_COLORS["skin"]
        image = textures.build_bone_image(f"tex_bone_{region}_{self.civilization}", base, region=region)
        mat = textures.build_face_material(f"bone_mat_{region}_{self.civilization}", image)
        self._cache[cache_key] = mat
        return mat

    def get_cloth_textured(self, faction: bool = True):
        cache_key = ("tiled", "cloth", faction, self.civilization)
        if cache_key in self._cache:
            return self._cache[cache_key]
        color = self.palette.get("cloth") if faction else FIXED_COLORS.get("cloth", (0.5, 0.5, 0.5))
        image = textures.build_cloth_image(f"tex_cloth_{self.civilization}", color)
        mat = textures.build_tiled_material(f"cloth_tiled_{self.civilization}", image, roughness=0.8)
        self._cache[cache_key] = mat
        return mat

    def get_wood_textured(self):
        cache_key = ("tiled", "wood")
        if cache_key in self._cache:
            return self._cache[cache_key]
        image = textures.build_wood_image("tex_wood", FIXED_COLORS["wood"])
        mat = textures.build_tiled_material("wood_tiled", image, roughness=0.75)
        self._cache[cache_key] = mat
        return mat

    def get_metal_textured(self, dark: bool = False):
        cache_key = ("tiled", "metal", dark)
        if cache_key in self._cache:
            return self._cache[cache_key]
        color = FIXED_COLORS["steel_dark"] if dark else FIXED_COLORS["steel"]
        image = textures.build_brushed_metal_image(f"tex_metal{'_dark' if dark else ''}", color)
        mat = textures.build_tiled_material(f"metal_tiled{'_dark' if dark else ''}", image,
                                             roughness=0.35, metallic=0.75)
        self._cache[cache_key] = mat
        return mat

    def all_materials(self):
        return list(self._cache.values())
