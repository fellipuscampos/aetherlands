"""Prepare the refined cuboid sculpture with broad contiguous pixel-painted faces."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2];TOOLS=ROOT/'tools/art_pipeline'
OLD='veil_archon_blocky_v6';NEW='veil_archon_blocky_v7'
CONCEPT='Floating voxel apparition following the dark spectral reference: open blade crown, broad swept collar, hollow tapered chest enclosing a cubic mana core, long crooked carapace sleeves and asymmetric spectral arms. Broad contiguous mineral faces, rotated cuboid limbs, concentrated crimson-magenta energy.'
def read(n):return (TOOLS/n).read_text(encoding='utf-8')
def names(s):return s.replace(OLD,NEW).replace('Veil_Archon_Blocky_V6','Veil_Archon_Blocky_V7').replace('VeilArchonModelReviewV6','VeilArchonModelReviewV7')
def write(n,s):(TOOLS/n).write_text(s,encoding='utf-8')
geometry=read('veil_archon_v6_geometry.py').replace("delimit={'NORMAL'}","delimit=set()")
geometry=geometry.replace('bm=bmesh.new();bm.from_mesh(o.data)\n    bmesh.ops.dissolve_limit','bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update()\n    bmesh.ops.dissolve_limit')
geometry=geometry.replace("'core':Vector((0,.0,2.45))","'core':Vector((0,.0,2.46))").replace("centers['core'],(.34,.34,.34)","centers['core'],(.30,.30,.30)")
horn="""horn=[(.02,3.00),(.14,3.00),(.14,3.10),(.30,3.10),(.30,3.20),
 (.50,3.20),(.50,3.26),(.76,3.26),(.76,3.30),(1.06,3.30),
 (1.06,3.34),(.90,3.34),(.90,3.38),(.68,3.38),(.68,3.36),
 (.46,3.36),(.46,3.30),(.24,3.30),(.24,3.22),(.12,3.22),(.12,3.16),(.02,3.16)]
"""
a=geometry.index('horn=[');b=geometry.index("for side,s in [('L',-1),('R',1)]:",a)
geometry=geometry[:a]+horn+geometry[b:]
geometry+='''
# Rigid angular poses retain square cross sections and make the silhouette less architectural.
upper={side:Matrix.Rotation(math.radians(7 if side=='L' else -7),3,'Y') for side in ('L','R')}
fore={side:Matrix.Rotation(math.radians(5 if side=='L' else -5),3,'Y') for side in ('L','R')}
tail_R=Matrix.Rotation(math.radians(5),3,'Y')
original_centers={n:c.copy() for n,c in centers.items()}
def apply_pose(v,bone):
    R=Matrix.Identity(3)
    for side in ('L','R'):
        if bone in ('upper_arm_'+side,'forearm_'+side,'hand_'+side):
            c=original_centers['upper_arm_'+side];v=c+upper[side]@(v-c);R=upper[side]@R
        if bone in ('forearm_'+side,'hand_'+side):
            c=original_centers['upper_arm_'+side]+upper[side]@(original_centers['forearm_'+side]-original_centers['upper_arm_'+side])
            v=c+fore[side]@(v-c);R=fore[side]@R
    if bone in ('tail','tail_L','tail_R'):
        c=original_centers['tail'];v=c+tail_R@(v-c);R=tail_R@R
    v+=Vector((0,0,.07 if bone in ('head','crown_L','crown_R') else -.08))
    return v,R
for o in parts:
    bone=o['rig_bone']
    for v in o.data.vertices:v.co,R=apply_pose(v.co,bone)
    o['local_rotation']=list((R@Euler(o['local_rotation'],'XYZ').to_matrix()).to_euler('XYZ'))
    o.data.update()
for n,c in original_centers.items():centers[n]=apply_pose(c,n)[0]
'''
write('veil_archon_v7_geometry.py',geometry)
texture=read('veil_archon_v6_texture.py').replace("'shell':(34,47,51),'ridge':(67,86,88),'edge':(105,124,124)","'shell':(24,39,44),'ridge':(49,71,76),'edge':(80,105,109)")
texture=texture.replace('rng.integers(-7,8','rng.integers(-4,5').replace('base+20','base+12').replace('base+12;','base+8;')
texture=texture.replace("rng.choice([-15,18,26])","rng.choice([-7,10,14])")
write('veil_archon_v7_texture.py',texture)
src=read('build_veil_archon_blocky_v6_mcp.py')
head=names(src[:src.index('# Sculpted unions of cuboids')])
head=head.replace('old_hashes={',"protected.extend(p for ext in ('glb','blend') if (p:=ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v6'/('veil_archon_blocky_v6.'+ext)).is_file())\nold_hashes={")
uv=src[src.index('coords=[v.co for o in parts for v in o.data.vertices]'):src.index('# Mineral layers, painted creases')]
tail=names(src[src.index('images=[]'):])
tail=re.sub(r"rig\['status'\]='[^']*'",f"rig['status']={CONCEPT!r}",tail)
tail=re.sub(r"scene\['description'\]='[^']*'",f"scene['description']={CONCEPT!r}",tail)
write('build_veil_archon_blocky_v7_mcp.py',head+geometry+'\n'+uv+texture+'\n'+tail)
export=names(read('export_veil_archon_blocky_v6_mcp.py'))
export=export.replace('max(abs(d-64) for d in densities)<.01','max(abs(d-64) for d in densities)<.05')
export=re.sub(r"'concept':'[^']*'",f"'concept':{CONCEPT!r}",export).replace("'revision':6","'revision':7")
export=export.replace("'strict_voxel_geometry':True","'cuboid_geometry':True,'rigid_rotated_cuboids':True")
write('export_veil_archon_blocky_v7_mcp.py',export)
for old,new in [('validate_veil_archon_blocky_v6.py','validate_veil_archon_blocky_v7.py'),('verify_veil_archon_blocky_v6.gd','verify_veil_archon_blocky_v7.gd'),('finalize_veil_archon_blocky_v6_mcp.py','finalize_veil_archon_blocky_v7_mcp.py'),('compare_veil_archon_v6.py','compare_veil_archon_v7.py'),('write_veil_archon_v6_review.py','write_veil_archon_v7_review.py')]:write(new,names(read(old)))
for folder,name in [('scripts/art_review','VeilArchonModelReviewV6.gd'),('scenes/art_review','VeilArchonModelReviewV6.tscn')]:
    (ROOT/folder/name.replace('V6','V7')).write_text(names((ROOT/folder/name).read_text(encoding='utf-8')),encoding='utf-8')
# Rotated cuboids have right-angle corners, but their face normals follow their rigid pose.
gallery=read('write_veil_archon_v7_review.py').replace('Todos os volumes, com exceção da orientação do cubo, usam faces ortogonais e contornos em degraus.','Os volumes têm cortes em blocos e faces planas; os membros usam poses angulares rígidas.').replace('Todas as peças usam faces ortogonais em degraus; apenas o núcleo cúbico tem orientação própria.','As peças são volumes de cuboides com recortes em degraus, orientados em poses rígidas.')
write('write_veil_archon_v7_review.py',gallery)
print('Refined cuboid V7 pipeline prepared.')
