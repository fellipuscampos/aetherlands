"""
Interactive editor for the procedural 3D Asset Factory (tools/asset_factory).
Runs INSIDE Blender's own UI (a panel in the 3D viewport sidebar), reusing
every existing generation module (style/character/geometry/rig/animation/
export) instead of duplicating any of that logic -- this is a thin UI layer
on top of the exact same deterministic pipeline `generate_character.py`
drives from the command line.

Workflow (see the panel under View3D > sidebar (N) > "Asset Factory"):
  1. Pick a preset from `presets/*.json`, click "Carregar Modelo".
  2. Drag the dimension sliders (limb lengths/thickness, torso, head) and
     click "Aplicar Dimensoes" to rebuild -- repeat as many times as you
     want, it's cheap and fully in-memory (nothing touches disk yet).
  3. Once the proportions look right, click "Preparar para Pintar": this
     bakes the character's CURRENT colors into one shared paintable image
     (so painting starts from what you already see, not a blank canvas)
     and drops Blender straight into Texture Paint mode. Adjusting
     dimensions again after this point rebuilds the mesh from scratch and
     throws the paint away -- finish shaping first, paint last.
  4. Click "Salvar Modelo": exports the .glb exactly as currently built
     (mesh + skeleton + animations + whatever you painted) to the preset's
     own output directory, writes the painted texture next to it as a
     loose PNG, and rewrites the preset JSON's "body" dimensions so this
     becomes the new deterministic baseline for that character.

How to run: in Blender, go to the Scripting tab, "Open" this file (not
"New" + paste -- Open is what lets this script find its own directory),
then click "Run Script". Re-running after editing this file (or any file
it imports) is safe -- it reloads its own dependencies and re-registers.
"""

import importlib
import json
import math
import os
import sys

import bpy
from mathutils import Vector

bl_info = {
    "name": "Aetherlands Asset Factory Editor",
    "author": "Aetherlands",
    "version": (1, 0, 0),
    "blender": (4, 2, 0),
    "location": "View3D > Sidebar > Asset Factory",
    "description": "Ajusta dimensoes e pinta texturas dos personagens/monstros procedurais do jogo",
    "category": "Object",
}


def _resolve_addon_dir():
    # Blender's Text Editor doesn't reliably set __file__ to this script's
    # real on-disk path even when it was opened (not pasted) from disk --
    # it can come back missing, or pointing at the .blend's own directory
    # instead. Trust a candidate only if it actually contains this
    # package's own "style" submodule; fall back to the known fixed repo
    # location otherwise, rather than silently sys.path-inserting a wrong
    # folder and failing on the first import.
    candidates = []
    try:
        candidates.append(os.path.dirname(os.path.abspath(__file__)))
    except NameError:
        pass
    candidates.append(r"C:\Users\felipe campos\Documents\jogo\tools\asset_factory")
    for candidate in candidates:
        if os.path.isdir(os.path.join(candidate, "style")):
            return candidate
    return candidates[-1]


ADDON_DIR = _resolve_addon_dir()
REPO_ROOT = os.path.dirname(os.path.dirname(ADDON_DIR))
if ADDON_DIR not in sys.path:
    sys.path.insert(0, ADDON_DIR)

# Re-running "Run Script" in the same Blender session after editing any of
# the factory's own modules (body_blocky.py etc.) would otherwise keep
# using the STALE cached version -- Python only imports a module once per
# process. Force a reload of everything this tool touches every time this
# file itself runs.
for _mod_name in [
    "style.definitions", "style.palette", "style.textures",
    "character.params", "character.builder_blocky",
    "geometry.primitives", "geometry.body_blocky", "geometry.equipment_blocky",
    "rig.skeleton", "rig.skinning", "animation.clips", "export.exporter",
]:
    if _mod_name in sys.modules:
        importlib.reload(sys.modules[_mod_name])

from style.definitions import HumanStyle  # noqa: E402
from style.palette import FIXED_COLORS  # noqa: E402
from character.builder_blocky import build_character_blocky  # noqa: E402
from rig.skeleton import build_skeleton  # noqa: E402
from rig.skinning import bind_to_armature  # noqa: E402
from animation.clips import build_all_clips  # noqa: E402
from export.exporter import export_glb  # noqa: E402


