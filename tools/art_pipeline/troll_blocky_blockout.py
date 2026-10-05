"""Stage 1 only: rectangular blockout in Blender MCP. No texture or rig."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
SOURCE=ROOT/'art_source/troll_blocky_v3'
OUT=ROOT/'assets/generated/trolls/troll_blocky_v3'
SOURCE.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').write_text('',encoding='utf-8')
NAME='Troll_Blocky_V3'; S=2.5/3.9
if NAME in bpy.data.scenes: raise RuntimeError('Blockout already exists: do not replace manual edits.')
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
parts=bpy.data.collections.new(NAME+'_01_CHARACTER'); studio=bpy.data.collections.new(NAME+'_02_STUDIO')
scene.collection.children.link(parts); scene.collection.children.link(studio)
clay=bpy.data.materials.new(NAME+'_Blockout_Clay'); clay.diffuse_color=(.42,.49,.49,1)
bone_specs={
 'root':((0,0,0),(0,0,.25),None),
 'pelvis':((0,0,1.30),(0,0,1.63),'root'),
 'spine_01':((0,0,1.63),(0,.04,2.22),'pelvis'),
 'chest':((0,.04,2.22),(0,.15,3.23),'spine_01'),
 'neck':((0,.15,3.23),(0,-.31,3.38),'chest'),
 'head':((0,-.31,3.38),(0,-.31,3.86),'neck'),
 'jaw':((0,-.48,3.34),(0,-.80,3.17),'head')}

def mesh(name,verts,faces,bone,region,kind='cuboid'):
    data=bpy.data.meshes.new(NAME+'_'+name+'_mesh'); data.from_pydata([Vector(v)*S for v in verts],[],faces); data.update()
    obj=bpy.data.objects.new(NAME+'_'+name,data); parts.objects.link(obj); data.materials.append(clay)
    for p in data.polygons: p.use_smooth=False
    obj['bone']=bone; obj['region']=region; obj['construction']=kind
    return obj

def box(name,center,size,bone,region,angle=0):
    c=Vector(center); a,b,d=[n/2 for n in size]
    verts=[]
    for sz in (-1,1):
        for sy in (-1,1):
            for sx in (-1,1):
                p=Vector((sx*a,sy*b,sz*d))
                p=Vector((math.cos(angle)*p.x+math.sin(angle)*p.z,p.y,-math.sin(angle)*p.x+math.cos(angle)*p.z))
                verts.append(c+p)
    return mesh(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],bone,region)

def beam(name,start,end,width,depth,bone,region):
    start,end=Vector(start),Vector(end); axis=(end-start).normalized()
    u=Vector((0,1,0)).cross(axis).normalized(); v=axis.cross(u).normalized()
    verts=[c+u*x*width/2+v*y*depth/2 for c in (start,end) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],bone,region)

# Three distinct rectangular trunk masses. Legs start below the pelvis.
box('Chest',(0,.15,2.82),(1.94,1.0,1.10),'chest','chest')
box('Abdomen',(0,.06,1.985),(1.35,.79,.57),'spine_01','abdomen')
box('Pelvis',(0,.045,1.505),(1.18,.72,.39),'pelvis','hide')
box('Back_Hump',(0,.50,3.26),(1.34,.57,.37),'chest','back')
box('Neck',(0,-.15,3.35),(.54,.53,.29),'neck','skin')
box('Head',(0,-.49,3.535),(.88,.83,.73),'head','face')
box('Jaw',(0,-.645,3.165),(.88,.76,.24),'jaw','jaw')
box('Nose',(0,-.958,3.47),(.28,.23,.34),'head','nose')
for side,suffix in [(1,'l'),(-1,'r')]:
    shoulder=(side*1.05,.14,3.08); elbow=(side*1.25,.04,2.30); wrist=(side*1.43,-.08,1.40)
    hip=(side*.38,.035,1.315); knee=(side*.47,.00,.75); ankle=(side*.49,.02,.22)
    bone_specs['shoulder_'+suffix]=((side*.26,.14,3.08),shoulder,'chest')
    bone_specs['upper_arm_'+suffix]=(shoulder,elbow,'shoulder_'+suffix)
    bone_specs['forearm_'+suffix]=(elbow,wrist,'upper_arm_'+suffix)
    bone_specs['hand_'+suffix]=(wrist,(side*1.47,-.10,1.12),'forearm_'+suffix)
    bone_specs['thigh_'+suffix]=(hip,knee,'pelvis')
    bone_specs['shin_'+suffix]=(knee,ankle,'thigh_'+suffix)
    bone_specs['foot_'+suffix]=(ankle,(side*.49,-.45,.14),'shin_'+suffix)
    box('Shoulder_'+suffix,(side*1.055,.15,3.10),(.70,.93,.56),'upper_arm_'+suffix,'shoulder')
    beam('UpperArm_'+suffix,(side*1.08,.14,3.02),elbow,.58,.68,'upper_arm_'+suffix,'upper_arm')
    box('Elbow_'+suffix,elbow,(.44,.49,.30),'forearm_'+suffix,'skin')
    beam('Forearm_'+suffix,(side*1.255,.04,2.33),(side*1.43,-.08,1.40),.68,.75,'forearm_'+suffix,'forearm')
    box('Hand_'+suffix,(side*1.46,-.09,1.175),(.73,.78,.48),'hand_'+suffix,'hand')
    box('Thumb_'+suffix,(side*1.095,-.30,1.22),(.18,.30,.25),'hand_'+suffix,'skin')
    beam('Thigh_'+suffix,(side*.38,.035,1.30),(side*.47,0,.77),.55,.63,'thigh_'+suffix,'thigh')
    box('Knee_'+suffix,knee,(.42,.47,.24),'shin_'+suffix,'skin')
    beam('Shin_'+suffix,(side*.47,.005,.79),(side*.49,.02,.23),.48,.53,'shin_'+suffix,'shin')
    box('Foot_'+suffix,(side*.49,-.205,.145),(.65,.97,.29),'foot_'+suffix,'foot')
    box('Brow_'+suffix,(side*.245,-.925,3.68),(.40,.13,.13),'head','brow',side*-.16)
    # Angular ears and prism-cut tusks are the only non-cuboid shapes.
    verts=[(side*.43,-.38,3.62),(side*.85,-.29,3.79),(side*.70,-.32,3.49),
           (side*.43,-.23,3.62),(side*.85,-.18,3.79),(side*.70,-.21,3.49)]
    mesh('Ear_'+suffix,verts,[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],'head','ear','triangular_prism')
    beam('TuskBase_'+suffix,(side*.32,-1.01,3.21),(side*.54,-1.045,3.18),.15,.15,'jaw','bone')
    a=(side*.54,-1.045,3.18); b=(side*.71,-1.03,3.48 if side==1 else 3.43)
    verts=[(a[0]+dx*.075,a[1]+dy*.075,a[2]) for dy in (-1,1) for dx in (-1,1)]
    verts += [(b[0]+dx*.022,b[1]+dy*.03,b[2]) for dy in (-1,1) for dx in (-1,1)]
    mesh('TuskTip_'+suffix,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],'jaw','bone','tapered_prism')

# Front flap starts at the pelvis, with room for two clearly separate thighs.
box('Belt',(0,.035,1.57),(1.24,.80,.15),'pelvis','belt')
box('HideFront',(-.04,-.407,1.285),(.69,.055,.49),'pelvis','hide')
box('HideSide_l',(.607,.035,1.285),(.055,.70,.42),'pelvis','hide')
box('HideSide_r',(-.607,.035,1.33),(.055,.70,.33),'pelvis','hide')
box('HideBack',(0,.448,1.30),(.95,.055,.42),'pelvis','hide')

grip=Vector((-1.46,-.19,1.18)); tip=Vector((-2.23,-.95,.63)); axis=(tip-grip).normalized()
bone_specs['weapon']=(tuple(grip),tuple(grip+axis*.55),'hand_r')
beam('Club_Handle',grip-axis*.24,grip+axis*.68,.20,.20,'weapon','wood')
beam('Club_Head',grip+axis*.57,grip+axis*1.37,.51,.51,'weapon','wood')
beam('Club_End',grip+axis*1.37,grip+axis*1.39,.51,.51,'weapon','endgrain')
scene['bone_specs']=json.dumps(bone_specs)
scene['blockout_reviewed']=False

camdata=bpy.data.cameras.new(NAME+'_Camera'); cam=bpy.data.objects.new(NAME+'_Camera',camdata); studio.objects.link(cam)
camdata.type='ORTHO'; camdata.ortho_scale=3.4; scene.camera=cam
def aim(pos):
    cam.location=pos; cam.rotation_euler=(Vector((-.23,-.08,1.24))-cam.location).to_track_quat('-Z','Y').to_euler()
aim((4,-8,3.8))
scene.render.engine='BLENDER_WORKBENCH'; scene.render.resolution_x=1000; scene.render.resolution_y=1000
scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
shading=scene.display.shading; shading.light='STUDIO'; shading.color_type='MATERIAL'
shading.show_shadows=True; shading.show_cavity=True; shading.cavity_type='BOTH'
shading.curvature_ridge_factor=1.3; shading.curvature_valley_factor=1.1
shading.background_type='WORLD'; scene.world=bpy.data.worlds.new(NAME+'_World'); scene.world.color=(.085,.085,.085)
scene.view_settings.view_transform='Standard'
scene.frame_set(1)
for obj in scene.objects: obj.select_set(False)
folder=SOURCE/'blockout'; folder.mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'troll_blocky_v3_blockout.blend'))
for view,pos in [('three_quarter',(4,-8,3.8)),('front',(0,-8,2.4)),('side',(8,0,2.8))]:
    aim(pos); scene.render.filepath=str(folder/(view+'.png')); bpy.ops.render.render(write_still=True)
aim((4,-8,3.8))
result={'stage':'BLOCKOUT_ONLY','parts':len(parts.objects),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in parts.objects),
        'previews':str(folder),'rig':False,'texture':False}
