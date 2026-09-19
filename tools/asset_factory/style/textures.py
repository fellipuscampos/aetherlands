"""
Procedural pixel-art textures. The Hytale/voxel-avatar look isn't just
blocky geometry with flat colors -- materials need to actually READ as
what they are: chainmail should look like interlocking rings, leather
like grained hide, cloth like a woven fabric, wood like grain, metal
plate like brushed steel. Every image here is generated as a small,
TILEABLE pattern (repeated across a surface via UV coordinates that run
0..N instead of 0..1 -- see geometry/primitives.apply_tiled_material) so
one small texture reads at a consistent, sensible physical scale
regardless of how big the box wearing it is.

Everything is a flat Python RGBA pixel buffer, generated with plain
arithmetic (no external art tool, no randomness that isn't seeded) so it
stays inside the same reproducible pipeline as the rest of this factory.
"""

import bpy


def _fill(pixels, size, x0, y0, w, h, color, alpha=1.0):
    r, g, b = color
    for y in range(max(0, y0), min(size, y0 + h)):
        row = y * size
        for x in range(max(0, x0), min(size, x0 + w)):
            idx = (row + x) * 4
            pixels[idx:idx + 4] = [r, g, b, alpha]


def _set(pixels, size, x, y, color):
    if 0 <= x < size and 0 <= y < size:
        idx = (y * size + x) * 4
        pixels[idx:idx + 4] = [color[0], color[1], color[2], 1.0]


def _new_image(name, size):
    img = bpy.data.images.new(name, size, size, alpha=False)
    # Pixels below are written as the SAME raw linear-ish numbers passed
    # straight into a flat material's Base Color (e.g. skin_color). A new
    # bpy image defaults to the "sRGB" colorspace, which makes the shader
    # decode every sampled pixel sRGB->linear before use -- silently
    # darkening/re-saturating the texture relative to a flat material
    # using the identical color tuple (0.24 sRGB-decodes to ~0.047
    # linear). This is what made the goblin's head (textured face patch)
    # read as a different green than its flat-colored body even though
    # both were built from the same skin_color. "Non-Color" makes the
    # shader use the stored numbers as-is, matching the flat materials.
    img.colorspace_settings.name = 'Non-Color'
    return img, [0.0] * (size * size * 4)


def _shade(color, factor):
    return tuple(max(0.0, min(1.0, c * factor)) for c in color)


# --------------------------------------------------------------------------
# Face (unique per character, not tiled -- see geometry.primitives.tag_front_face)
# --------------------------------------------------------------------------