# (field name, UI label, min, max)
DIMENSION_FIELDS = [
    ("height", "Altura total", 0.3, 3.0),
    ("limb_thickness", "Espessura geral dos membros", 0.2, 3.0),
    ("shoulder_width_ratio", "Largura dos ombros", 0.05, 0.5),
    ("head_height_ratio", "Altura da cabeca", 0.05, 0.5),
    ("head_width_ratio", "Largura da cabeca", 0.05, 0.5),
    ("head_depth_ratio", "Profundidade da cabeca", 0.05, 0.5),
    ("neck_height_ratio", "Altura do pescoco (quase 0 = cabeca encostada no corpo)", 0.001, 0.15),
    ("torso_height_ratio", "Altura do torso", 0.05, 0.5),
    ("belly_fraction", "Fracao da barriga (resto vai pro peito)", 0.05, 0.9),
    ("upper_arm_ratio", "Comprimento do braco", 0.02, 0.4),
    ("lower_arm_ratio", "Comprimento do antebraco", 0.02, 0.4),
    ("upper_arm_radius_ratio", "Grossura do braco (profundidade)", 0.01, 0.2),
    ("upper_arm_width_mult", "Largura do braco (retangular, 1=quadrado)", 0.3, 3.0),
    ("lower_arm_radius_ratio", "Grossura do antebraco (profundidade)", 0.01, 0.2),
    ("lower_arm_width_mult", "Largura do antebraco (retangular, 1=quadrado)", 0.3, 3.0),
    ("hand_size_ratio", "Tamanho da mao (relativo ao antebraco)", 0.4, 2.5),
    ("hand_width_mult", "Largura da mao (retangular, 1=quadrado)", 0.3, 3.0),
    ("hand_depth_mult", "Profundidade da mao", 0.3, 3.0),
    ("hand_length_mult", "Comprimento da mao (dedos)", 0.3, 3.0),
    ("upper_leg_ratio", "Comprimento da coxa", 0.02, 0.4),
    ("lower_leg_ratio", "Comprimento da canela", 0.02, 0.4),
    ("upper_leg_radius_ratio", "Grossura da coxa (profundidade)", 0.01, 0.25),
    ("upper_leg_width_mult", "Largura da coxa (retangular, 1=quadrado)", 0.3, 3.0),
    ("lower_leg_radius_ratio", "Grossura da canela (profundidade)", 0.01, 0.25),
    ("lower_leg_width_mult", "Largura da canela (retangular, 1=quadrado)", 0.3, 3.0),
    ("foot_width_mult", "Largura do pe (retangular, 1=quadrado)", 0.3, 3.0),
]

# (rig/bones.py name, property name, UI label) -- unchecking one removes
# EVERY mesh part tagged for that bone (body part AND any equipment riding
# on it, e.g. a removed arm's own glove) from the next rebuild. The
# skeleton always keeps every bone regardless -- this only ever removes
# mesh, never a joint.
PART_TOGGLES = [
    ("Neck", "part_neck", "Pescoco"),
    ("Head", "part_head", "Cabeca"),
    ("Chest", "part_chest", "Peito"),
    ("Spine", "part_spine", "Barriga"),
    ("Pelvis", "part_pelvis", "Pelve"),
    ("UpperArm.L", "part_upper_arm_l", "Braco esq. (superior)"),
    ("UpperArm.R", "part_upper_arm_r", "Braco dir. (superior)"),
    ("LowerArm.L", "part_lower_arm_l", "Antebraco esquerdo"),
    ("LowerArm.R", "part_lower_arm_r", "Antebraco direito"),
    ("Hand.L", "part_hand_l", "Mao esquerda"),
    ("Hand.R", "part_hand_r", "Mao direita"),
    ("UpperLeg.L", "part_upper_leg_l", "Coxa esquerda"),
    ("UpperLeg.R", "part_upper_leg_r", "Coxa direita"),
    ("LowerLeg.L", "part_lower_leg_l", "Canela esquerda"),
    ("LowerLeg.R", "part_lower_leg_r", "Canela direita"),
    ("Foot.L", "part_foot_l", "Pe esquerdo"),
    ("Foot.R", "part_foot_r", "Pe direito"),
]

# Live Python objects (measurements/mat_lib/preset dict) that don't survive
# as bpy ID properties -- keyed by the generated mesh object's name, valid
# for as long as that Object exists in this Blender session.
_LIVE = {}
_preset_items_cache = []


