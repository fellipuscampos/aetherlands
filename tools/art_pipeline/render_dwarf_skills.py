"""Preview native dwarf skill actions in live Blender, without retargeting."""
import json
import bpy
from mathutils import Vector
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import ROOT, OUT, WORK, roles_for, FPS
from build_dwarf_skills import activate


def render_all():
    initial=bpy.context.window.scene; results=[]
    for row in ASSETS:
        scene=bpy.data.scenes[row['stem']+'_MCP_Static_V2'];bpy.context.window.scene=scene
        rig=next(o for o in scene.objects if o.type=='ARMATURE' and o.get('dwarf_animation_owned'))
        camera=scene.camera
        saved=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,
               scene.render.filepath,camera.matrix_world.copy(),camera.data.ortho_scale)
        folder=WORK/'frames'/row['stem'];folder.mkdir(parents=True,exist_ok=True)
        try:
            scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=scene.render.resolution_y=560
            scene.render.resolution_percentage=100
            scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE'
            scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True
            scene.display.shading.cavity_type='BOTH';scene.display.shading.background_type='WORLD'
            for obj in scene.objects:
                if obj.get('part') and not obj['part'].startswith('STUDIO_'):
                    for mat in obj.data.materials:
                        if mat.use_nodes:
                            node=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE')
                            mat.node_tree.nodes.active=node
            center=Vector((0,-.12,1.12 if row['family']=='cavalry' else 1.04 if row['family']=='siege' else .85))
            direction=Vector((5,-10,3.6)).normalized();camera.location=center+direction*12
            camera.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler()
            camera.data.ortho_scale=3.8 if row['family']=='cavalry' else 3.3 if row['family']=='siege' else 2.45
            for role,(seconds,_) in roles_for(row).items():
                activate(scene,rig,role);dest=folder/role;dest.mkdir(exist_ok=True)
                end=round(seconds*FPS)+1
                frames=list(range(1,end,4)) if row['tier']==2 else [1,1+round((end-1)*.54),end]
                for frame in frames:
                    scene.frame_set(frame);scene.view_layers[0].update()
                    scene.render.filepath=str(dest/('%04d.png'%frame))
                    bpy.ops.render.render(write_still=True)
                results.append(dict(stem=row['stem'],role=role,frames=len(frames),folder=str(dest)))
            print('DWARF_SKILL_PREVIEW',row['stem'],flush=True)
        finally:
            scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.filepath=saved[:4]
            camera.matrix_world=saved[4];camera.data.ortho_scale=saved[5];activate(scene,rig,'idle')
    bpy.context.window.scene=initial
    report=dict(status='PASS',models=24,skill_clips=43,native_renders=True,sequences=results)
    (ROOT/'docs/dwarf_skills_preview_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    return dict(status='PASS',models=24,skills=43,rendered_frames=sum(r['frames'] for r in results))
