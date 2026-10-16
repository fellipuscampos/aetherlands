"""Create the focused skull/vestment revision while preserving V1 and its review."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TOOLS=ROOT/'tools/art_pipeline'
def revised(text):
    return text.replace('elder_lich_blocky_v1','elder_lich_blocky_v2').replace('Elder_Lich_Blocky_V1','Elder_Lich_Blocky_V2').replace('ElderLichModelReview','ElderLichModelReviewV2')

source=revised((TOOLS/'build_elder_lich_blocky_v1_mcp.py').read_text(encoding='utf-8'))
source=source.replace(source.splitlines()[0],'"""Ancient spectral mage: current skeleton skull and worn purple pixel vestments."""')
source=source.replace("if bpy.context.screen.is_animation_playing:","if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')\nif bpy.context.screen.is_animation_playing:",1)
anchor="old_hashes={str(p.relative_to(ROOT))"
extra="""for relative in [
    'assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1.glb',
    'assets/generated/humans/human_necromancer_v1/human_necromancer_v1.glb',
    'assets/generated/grand_manifestations/elder_lich_blocky_v1/elder_lich_blocky_v1.glb',
    'assets/generated/grand_manifestations/elder_lich_blocky_v1/elder_lich_blocky_v1.blend']:
    protected.append(ROOT/relative)
"""
source=source.replace(anchor,extra+anchor,1)
source=source.replace("box('Skull_Jaw',(0,-.047,2.535),(.292,.290,.067),'head','bone')", "box('Skull_Jaw',(0,-.077,2.507),(.314,.264,.095),'head','bone')")
start=source.index("palette={'cloth'")
end=source.index('images=[]',start)
source=source[:start]+(TOOLS/'elder_lich_v2_texture.py.inc').read_text(encoding='utf-8')+'\n'+source[end:]
source=source.replace('# One metric nearest-filtered atlas with old slate/iron, square wear and woven red stoles.', '# Metric pixel atlas: aged ivory skull and purple cloth, 64 pixels per meter.')
(TOOLS/'build_elder_lich_blocky_v2_mcp.py').write_text(source,encoding='utf-8')
for name in ['export_elder_lich_blocky_v1_mcp.py','validate_elder_lich_blocky_v1.py','verify_elder_lich_blocky_v1.gd','finalize_elder_lich_blocky_v1_mcp.py']:
    text=revised((TOOLS/name).read_text(encoding='utf-8'))
    text=text.replace('static archdemon','static elder lich').replace('archdemon_static_validation_', 'elder_lich_v2_validation_')
    if name.startswith('export'):
        text=text.replace('assets/generated/skeletons/skeleton_blocky','assets/generated/skeletons/skeleton_warrior_v1')
        text=text.replace("'source_scenes':1", "'revision':2,'changes':['Current Skeleton Warrior skull sockets, nasal cavity, teeth and separate jaw','Purple pixel cloth with folds and worn hems; human necromancer palette'],'previous_version':'elder_lich_blocky_v1','source_scenes':1")
        text=text.replace("'assets/generated/skeletons/skeleton_warrior_v1'],", "'assets/generated/skeletons/skeleton_warrior_v1',\n                  'assets/generated/grand_manifestations/seraph_blocky_v4_animated',\n                  'assets/generated/grand_manifestations/archdemon_blocky_v5_animated'],")
    (TOOLS/name.replace('v1','v2')).write_text(text,encoding='utf-8')
for relative in ['scripts/art_review/ElderLichModelReview.gd','scenes/art_review/ElderLichModelReview.tscn']:
    original=ROOT/relative
    target=original.with_name(original.name.replace('ModelReview','ModelReviewV2'))
    target.write_text(revised(original.read_text(encoding='utf-8')),encoding='utf-8')
comparison=(TOOLS/'compare_elder_lich_style.py').read_text(encoding='utf-8')
comparison=comparison.replace("'art_source/elder_lich_style_review'", "'art_source/elder_lich_blocky_v2_review'")
comparison=comparison.replace('Lich Ancião V1','Lich Ancião V2').replace('elder_lich_blocky_v1/elder_lich_blocky_v1.glb','elder_lich_blocky_v2/elder_lich_blocky_v2.glb')
comparison=comparison.replace('compare_elder_lich_style.gd','compare_elder_lich_v2_style.gd')
(TOOLS/'compare_elder_lich_v2_style.py').write_text(comparison,encoding='utf-8')
comparison_gd=(TOOLS/'compare_elder_lich_style.gd').read_text(encoding='utf-8').replace('comparison_before.png','comparison_after.png')
anchor='\troot.size=Vector2i(3600,1200)'
detail='''\tvar lich: Node3D = models["lich"]
\tlich.visible = true
\tvar skull_center := Vector3(0, 2.79, 0)
\tcamera.size = 1.12
\tcamera.position = skull_center + Vector3(3, 2.43, 10)
\tcamera.look_at(skull_center)
\tfor frame in 5: await process_frame
\tawait RenderingServer.frame_post_draw
\tassert(root.get_texture().get_image().save_png(destination.path_join("skull_detail.png")) == OK)
\tlich.visible = false
'''
comparison_gd=comparison_gd.replace(anchor,detail+anchor)
(TOOLS/'compare_elder_lich_v2_style.gd').write_text(comparison_gd,encoding='utf-8')
print('Prepared separate Lich V2 builder, export, review and native validation.')