def build_head_face_image(name, skin_color, eye_color=(0.32, 0.56, 0.82), size=32,
                           beard_color=None, beard=True, teeth=False, eye_style="round"):
    """A square texture meant for ONE face of the head box: skin-colored
    background, two big eyes, simple brows, a mouth line, and -- if
    `beard` -- a light shadow of stubble across the jaw/chin (not a full
    3D beard volume, a subtle tone shift, per "barba de leve"). Row 0 is
    the bottom of the image (Blender's convention) -- eyes are placed
    high up (large y).

    `eye_style="round"` (every human so far) is the cartoon eye (white
    sclera + iris + pupil + highlight dot). `eye_style="slit"` is a
    solid glowing eye instead -- no white at all, just the eye color
    with a thin dark vertical pupil slit -- for a creature ("o olho
    desse aqui ta menos humano", user, re: a monster reference).
    `eye_style="hollow"` is an empty skull socket -- flat solid black,
    no iris/pupil/highlight at all (a Skeleton has no eye to shade)."""
    img, pixels = _new_image(name, size)
    _fill(pixels, size, 0, 0, size, size, skin_color)

    eye_w, eye_h = 7, 7
    eye_y = 15
    left_x, right_x = 6, size - 6 - eye_w
    for ex in (left_x, right_x):
        if eye_style == "slit":
            _fill(pixels, size, ex, eye_y, eye_w, eye_h, (0.04, 0.04, 0.05))  # dark socket, no white sclera
            _fill(pixels, size, ex + 1, eye_y + 1, eye_w - 2, eye_h - 2, eye_color)
            _fill(pixels, size, ex + 3, eye_y + 1, 1, eye_h - 2, (0.03, 0.03, 0.04))  # vertical pupil slit
        elif eye_style == "hollow":
            # Slightly bigger and shifted down from the round socket --
            # reads as a deeper cavity, not just a dark iris.
            _fill(pixels, size, ex - 1, eye_y - 1, eye_w + 2, eye_h + 2, (0.02, 0.02, 0.02))
        else:
            _fill(pixels, size, ex, eye_y, eye_w, eye_h, (0.05, 0.05, 0.06))  # dark outline/socket
            _fill(pixels, size, ex + 1, eye_y + 1, eye_w - 2, eye_h - 2, (1.0, 1.0, 1.0))
            _fill(pixels, size, ex + 2, eye_y + 1, 3, 4, eye_color)
            _fill(pixels, size, ex + 2, eye_y + 2, 2, 2, (0.03, 0.03, 0.04))
            _fill(pixels, size, ex + 1, eye_y + 4, 1, 1, (1.0, 1.0, 1.0))  # highlight

    brow_color = _shade(skin_color, 0.45)
    for ex in (left_x - 1, right_x - 1):
        _fill(pixels, size, ex, eye_y + eye_h + 1, eye_w + 2, 2, brow_color)

    if beard:
        # A hard-edged brown block across most of the lower face read as
        # a strange painted-on patch, not stubble. "Leve" means barely
        # there: a SMALL strip, right at the chin only, blended mostly
        # toward the skin tone rather than a distinct hair color.
        tint = beard_color if beard_color else _shade(skin_color, 0.55)
        stubble = tuple(sc * 0.6 + tc * 0.4 for sc, tc in zip(skin_color, tint))
        _fill(pixels, size, size // 2 - 5, 0, 10, 3, stubble)

    if teeth:
        # Wide, dark, open mouth with a row of jagged light teeth --
        # "goblin/monster" grin instead of the plain closed mouth line.
        dark = (0.05, 0.04, 0.03)
        _fill(pixels, size, size // 2 - 7, 5, 14, 4, dark)
        tooth_color = (0.92, 0.88, 0.72)
        for tx in range(size // 2 - 6, size // 2 + 6, 3):
            _fill(pixels, size, tx, 7, 2, 2, tooth_color)
    else:
        mouth_color = _shade(skin_color, 0.65)
        _fill(pixels, size, size // 2 - 4, 7, 8, 2, mouth_color)

    img.pixels[:] = pixels
    img.pack()
    return img


def build_foot_nail_image(name, skin_color, nail_color=None, size=16, toe_count=4):
    """A square texture for ONE face of a bare (unbooted) foot box -- skin
    background with a row of small light toenails near the BOTTOM edge.
    Same technique as build_head_face_image (a unique, non-tiled texture
    tagged onto one face via geometry.primitives.tag_front_face), just
    for feet instead of the head.

    Row 0 is the BOTTOM of the image (Blender's convention, see
    build_head_face_image's own docstring) -- the foot box's front face
    spans from the ankle/leg join (top of the box, high Z, i.e. high row
    index) down to ground level (bottom of the box, low Z, i.e. LOW row
    index), and the toes/nails sit at the ground end. An earlier version
    put the nails near `size` (the ankle end) instead of near 0 (the toe
    end) -- backwards ("as unhas devem ficar na parte de baixo dos pes
    nao no topo", user)."""
    img, pixels = _new_image(name, size)
    _fill(pixels, size, 0, 0, size, size, skin_color)

    tint = nail_color if nail_color else (0.85, 0.80, 0.72)
    nail_w = max(1, size // (toe_count * 2))
    gap = nail_w
    total_w = toe_count * nail_w + (toe_count - 1) * gap
    start_x = (size - total_w) // 2
    nail_y = max(0, size // 8)
    for i in range(toe_count):
        x = start_x + i * (nail_w + gap)
        _fill(pixels, size, x, nail_y, nail_w, max(1, size // 6), tint)

    img.pixels[:] = pixels
    img.pack()
    return img


def build_face_material(name, image, roughness=0.55):
    """`roughness` defaults to skin's own value (see palette.
    ROUGHNESS_BY_CATEGORY["skin"]) -- this used to be hardcoded to 0.65
    with no Specular set at all (leaving Blender's default, ~0.5), while
    the FLAT skin material used by the rest of the same head/foot (see
    palette.MaterialLibrary._make) sets 0.25. Two different roughness/
    specular values on the exact same base color reflect light
    differently regardless of lighting setup -- reads as a visibly
    different tone on the textured face/toe patch vs. the rest of the
    body ("pes e cabeca sao de tons diferentes", user) even though the
    underlying color was always identical. Matching both fixes it."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.image = image
    tex_node.interpolation = "Closest"  # crisp pixel-art, no texture blur
    mat.node_tree.links.new(bsdf.inputs["Base Color"], tex_node.outputs["Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    for spec_key in ("Specular IOR Level", "Specular"):
        if spec_key in bsdf.inputs:
            bsdf.inputs[spec_key].default_value = 0.25
            break
    return mat


# --------------------------------------------------------------------------
# Tileable material textures
# --------------------------------------------------------------------------

def build_hide_image(name, base_color, size=16):
    """Mottled organic skin/hide base tone -- same deterministic hash-
    noise technique as build_leather_image (blotchy tonal variation,
    never a flat single color -- real skin/hide always has some). This
    is deliberately ONLY the base tone now: a tiled/repeating image is
    the wrong tool for muscle definition or vegetation (those read as a
    single designed shape on ONE specific body part, not a pattern that
    repeats every few centimeters) -- see build_muscle_image (a unique
    per-body-part texture, same tag_front_face technique as the head's
    face) and equipment_blocky.build_debris_parts (actual small 3D
    leaf/torn-cloth geometry) for those instead. An earlier version of
    this function tried to fake both with per-pixel modulo noise -- "so
    inseriu ruido pra caralho... nao tentou construir nada" (user,
    fairly)."""
    img, pixels = _new_image(name, size)
    for y in range(size):
        for x in range(size):
            h = (x * 41 + y * 23 + x * y * 3) % 17
            factor = 0.82 + 0.32 * (h / 16.0)
            _set(pixels, size, x, y, _shade(base_color, factor))

    img.pixels[:] = pixels
    img.pack()
    return img


def build_muscle_image(name, base_color, region="chest", size=32):
    """A UNIQUE (non-tiled) texture mapped onto ONE specific body part
    via geometry.primitives.tag_front_face -- actual designed muscle
    shapes, not a repeating pattern (a tiled "muscle" texture would show
    the same bulge stamped every few centimeters up a limb, which reads
    as a fabric print, not anatomy). Row 0 is the bottom of the image
    (Blender's convention, see build_head_face_image).

    `region`:
      "chest" -- two symmetric pec highlight/shadow curves in the upper
        half, a center line (sternum groove), and a stack of ab shadow
        lines lower down.
      "bicep"/"thigh" -- a single vertical highlight down the muscle's
        own centerline with a shadow on each side, suggesting a round
        bulge (thigh gets a slightly wider, lower highlight for the
        quad).
      "forearm"/"calf" -- 2-3 thin vertical tendon/muscle striations,
        subtler than the bulge regions above."""
    img, pixels = _new_image(name, size)
    _fill(pixels, size, 0, 0, size, size, base_color)
    highlight = _shade(base_color, 1.28)
    shadow = _shade(base_color, 0.60)

    if region == "chest":
        for s in (-1, 1):
            cx = size // 2 + s * (size // 4)
            for x in range(size):
                dx = (x - cx) / (size * 0.24)
                if abs(dx) > 1.0:
                    continue
                arc = int((1 - dx * dx) ** 0.5 * size * 0.16)
                cy = int(size * 0.66)
                _set(pixels, size, x, cy + arc, highlight)
                _set(pixels, size, x, cy - 2, shadow)
        for x in range(size // 2 - 1, size // 2 + 1):
            _fill(pixels, size, x, size // 4, 1, size // 3, shadow)  # sternum groove
        for i, ab_y in enumerate((size // 4 - 2, size // 6, size // 10)):
            _fill(pixels, size, size // 2 - 6, max(0, ab_y), 12, 1, shadow)

    elif region in ("bicep", "thigh"):
        width_frac = 0.10 if region == "bicep" else 0.16
        cx = size // 2
        for y in range(size):
            hw = int(size * width_frac)
            _fill(pixels, size, cx - hw // 2, y, hw, 1, highlight)
            _fill(pixels, size, cx - hw // 2 - 2, y, 2, 1, shadow)
            _fill(pixels, size, cx + hw // 2, y, 2, 1, shadow)

    elif region in ("forearm", "calf"):
        for i, x in enumerate(range(size // 3, size - size // 3, max(1, size // 6))):
            tone = highlight if i % 2 == 0 else shadow
            _fill(pixels, size, x, 0, 1, size, tone)

    img.pixels[:] = pixels
    img.pack()
    return img


def build_bone_image(name, base_color, region="chest", size=32):
    """A UNIQUE (non-tiled) texture mapped onto ONE body part via
    geometry.primitives.tag_front_face -- same technique as
    build_muscle_image, but drawing actual bone structure instead of
    muscle bulges: a flat bone-colored box alone read as "just an
    albino" (user), since nothing on it actually looks skeletal.

    `region`:
      "chest" -- a ribcage: a vertical spine/sternum groove down the
        center with a stack of curved rib lines arcing out from it on
        both sides, plus a dark pelvic notch at the very bottom (where
        the ribcage would end).
      "bicep"/"forearm"/"thigh"/"calf" -- 2-3 dark horizontal bands
        crossing the whole width, marking where separate bone segments
        would meet (a single smooth box has no such seam otherwise)."""
    img, pixels = _new_image(name, size)
    _fill(pixels, size, 0, 0, size, size, base_color)
    shadow = _shade(base_color, 0.55)
    deep_shadow = _shade(base_color, 0.35)

    if region == "chest":
        cx = size // 2
        _fill(pixels, size, cx - 1, size // 6, 2, size * 2 // 3, shadow)  # spine/sternum groove
        rib_ys = [int(size * f) for f in (0.42, 0.55, 0.68, 0.81)]
        for i, ry in enumerate(rib_ys):
            rib_w = size // 2 - i  # ribs narrow slightly going up
            for s in (-1, 1):
                for dx in range(2, rib_w):
                    x = cx + s * dx
                    # gentle downward arc away from the spine, like a real rib
                    sag = int((dx / rib_w) ** 2 * 3)
                    _set(pixels, size, x, ry - sag, shadow)
        _fill(pixels, size, cx - size // 6, size // 8, size // 3, 2, deep_shadow)  # pelvic notch

    elif region in ("bicep", "forearm", "thigh", "calf"):
        band_count = 2 if region in ("bicep", "thigh") else 3
        for i in range(1, band_count + 1):
            y = size * i // (band_count + 1)
            _fill(pixels, size, 0, y, size, 2, shadow)
            _fill(pixels, size, 0, y - 2, size, 1, deep_shadow)

    img.pixels[:] = pixels
    img.pack()
    return img


def build_chainmail_image(name, ring_color, size=16):
    """Staggered ring grid -- alternate rows offset by half a cell, each
    ring drawn as a dark hole (the gap you see through mail) ringed by a
    lighter highlight (the metal catching light), on the base metal tone.
    Reads as chainmail at the small on-screen scale this pipeline targets."""
    img, pixels = _new_image(name, size)
    dark = _shade(ring_color, 0.45)
    light = _shade(ring_color, 1.35)
    _fill(pixels, size, 0, 0, size, size, ring_color)

    cell = 4
    for y in range(size):
        for x in range(size):
            row = y // cell
            xo = (x + (cell // 2 if row % 2 else 0)) % cell
            yo = y % cell
            dx, dy = xo - cell / 2.0 + 0.5, yo - cell / 2.0 + 0.5
            d = (dx * dx + dy * dy) ** 0.5
            if d < 0.9:
                _set(pixels, size, x, y, dark)
            elif d < 1.6:
                _set(pixels, size, x, y, light)

    img.pixels[:] = pixels
    img.pack()
    return img


def build_leather_image(name, base_color, size=16):
    """Mottled hide grain -- deterministic pseudo-noise speckling (a hash
    of the pixel coordinates, not true randomness, so the same seed/preset
    always produces the same texture) plus a couple of darker "crease"
    lines."""
    img, pixels = _new_image(name, size)
    for y in range(size):
        for x in range(size):
            h = (x * 37 + y * 17 + x * y) % 13
            factor = 0.86 + 0.28 * (h / 12.0)
            _set(pixels, size, x, y, _shade(base_color, factor))

    crease = _shade(base_color, 0.6)
    for x in range(size):
        _set(pixels, size, x, (x * 3) % size, crease)
    for y in range(size):
        _set(pixels, size, (y * 5 + 2) % size, y, crease)

    img.pixels[:] = pixels
    img.pack()
    return img


def build_cloth_image(name, base_color, size=16):
    """Basket-weave -- a 2x2 checker of subtly different tones, the
    cheapest pattern that still reads as "woven" rather than flat plastic."""
    img, pixels = _new_image(name, size)
    warp = _shade(base_color, 1.06)
    weft = _shade(base_color, 0.92)
    for y in range(size):
        for x in range(size):
            on = ((x // 2) + (y // 2)) % 2 == 0
            _set(pixels, size, x, y, warp if on else weft)
    img.pixels[:] = pixels
    img.pack()
    return img


def build_wood_image(name, base_color, size=16):
    """Grain bands running along Y (the shaft's length once tiled) with a
    slow sine-ish wobble so the bands aren't perfectly straight lines."""
    img, pixels = _new_image(name, size)
    for y in range(size):
        for x in range(size):
            wobble = (y * 3) % size
            band = (x + wobble // 4) % 5
            factor = (0.82, 0.94, 1.08, 0.90, 1.0)[band]
            _set(pixels, size, x, y, _shade(base_color, factor))
    img.pixels[:] = pixels
    img.pack()
    return img


def build_brushed_metal_image(name, base_color, size=16):
    """Vertical brushed-steel streaks -- distinct from the ring pattern of
    chainmail, for plate armor/blades/helmets: "worked metal", not mail."""
    img, pixels = _new_image(name, size)
    for y in range(size):
        for x in range(size):
            h = (x * 29 + (x * x) * 7) % 9
            factor = 0.90 + 0.22 * (h / 8.0)
            _set(pixels, size, x, y, _shade(base_color, factor))
    # a couple of brighter rivet-like highlight columns
    highlight = _shade(base_color, 1.4)
    for x in (2, size - 3):
        for y in range(size):
            _set(pixels, size, x, y, highlight)
    img.pixels[:] = pixels
    img.pack()
    return img


def build_tiled_material(name, image, roughness=0.7, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    tex_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex_node.image = image
    tex_node.interpolation = "Closest"
    tex_node.extension = "REPEAT"
    mat.node_tree.links.new(bsdf.inputs["Base Color"], tex_node.outputs["Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    for spec_key in ("Specular IOR Level", "Specular"):
        if spec_key in bsdf.inputs:
            bsdf.inputs[spec_key].default_value = 0.25
            break
    return mat
