"""Conservative, palette-preserving cleanup for the human pixel-art painters.

Only palette noise and known accidental glove/trouser strokes are changed.
UVs, silhouettes, garment construction, heraldry and facial features are inputs,
not generated here. The same function is used by the source painters and repair.
"""

VERSION = 'human_texture_cleanup_v1'


def mix(color, base, amount):
    return tuple(round(b + (c - b) * amount) for c, b in zip(color, base))


def shifted(color, amount):
    return tuple(max(0, min(255, c + amount)) for c in color)


def repair_surface(tile, region, colors):
    mapping = {}
    palettes = dict(colors)
    for name, palette in colors.get('custom', {}).items():
        palettes[name.upper()] = palette
    for name, palette in palettes.items():
        if not isinstance(palette, list) or len(palette) < 2:
            continue
        if not all(isinstance(c, tuple) and len(c) == 3 and
                   all(isinstance(v, int) and 0 <= v <= 255 for v in c) for c in palette):
            continue
        amount = 0.55 if name in ('IRON', 'STEEL', 'BSTEEL', 'MAIL', 'GOLD', 'BRASS', 'FUR', 'PELT') else 0.4
        if name == 'SKIN':
            amount = 0.3
        for c in palette:
            mapping.setdefault(c, mix(c, palette[0], amount))
    leather = colors['LEATHER']
    if region == 'glove':
        # The meshes are closed, block-shaped gloves; drawn finger stripes on
        # arbitrary UV columns read as cuts and disagree between hand faces.
        for c in leather:
            mapping[shifted(c, 18)] = mix(shifted(c, 18), shifted(leather[0], 18), 0.4)
        mapping[colors['LEATHER_DARK']] = shifted(leather[0], 18)
    if region == 'trousers':
        # Randomly interrupted columns are neither a seam nor a cloth weave.
        mapping[colors['WOOL_DARK']] = colors['WOOL'][0]
    if region == 'boot':
        for c in leather:
            mapping[shifted(c, -12)] = mix(shifted(c, -12), shifted(leather[0], -12), 0.4)
    if region in ('gambeson', 'gambeson_chest', 'pelvis', 'pelvis_sash', 'archer_chest'):
        # Keep diamond stitching visible, with less contrast than the leather
        # baldric, buckles and silhouette outlines laid over it.
        mapping[colors['GAMB_SEAM']] = mix(colors['GAMB_SEAM'], colors['GAMB'][0], 0.65)
        mapping[colors['GAMB_HI']] = mix(colors['GAMB_HI'], colors['GAMB'][0], 0.65)
    if region == 'dark_leather':
        # These are bags, knife grips and mantles, not ribbed metal plates.
        mapping[colors['LEATHER_HI']] = mix(colors['LEATHER_HI'], leather[0], 0.25)
    return [[mapping.get(c, c) for c in row] for row in tile]
