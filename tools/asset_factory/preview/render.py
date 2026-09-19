"""
Automated preview renders: front / side / back / top, orthographic, same
framing every run so results are comparable across iterations/seeds.
"""

import math
import os

import bpy
from mathutils import Vector


def _mesh_world_bounds(obj):
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        mins = Vector(min(a, b) for a, b in zip(mins, p))
        maxs = Vector(max(a, b) for a, b in zip(maxs, p))
    return mins, maxs


def _point_camera(cam_obj, location, target):
    cam_obj.location = location
    direction = Vector(target) - Vector(location)
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def _try_set(obj, attr, value):
    try:
        setattr(obj, attr, value)
    except (AttributeError, TypeError):
        pass


def _setup_render_settings(resolution=900):
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    # Opaque, not transparent: a transparent PNG viewed against a white
    # background makes any pale part (steel, skin, bone, cream cloth)
    # visually vanish -- indistinguishable from "no geometry here". That
    # cost real debugging time (a perfectly fine character read as
    # "missing torso"). An opaque neutral backdrop keeps every color
    # readable regardless of the color itself or what viewer shows it.
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.view_transform = "Standard"  # keep the flat-stylized colors, no filmic desaturation

    eevee = scene.eevee
    _try_set(eevee, "taa_render_samples", 64)
    _try_set(eevee, "use_gtao", True)
    _try_set(eevee, "gtao_distance", 0.4)
    _try_set(eevee, "use_raytracing", True)
    _try_set(eevee, "use_shadows", True)


def _ensure_lighting():
    # AREA lights, not SUN: Eevee's Sun specular reflection doesn't soften
    # with the `angle` property the way area-light specular properly does
    # by size -- a Sun (of any angle) still mirrors as a small hard-edged
    # hotspot on a single flat low-poly face. Area lights fix this at the
    # source instead of fighting it with roughness/specular tweaks.
    key_data = bpy.data.lights.new("PreviewKey", type="AREA")
    key_data.energy = 45.0
    key_data.size = 2.2
    key_data.color = (1.0, 0.96, 0.88)
    key_obj = bpy.data.objects.new("PreviewKey", key_data)
    bpy.context.collection.objects.link(key_obj)
    key_obj.location = (2.2, -2.6, 3.0)
    direction = Vector((0, 0, 0.9)) - key_obj.location
    key_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    fill_data = bpy.data.lights.new("PreviewFill", type="AREA")
    fill_data.energy = 18.0
    fill_data.size = 2.6
    fill_data.color = (0.75, 0.83, 1.0)
    fill_obj = bpy.data.objects.new("PreviewFill", fill_data)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.location = (-2.6, -1.8, 1.6)
    direction = Vector((0, 0, 0.9)) - fill_obj.location
    fill_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    rim_data = bpy.data.lights.new("PreviewRim", type="AREA")
    rim_data.energy = 24.0
    rim_data.size = 2.4
    rim_data.color = (1.0, 1.0, 1.0)
    rim_obj = bpy.data.objects.new("PreviewRim", rim_data)
    bpy.context.collection.objects.link(rim_obj)
    rim_obj.location = (0.0, 2.6, 2.4)
    direction = Vector((0, 0, 0.9)) - rim_obj.location
    rim_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.52, 0.54, 0.58, 1.0)  # visible backdrop now that film isn't transparent
        bg.inputs[1].default_value = 0.9
    bpy.context.scene.world = world


def render_previews(mesh_obj, out_dir, basename="preview", reference_height=None):
    """`reference_height` (the character's own target height, e.g.
    style.height) caps how far a tall HELD PROP (a spear, a banner) can
    zoom the camera out -- without this, a weapon reaching well above the
    head shrinks the character itself down to a sliver of the frame. The
    prop's tip may crop out of the thumbnail instead; the actual 3D asset
    is unaffected, this only changes the preview PNG framing."""
    _setup_render_settings()
    _ensure_lighting()

    mins, maxs = _mesh_world_bounds(mesh_obj)
    full_height = maxs.z - mins.z
    frame_height = min(full_height, reference_height * 1.6) if reference_height else full_height
    mid_z = mins.z + frame_height / 2.0  # anchored to the feet, not the true (prop-skewed) center
    ortho_scale = frame_height * 1.4
    distance = frame_height * 2.5

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    views = {
        "front": ((0, distance, mid_z), (0, 0, mid_z)),
        "side": ((distance, 0, mid_z), (0, 0, mid_z)),
        "back": ((0, -distance, mid_z), (0, 0, mid_z)),
        "top": ((0, 0.0001, mid_z + distance), (0, 0, mid_z)),
    }

    os.makedirs(out_dir, exist_ok=True)
    paths = {}
    for view_name, (loc, target) in views.items():
        _point_camera(cam_obj, loc, target)
        out_path = os.path.join(out_dir, f"{basename}_{view_name}.png")
        bpy.context.scene.render.filepath = out_path
        bpy.ops.render.render(write_still=True)
        paths[view_name] = out_path
    return paths
