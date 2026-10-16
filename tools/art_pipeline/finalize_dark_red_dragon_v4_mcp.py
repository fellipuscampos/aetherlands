"""Mirror the right thumb forward, re-export the reviewed model and refresh previews."""
import bpy,bmesh,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='dark_red_dragon_v4'
st=bpy.app.driver_namespace[STEM]
scene=st['scene']; rig=st['rig']; root=st['root']; parts=st['parts']; OUT=st['out']
bpy.context.window.scene=scene
by_name={obj['part']:obj for obj in parts}
left=by_name['Wing_thumb_L']; right=by_name['Wing_thumb_R']
for a,b in zip(left.data.vertices,right.data.vertices): b.co=Vector((-a.co.x,a.co.y,a.co.z))
bm=bmesh.new(); bm.from_mesh(right.data)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(right.data); bm.free(); right.data.update()
material=parts[0].data.materials[0]
helper=(ROOT/'tools/art_pipeline/build_elemental_dragon_mcp.py').read_text(encoding='utf-8')
start=helper.index('# Runtime: one material'); end=helper.index('\ndef aim(obj,point):',start)
exec(compile(helper[start:end],'dragon_runtime_export','exec'),globals())
exec(compile((ROOT/'tools/art_pipeline/validate_dark_red_dragon_v4_mcp.py').read_text(encoding='utf-8'),'dragon_validation','exec'),globals())
def aim(obj,p): obj.rotation_euler=(Vector(p)-obj.location).to_track_quat('-Z','Y').to_euler()
camera=scene.camera; scene.cycles.samples=24
for view,pos in [('three_quarter',(6,-10,5.2)),('front',(0,-10,3.1)),('side',(10,0,3.5)),('game_top',(5,-8,9))]:
    camera.location=pos; aim(camera,(.18,.04,1.73)); scene.render.filepath=str(OUT/'previews'/(view+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location=(6,-10,5.2); aim(camera,(.18,.04,1.73))
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        area.spaces.active.overlay.show_overlays=False
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print('Reviewed V4 saved and exported')