def _build_pixel_palette(mat_lib):
    """A small curated bpy.data.palettes swatch set -- the character's own
    colors (skin/hair/eyes, whatever this preset actually set) plus the
    factory's other FIXED_COLORS and a few flat pixel-art staples (black/
    white/gray for outlines and highlights). Shows up directly in the
    Texture Paint tool settings once assigned as the active palette, no
    color picker needed for the common case ("uma paleta de cores onde eu
    posso selecionar a cor", user)."""
    palette = bpy.data.palettes.new("AssetFactoryPalette")
    seen = set()

    def add(color):
        color = tuple(round(c, 3) for c in color)
        if color in seen:
            return
        seen.add(color)
        palette.colors.new().color = color

    add(mat_lib.skin_color_override or FIXED_COLORS["skin"])
    add(FIXED_COLORS["skin_shadow"])
    add(mat_lib.hair_color_override or FIXED_COLORS["hair"])
    if mat_lib.eye_color_override:
        add(mat_lib.eye_color_override)
    add(FIXED_COLORS["leather"])
    add(FIXED_COLORS["wood"])
    add(FIXED_COLORS["steel"])
    add(FIXED_COLORS["steel_dark"])
    add(FIXED_COLORS["cloth"])
    add((0.05, 0.05, 0.05))
    add((0.5, 0.5, 0.5))
    add((0.95, 0.95, 0.95))
    return palette


def _preset_items(self, context):
    global _preset_items_cache
    presets_dir = os.path.join(ADDON_DIR, "presets")
    items = []
    try:
        for fname in sorted(os.listdir(presets_dir)):
            if fname.endswith(".json"):
                items.append((fname, fname[:-5], fname))
    except FileNotFoundError:
        pass
    _preset_items_cache = items or [("NONE", "Nenhum preset encontrado", "")]
    return _preset_items_cache


def _mark_dirty(self, context):
    self.dirty = True


def _isolate_part_items(self, context):
    return [(bone_name, label, bone_name) for bone_name, _, label in PART_TOGGLES]


def _select_vertex_group(obj, bone_name):
    """Selects exactly the vertices/edges/faces belonging to one part's
    bone (a face counts as belonging to it only if ALL its verts do --
    fine here since every body part is its own separate box merged in,
    never sharing a vertex with its neighbor)."""
    vg = obj.vertex_groups.get(bone_name)
    if vg is None:
        return
    idx = vg.index
    mesh = obj.data
    for v in mesh.vertices:
        v.select = any(g.group == idx and g.weight > 0.5 for g in v.groups)
    for edge in mesh.edges:
        edge.select = all(mesh.vertices[vi].select for vi in edge.vertices)
    for poly in mesh.polygons:
        poly.select = all(mesh.vertices[vi].select for vi in poly.vertices)


def _clear_generated(context):
    # Removing objects/mesh-material-image data-blocks directly through
    # the low-level bpy.data.*.remove() API (what this used to do, plus an
    # orphan-data purge loop on top) bypasses Blender's undo system --
    # the undo stack ends up holding references into freed memory, and
    # the NEXT Ctrl+Z after running this addon crashes Blender outright
    # (reported by the user). bpy.ops.object.delete() is the operator
    # Blender's own undo system actually knows how to record/replay, so
    # route object removal through it instead. This leaves the old mesh/
    # armature/action/material/image data-blocks behind as harmless
    # zero-user orphans (a little extra memory per rebuild within one
    # session) -- a deliberate trade for not crashing on undo; use
    # Blender's own File > Clean Up > Purge if that bloat ever matters.
    # bpy.ops.object.delete() defers the actual free -- a just-deleted
    # object can still show up in bpy.data.objects (with our own custom
    # property still on it) on the VERY NEXT rebuild, just no longer
    # linked into any view layer. Selecting one of those raises "can't be
    # selected because it is not in View Layer" and crashes this operator
    # -- only touch tagged objects that are still actually live here.
    to_remove = [o for o in bpy.data.objects
                 if o.get("asset_factory_generated") and o.name in context.view_layer.objects]
    if not to_remove:
        return
    bpy.ops.object.select_all(action='DESELECT')
    for obj in to_remove:
        obj.select_set(True)
    if context.view_layer.objects.active not in to_remove:
        context.view_layer.objects.active = to_remove[0]
    bpy.ops.object.delete()


