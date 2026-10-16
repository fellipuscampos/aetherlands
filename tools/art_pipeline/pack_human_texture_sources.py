"""Pack repaired albedos into editable scenes and render review views in Blender.

This updates images only. Render settings and camera transforms are restored
before saving, and a semantic digest checks meshes, UVs, skin weights and curves.
"""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art_source/human_texture_repair'
ROGUES = {'rogue_v1', 'saboteur_v1', 'assassin_v1', 'shadow_master_v1'}
VIEWS = {'three_quarter': (6,-12,5.6), 'front': (0,-12,1.2),
         'side': (12,0,2.0), 'back': (-6,12,5.0), 'game_top': (5,-7,11)}


def signature(scene):
    data = {'objects': [], 'actions': []}
    for o in sorted(scene.objects, key=lambda o:o.name):
        if o.type not in ('MESH', 'ARMATURE', 'EMPTY'):
            continue
        row = {'name': o.name, 'type': o.type, 'parent': o.parent.name if o.parent else None,
               'matrix': [list(r) for r in o.matrix_basis]}
        if o.type == 'MESH':
            row.update(vertices=[list(v.co) for v in o.data.vertices],
                       polygons=[list(p.vertices) for p in o.data.polygons],
                       normals=[list(p.normal) for p in o.data.polygons],
                       uv={u.name:[list(v.uv) for v in u.data] for u in o.data.uv_layers},
                       groups=[g.name for g in o.vertex_groups],
                       weights=[[(g.group,g.weight) for g in v.groups] for v in o.data.vertices],
                       modifiers=[(m.name,m.type,getattr(getattr(m,'object',None),'name',None)) for m in o.modifiers])
        elif o.type == 'ARMATURE':
            row['bones'] = [(b.name,b.parent.name if b.parent else None,[list(r) for r in b.matrix_local]) for b in o.data.bones]
            row['nla'] = [(t.name,t.mute,[(s.name,s.action.name,s.frame_start,s.frame_end,s.action_frame_start,s.action_frame_end)
                                        for s in t.strips]) for t in o.animation_data.nla_tracks] if o.animation_data else []
        data['objects'].append(row)
    for a in sorted(bpy.data.actions, key=lambda a:a.name):
        curves = []
        for layer in a.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        curves.append((fc.data_path,fc.array_index,[(list(k.co),k.interpolation,list(k.handle_left),list(k.handle_right))
                                                                 for k in fc.keyframe_points]))
        data['actions'].append((a.name,curves,[(m.name,m.frame) for m in a.pose_markers]))
    return hashlib.sha256(json.dumps(data,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def target_for(unit):
    if unit == 'griffon_rider_v1':
        return Vector((0,-.28,1.61))
    if 'cavalier' in unit:
        return Vector((0,-.25,1.45))
    return Vector((0,-.10,.92))


def render_views(scene, unit, out, names):
    out.mkdir(parents=True,exist_ok=True)
    camera = scene.camera
    assert camera is not None, unit
    saved = (camera.matrix_world.copy(), scene.render.resolution_x,scene.render.resolution_y,
             scene.render.resolution_percentage,scene.render.filepath,scene.cycles.samples)
    try:
        scene.render.resolution_x = scene.render.resolution_y = 720
        scene.render.resolution_percentage = 100
        scene.cycles.samples = 16
        target = target_for(unit)
        for name in names:
            camera.location = target + Vector(VIEWS[name])
            camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath = str(out/(name+'.png'))
            bpy.ops.render.render(write_still=True)
    finally:
        camera.matrix_world = saved[0]
        (scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage,
         scene.render.filepath,scene.cycles.samples) = saved[1:]


parser = argparse.ArgumentParser()
parser.add_argument('--units',nargs='+')
parser.add_argument('--views',nargs='+',default=['three_quarter','front','back','game_top'])
parser.add_argument('--compare',action='store_true')
parser.add_argument('--no-render',action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
if args.no_render:
    args.views = []
rows = json.loads((WORK/'native_audit.json').read_text(encoding='utf-8'))
results = []
for row in rows:
    unit = row['unit']
    if row.get('legacy') or (args.units and unit not in args.units):
        continue
    out = WORK/'staged'/unit
    source = WORK/'before'/unit/(unit+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = next(s for s in bpy.data.scenes if s.camera)
    before = signature(scene)
    if args.compare:
        render_views(scene,unit,WORK/'review_before'/unit,args.views)
    old = next(im for im in bpy.data.images if im.name == next(i['name'] for i in row['images'] if 'albedo' in i['name'].lower()))
    expected_name = old.name
    new = bpy.data.images.load(str(out/(unit+'_albedo.png')),check_existing=False)
    new.colorspace_settings.name = old.colorspace_settings.name
    assert list(new.size) == list(old.size)
    old.user_remap(new)
    bpy.data.images.remove(old)
    new.name = expected_name
    new.pack()
    new.filepath = str(out/(unit+'_albedo.png'))
    for image in bpy.data.images:
        if image.name.lower().endswith('_emission'):
            emission = unit+'_emission.png'
            shutil.copy2(WORK/'before'/unit/emission,out/emission)
            image.filepath = str(out/emission)
    assert bytes(new.packed_file.data) == (out/(unit+'_albedo.png')).read_bytes()
    if args.views:
        render_views(scene,unit,out/'previews',args.views)
    assert signature(scene) == before, unit+': scene changed outside textures'
    bpy.data.libraries.write(str(out/(unit+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    bpy.ops.wm.open_mainfile(filepath=str(out/(unit+'.blend')))
    saved_scene = next(s for s in bpy.data.scenes if s.camera)
    assert signature(saved_scene) == before, unit+': saved source differs'
    im = next(im for im in bpy.data.images if im.name == expected_name)
    assert bytes(im.packed_file.data) == (out/(unit+'_albedo.png')).read_bytes()
    assert Path(bpy.path.abspath(im.filepath)).resolve() == (out/(unit+'_albedo.png')).resolve()
    results.append({'unit':unit,'geometry_uv_skinning_animation_digest':before,
                    'source_geometry_uv_skinning_animations_unchanged':True,'packed_albedo_matches_png':True,
                    'portable_relative_texture_paths':True,
                    'views':sorted(p.stem for p in (out/'previews').glob('*.png'))})
    print('PACKED_VALIDATED',unit,flush=True)
(WORK/('native_validation_'+('_'.join(args.units) if args.units else 'all')+'.json')).write_text(json.dumps(results,indent=2),encoding='utf-8')