def _do_rebuild(context, preset):
    props = context.scene.asset_factory_props
    _clear_generated(context)

    style = HumanStyle()
    for key, value in preset.get("body", {}).items():
        if hasattr(style, key):
            setattr(style, key, value)
    name = preset.get("output", {}).get("name", "character")
    seed = preset.get("seed", 0)

    excluded_parts = {bone_name for bone_name, prop_name, _ in PART_TOGGLES if not getattr(props, prop_name)}

    try:
        mesh_obj, measurements, mat_lib, stats = build_character_blocky(
            name, style, preset, seed, excluded_parts=excluded_parts,
        )
        mesh_obj["asset_factory_generated"] = True
        armature_obj = build_skeleton(measurements, name=f"{name}_armature")
        armature_obj["asset_factory_generated"] = True
        bind_to_armature(mesh_obj, armature_obj)
        weapon = preset.get("equipment", {}).get("weapon")
        staff_side = 1 if weapon == "staff" else 0
        build_all_clips(armature_obj, staff_side=staff_side)
    except Exception as exc:
        raise RuntimeError(f"Falha ao gerar personagem (dimensoes invalidas?): {exc}") from exc

    props.mesh_obj = mesh_obj
    props.armature_obj = armature_obj
    props.paint_image = None
    _LIVE.clear()
    _LIVE[mesh_obj.name] = {"preset": preset, "mat_lib": mat_lib}
    return mesh_obj


def _ensure_uv_map_node(tree, tex_node, uv_layer_name):
    uv_node = tree.nodes.new("ShaderNodeUVMap")
    uv_node.uv_map = uv_layer_name
    tree.links.new(uv_node.outputs["UV"], tex_node.inputs["Vector"])


def _grid_unwrap_paint_uv(mesh, uv_layer_name):
    """Writes a fresh, guaranteed-non-degenerate UV layout into
    `uv_layer_name` -- every polygon gets its OWN grid cell, sized to
    preserve that face's real aspect ratio.

    Replaces `bpy.ops.uv.smart_project()`, which turned out to hand 4 of
    every box's 6 faces (all four SIDE walls -- only top/bottom survived)
    a ZERO-WIDTH sliver of UV space on this mesh: verified by dumping
    actual UV bounds per face (a smaller island_margin did not help, so
    it isn't a packing-pressure issue -- smart_project's clustering
    heuristic just doesn't cope with a mesh built ENTIRELY from perfectly
    axis-aligned boxes, which every part in this pipeline is). A face
    with zero UV area can't be painted at all -- "não consigo pintar na
    frente do peito" (user) -- since every stroke on it maps to a single
    point instead of a 2D region. Grid packing is far less space-
    efficient than a real bin-packer, but it can't produce a zero-area
    cell, which is the one property that actually matters here."""
    polys = list(mesh.polygons)
    n = len(polys)
    if n == 0:
        return
    cols = max(1, math.ceil(math.sqrt(n)))
    rows = max(1, math.ceil(n / cols))
    cell_w = 1.0 / cols
    cell_h = 1.0 / rows
    margin = 0.12  # fraction of the cell kept empty, so paint strokes near a face's edge don't bleed into its grid neighbor once nearest-neighbor filtering (hard pixel edges) is in play

    world_axes = (Vector((1.0, 0.0, 0.0)), Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 1.0)))
    uv_layer = mesh.uv_layers[uv_layer_name]

    for i, poly in enumerate(polys):
        col = i % cols
        row = i // cols
        axes = sorted(world_axes, key=lambda a: abs(poly.normal.dot(a)))
        u_axis, v_axis = axes[0], axes[1]
        coords = [mesh.vertices[mesh.loops[li].vertex_index].co for li in poly.loop_indices]
        us = [c.dot(u_axis) for c in coords]
        vs = [c.dot(v_axis) for c in coords]
        umin, umax = min(us), max(us)
        vmin, vmax = min(vs), max(vs)
        uspan = max(umax - umin, 1e-6)
        vspan = max(vmax - vmin, 1e-6)

        avail_w = cell_w * (1.0 - margin)
        avail_h = cell_h * (1.0 - margin)
        scale = min(avail_w / uspan, avail_h / vspan)
        base_u = col * cell_w + (cell_w - uspan * scale) / 2.0
        base_v = row * cell_h + (cell_h - vspan * scale) / 2.0

        for li, u, v in zip(poly.loop_indices, us, vs):
            uv_layer.data[li].uv = (base_u + (u - umin) * scale, base_v + (v - vmin) * scale)


class AssetFactoryProps(bpy.types.PropertyGroup):
    preset_enum: bpy.props.EnumProperty(name="Preset", items=_preset_items)
    preset_file_path: bpy.props.StringProperty(name="Arquivo do preset")
    loaded_name: bpy.props.StringProperty(name="Personagem carregado")
    dirty: bpy.props.BoolProperty(name="Sliders alterados", default=False)
    mesh_obj: bpy.props.PointerProperty(name="Malha gerada", type=bpy.types.Object)
    armature_obj: bpy.props.PointerProperty(name="Esqueleto gerado", type=bpy.types.Object)
    paint_image: bpy.props.PointerProperty(name="Textura pintavel", type=bpy.types.Image)
    paint_resolution: bpy.props.IntProperty(
        name="Resolucao da textura (pixel art)", default=128, min=8, max=512,
        description=("Baixa = pixels bem grandes/visiveis (jogo pixelado); alta = mais parecido com pintura lisa. "
                      "Cada face vira sua propria celula numa grade (evita celulas de area zero), entao com um "
                      "personagem de muitas partes cada celula ja fica pequena -- 128 costuma ser um bom minimo"),
    )
    isolate_part: bpy.props.EnumProperty(name="Parte", items=_isolate_part_items)


for _field, _label, _min, _max in DIMENSION_FIELDS:
    AssetFactoryProps.__annotations__[_field] = bpy.props.FloatProperty(
        name=_label, min=_min, max=_max, precision=3, update=_mark_dirty,
    )
for _bone_name, _prop_name, _label in PART_TOGGLES:
    AssetFactoryProps.__annotations__[_prop_name] = bpy.props.BoolProperty(
        name=_label, default=True, update=_mark_dirty,
    )


class ASSETFACTORY_OT_load_preset(bpy.types.Operator):
    bl_idname = "assetfactory.load_preset"
    bl_label = "Carregar Modelo"
    bl_description = "Carrega o preset selecionado e gera o personagem na cena"

    def execute(self, context):
        props = context.scene.asset_factory_props
        fname = props.preset_enum
        if not fname or fname == "NONE":
            self.report({'ERROR'}, "Nenhum preset selecionado")
            return {'CANCELLED'}

        path = os.path.join(ADDON_DIR, "presets", fname)
        with open(path, "r", encoding="utf-8") as f:
            preset = json.load(f)

        defaults = HumanStyle()
        body_cfg = preset.get("body", {})
        for field, _, _, _ in DIMENSION_FIELDS:
            if field == "hand_width_mult" and field not in body_cfg:
                # hand_width_mult's own dataclass default is None (see
                # definitions.py) so arm_dims() can fall back to the older
                # thick_hands boolean's 0.75/1.2 split -- show the slider
                # whatever that fallback actually resolves to right now,
                # not None/0, so dragging it starts from today's look.
                default_value = 1.2 if body_cfg.get("thick_hands", False) else 0.75
            else:
                default_value = getattr(defaults, field)
            setattr(props, field, body_cfg.get(field, default_value))
        for _, prop_name, _ in PART_TOGGLES:
            setattr(props, prop_name, True)

        try:
            _do_rebuild(context, preset)
        except RuntimeError as exc:
            self.report({'ERROR'}, str(exc))
            return {'CANCELLED'}

        props.preset_file_path = path
        props.loaded_name = preset.get("output", {}).get("name", "character")
        props.dirty = False
        self.report({'INFO'}, f"Carregado: {props.loaded_name}")
        return {'FINISHED'}


class ASSETFACTORY_OT_apply_dimensions(bpy.types.Operator):
    bl_idname = "assetfactory.apply_dimensions"
    bl_label = "Aplicar Dimensoes"
    bl_description = "Reconstroi o personagem com os valores atuais dos sliders (perde qualquer pintura feita antes)"

    def execute(self, context):
        props = context.scene.asset_factory_props
        if not props.preset_file_path:
            self.report({'ERROR'}, "Carregue um preset primeiro")
            return {'CANCELLED'}

        with open(props.preset_file_path, "r", encoding="utf-8") as f:
            preset = json.load(f)
        preset.setdefault("body", {})
        for field, _, _, _ in DIMENSION_FIELDS:
            preset["body"][field] = getattr(props, field)

        try:
            _do_rebuild(context, preset)
        except RuntimeError as exc:
            self.report({'ERROR'}, str(exc))
            return {'CANCELLED'}

        props.dirty = False
        self.report({'INFO'}, "Dimensoes aplicadas")
        return {'FINISHED'}


class ASSETFACTORY_OT_prepare_paint(bpy.types.Operator):
    bl_idname = "assetfactory.prepare_paint"
    bl_label = "Preparar para Pintar"
    bl_description = ("Cria uma textura unica pintavel, faz bake das cores atuais nela (ponto de partida, "
                       "nao comeca em branco) e entra no modo Texture Paint")

    def execute(self, context):
        props = context.scene.asset_factory_props
        obj = props.mesh_obj
        if obj is None or obj.name not in bpy.data.objects:
            self.report({'ERROR'}, "Carregue um modelo primeiro")
            return {'CANCELLED'}

        mesh = obj.data
        # NOT touching mesh.uv_layers.active here (unlike an earlier
        # version) -- _grid_unwrap_paint_uv below writes directly into a
        # NAMED layer via the Python API, no edit-mode/active-layer
        # dance needed. Every EXISTING image-texture node (chainmail,
        # leather, face, nails, ...) with no explicit UV input keeps
        # sampling whatever layer is ALREADY active (unchanged by this
        # operator), so nothing about existing textures can be disturbed.
        if "PaintUV" not in mesh.uv_layers:
            mesh.uv_layers.new(name="PaintUV")
        _grid_unwrap_paint_uv(mesh, "PaintUV")

        # No pre-removal of a same-named old image: bpy.data.images.new()
        # already auto-suffixes (".001", ...) on a name collision, and
        # removing a data-block through the low-level bpy.data API is
        # exactly what made Ctrl+Z crash Blender elsewhere in this addon
        # (see _clear_generated) -- an orphaned old paint image left
        # behind on a second "Preparar para Pintar" click is harmless.
        res = props.paint_resolution
        image = bpy.data.images.new(f"{obj.name}_PaintTexture", res, res, alpha=False)
        image.generated_color = (0.5, 0.5, 0.5, 1.0)

        bake_targets = []
        for mat in mesh.materials:
            if mat is None:
                continue
            mat.use_nodes = True
            tree = mat.node_tree
            tex_node = tree.nodes.new("ShaderNodeTexImage")
            tex_node.name = "AssetFactoryPaintNode"
            tex_node.image = image
            # 'Closest' (nearest-neighbor, no blur between texels) instead
            # of Blender's default 'Linear' -- "o jogo vai ser pixelado...
            # aquela [textura] pelo que vi nao tem pixel" (user). A low
            # paint_resolution alone still gets smoothed into a blurry
            # gradient without this.
            tex_node.interpolation = 'Closest'
            _ensure_uv_map_node(tree, tex_node, "PaintUV")
            for node in tree.nodes:
                node.select = False
            tex_node.select = True
            tree.nodes.active = tex_node
            bake_targets.append((mat, tex_node))

        prev_engine = context.scene.render.engine
        context.scene.render.engine = 'CYCLES'
        try:
            bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=8)
        except RuntimeError as exc:
            self.report({'WARNING'}, f"Bake falhou, tela comeca cinza em vez da cor atual: {exc}")
        finally:
            context.scene.render.engine = prev_engine

        for mat, tex_node in bake_targets:
            bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf is not None:
                mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])

        image.pack()
        props.paint_image = image

        context.view_layer.objects.active = obj
        image_paint = context.scene.tool_settings.image_paint
        image_paint.mode = 'MATERIAL'

        # Enter paint mode BEFORE touching the brush -- Blender only
        # guarantees image_paint.brush points at something real once
        # Texture Paint mode is actually active; grabbing/hardening a
        # brush before that (as this used to do, looking up a fixed name
        # "TexDraw") silently did nothing on Blender 4.x, which moved its
        # default brushes into an asset library and doesn't necessarily
        # keep a plain bpy.data.brushes entry by that name.
        bpy.ops.object.mode_set(mode='TEXTURE_PAINT')

        live = _LIVE.get(obj.name)
        mat_lib = live["mat_lib"] if live and "mat_lib" in live else None
        if mat_lib is not None:
            image_paint.palette = _build_pixel_palette(mat_lib)

        # Hard-edged, flat, full-strength dabs on WHATEVER brush Blender
        # actually made active -- its default falloff is a soft round
        # gradient (an airbrush blur), not a placed pixel. CONSTANT
        # falloff + full strength/MIX blend + no pressure sensitivity
        # makes every stroke a flat blob of the exact picked color,
        # closest this gets to a pixel-art brush without a dedicated 2D
        # pixel editor.
        brush = image_paint.brush
        if brush is not None:
            brush.strength = 1.0
            brush.blend = 'MIX'
            brush.curve_preset = 'CONSTANT'
            brush.use_pressure_strength = False
            brush.use_pressure_size = False
        ups = context.scene.tool_settings.unified_paint_settings
        ups.use_unified_size = True
        ups.size = max(1, res // 20)

        self.report({'INFO'}, (
            "Pronto -- textura %dx%d, filtro Closest (sem borrao), paleta e pincel de borda dura "
            "prontos. A paleta tambem aparece aqui embaixo, no proprio painel. Dica: pra pintar "
            "pixel a pixel de verdade, troque uma area pra 'Image Editor' (canto inferior esquerdo "
            "dela), selecione essa textura e mude o modo pra 'Paint'."
        ) % (res, res))
        return {'FINISHED'}


class ASSETFACTORY_OT_isolate_part(bpy.types.Operator):
    bl_idname = "assetfactory.isolate_part"
    bl_label = "Isolar Parte"
    bl_description = ("Esconde temporariamente todo o resto do personagem, deixando so a parte "
                       "escolhida visivel/pintavel -- nao apaga nada, e so visual, e tambem evita "
                       "que o pincel acerte a geometria vizinha por engano (as partes se sobrepoem "
                       "de proposito nas juntas, pra nao deixar frestas)")

    def execute(self, context):
        props = context.scene.asset_factory_props
        obj = props.mesh_obj
        if obj is None or obj.name not in bpy.data.objects:
            self.report({'ERROR'}, "Carregue um modelo primeiro")
            return {'CANCELLED'}

        return_mode = 'TEXTURE_PAINT' if obj.mode == 'TEXTURE_PAINT' else 'OBJECT'
        context.view_layer.objects.active = obj
        if obj.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')

        # reveal() first -- undo any PREVIOUS isolation's hidden flags, or
        # they'd stack (isolating "Chest" after isolating "Head" would
        # otherwise leave Head hidden forever until Mostrar Tudo).
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.reveal()
        bpy.ops.object.mode_set(mode='OBJECT')

        _select_vertex_group(obj, props.isolate_part)

        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.hide(unselected=True)
        bpy.ops.object.mode_set(mode=return_mode)

        label = next((lbl for bone, _, lbl in PART_TOGGLES if bone == props.isolate_part), props.isolate_part)
        self.report({'INFO'}, f"So '{label}' visivel agora -- use Mostrar Tudo pra reverter")
        return {'FINISHED'}


class ASSETFACTORY_OT_show_all_parts(bpy.types.Operator):
    bl_idname = "assetfactory.show_all_parts"
    bl_label = "Mostrar Tudo"
    bl_description = "Revela qualquer parte escondida por Isolar Parte"

    def execute(self, context):
        props = context.scene.asset_factory_props
        obj = props.mesh_obj
        if obj is None or obj.name not in bpy.data.objects:
            self.report({'ERROR'}, "Carregue um modelo primeiro")
            return {'CANCELLED'}

        return_mode = 'TEXTURE_PAINT' if obj.mode == 'TEXTURE_PAINT' else 'OBJECT'
        context.view_layer.objects.active = obj
        if obj.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.reveal()
        bpy.ops.object.mode_set(mode=return_mode)

        self.report({'INFO'}, "Tudo visivel de novo")
        return {'FINISHED'}


class ASSETFACTORY_OT_save(bpy.types.Operator):
    bl_idname = "assetfactory.save"
    bl_label = "Salvar Modelo"
    bl_description = "Exporta o modelo exatamente como esta agora e regrava o preset com as dimensoes atuais"

    def execute(self, context):
        props = context.scene.asset_factory_props
        obj = props.mesh_obj
        if obj is None or obj.name not in _LIVE:
            self.report({'ERROR'}, "Nada gerado ainda -- carregue um preset primeiro")
            return {'CANCELLED'}

        if context.object is not None and context.object.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')

        preset = _LIVE[obj.name]["preset"]
        output_cfg = preset.get("output", {})
        name = output_cfg.get("name", "character")
        out_dir_rel = output_cfg.get("directory", f"assets/generated/output/{name}")
        out_dir = os.path.abspath(os.path.join(REPO_ROOT, out_dir_rel))
        os.makedirs(out_dir, exist_ok=True)
        glb_path = os.path.join(out_dir, f"{name}.glb")

        try:
            export_glb(glb_path)
        except RuntimeError as exc:
            self.report({'ERROR'}, f"Falha ao exportar: {exc}")
            return {'CANCELLED'}

        if props.paint_image is not None and props.paint_image.name in bpy.data.images:
            texture_path = os.path.join(out_dir, f"{name}_paint.png")
            img = props.paint_image
            img.filepath_raw = texture_path
            img.file_format = 'PNG'
            img.save()

        if props.preset_file_path and os.path.exists(props.preset_file_path):
            with open(props.preset_file_path, "w", encoding="utf-8") as f:
                json.dump(preset, f, indent=2, ensure_ascii=False)
                f.write("\n")

        self.report({'INFO'}, f"Salvo: {glb_path}")
        return {'FINISHED'}


class ASSETFACTORY_PT_panel(bpy.types.Panel):
    bl_label = "Asset Factory Editor"
    bl_idname = "ASSETFACTORY_PT_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Asset Factory"

    def draw(self, context):
        layout = self.layout
        props = context.scene.asset_factory_props

        layout.prop(props, "preset_enum", text="")
        layout.operator("assetfactory.load_preset", icon='IMPORT')

        if not props.loaded_name:
            return

        layout.label(text=f"Carregado: {props.loaded_name}")
        box = layout.box()
        box.label(text="Dimensoes (membros e corpo)")
        for field, _, _, _ in DIMENSION_FIELDS:
            box.prop(props, field)
        layout.separator()
        part_box = layout.box()
        part_box.label(text="Remover Partes (desmarque pra apagar)")
        row = part_box.row()
        col_a = row.column()
        col_b = row.column()
        for i, (_, prop_name, _) in enumerate(PART_TOGGLES):
            (col_a if i % 2 == 0 else col_b).prop(props, prop_name)

        if props.dirty:
            box.label(text="Sliders/partes alterados -- clique Aplicar", icon='ERROR')
        box.operator("assetfactory.apply_dimensions", icon='FILE_REFRESH')

        layout.separator()
        iso_box = layout.box()
        iso_box.label(text="Pintar parte por parte (esconde o resto)")
        iso_box.label(text="So visual -- nao apaga nada, tambem evita o pincel")
        iso_box.label(text="acertar a geometria vizinha nas juntas por engano.")
        iso_box.prop(props, "isolate_part", text="")
        row = iso_box.row(align=True)
        row.operator("assetfactory.isolate_part", icon='HIDE_ON')
        row.operator("assetfactory.show_all_parts", icon='HIDE_OFF')

        layout.separator()
        layout.prop(props, "paint_resolution")
        layout.operator("assetfactory.prepare_paint", icon='BRUSH_DATA')
        layout.label(text="So mexa nos sliders ANTES de pintar.")

        image_paint = context.scene.tool_settings.image_paint
        if image_paint.palette is not None:
            paint_box = layout.box()
            paint_box.label(text="Paleta (clique numa cor pra pintar com ela)")
            paint_box.template_palette(image_paint, "palette", color=True)
            if context.mode == 'PAINT_TEXTURE':
                paint_box.prop(context.scene.tool_settings.unified_paint_settings, "size", text="Tamanho do pincel")
            paint_box.label(text="Pinte na malha na viewport 3D (modo Texture Paint).")

        layout.separator()
        layout.operator("assetfactory.save", icon='FILE_TICK')


_CLASSES = [
    AssetFactoryProps,
    ASSETFACTORY_OT_load_preset,
    ASSETFACTORY_OT_apply_dimensions,
    ASSETFACTORY_OT_prepare_paint,
    ASSETFACTORY_OT_isolate_part,
    ASSETFACTORY_OT_show_all_parts,
    ASSETFACTORY_OT_save,
    ASSETFACTORY_PT_panel,
]


def register():
    for cls in _CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.asset_factory_props = bpy.props.PointerProperty(type=AssetFactoryProps)


def unregister():
    del bpy.types.Scene.asset_factory_props
    for cls in reversed(_CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    try:
        unregister()
    except Exception:
        pass
    register()
