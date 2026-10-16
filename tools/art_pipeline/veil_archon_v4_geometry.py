# A continuous floating armored apparition, following the second user reference.
centers={'body':Vector((0,.04,1.90)), 'chest':Vector((0,.03,2.54)),
 'head':Vector((0,.02,3.07)), 'halo':Vector((0,.02,3.40)),
 'core':Vector((0,-.28,2.49)), 'tail':Vector((0,.055,1.52)),
 'tail_L':Vector((-.25,.12,1.63)), 'tail_R':Vector((.25,.12,1.63))}
parents={'body':'root','chest':'body','head':'chest','halo':'head','core':'chest',
 'tail':'body','tail_L':'body','tail_R':'body'}
for side,s in [('L',-1),('R',1)]:
    for name,c,parent in [
      ('shoulder',(s*.69,.025,2.88),'chest'),
      ('upper_arm',(s*.91,.025,2.71),'chest'),
      ('forearm',(s*1.08,-.03,2.02),'upper_arm_'+side),
      ('hand',(s*1.12,-.08,1.20),'forearm_'+side)]:
        centers[name+'_'+side]=Vector(c); parents[name+'_'+side]=parent

def loft(label,rings,bone,kind='armor'):
    # Eight flat facets per section: thick in depth, square cuts, no rounded bevels.
    vs=[]
    for z,w,d,y in rings:
        cut=min(w,d)*.22
        vs.extend((x,y+q,z) for x,q in [(-w+cut,-d),(w-cut,-d),(w,-d+cut),
          (w,d-cut),(w-cut,d),(-w+cut,d),(-w,d-cut),(-w,-d+cut)])
    fs=[tuple(reversed(range(8))),tuple(range((len(rings)-1)*8,len(rings)*8))]
    for k in range(len(rings)-1):
        for i in range(8):
            a=k*8+i;b=k*8+(i+1)%8;c=(k+1)*8+(i+1)%8;d=(k+1)*8+i
            fs.extend([(a,b,c),(a,c,d)])
    return mesh_part(label,vs,fs,bone,kind)

# The back and lower torso form one tapering silhouette, not a skeleton or robe.
loft('Dark_Central_Cuirass',[(1.46,.17,.13,.20),(1.93,.25,.19,.20),
 (2.38,.33,.20,.20),(2.82,.40,.19,.22)],'chest')
loft('Long_Suspended_Body_Point',[(.32,.035,.035,.11),(.64,.075,.060,.09),
 (1.02,.14,.09,.08),(1.45,.23,.13,.08),(1.80,.30,.16,.09)],'tail')

for side,s in [('L',-1),('R',1)]:
    # Broad collar tips flare outward, then fold down into the chest.
    collar=[(.18,2.83),(.56,2.71),(.94,2.85),(1.12,3.06),(.72,2.99),(.30,3.08)]
    prism(side+'_Swept_Collar',[(s*x,z) for x,z in collar],.36,(0,-.06,0),'shoulder_'+side,'edge')
    chest=[(.30,2.78),(.68,2.82),(.61,2.51),(.49,2.30),(.32,2.18),(.28,2.31)]
    prism(side+'_Open_Pectoral_Plate',[(s*x,z) for x,z in chest],.21,(0,-.095,0),'chest','armor')
    trim=[(.35,2.78),(.67,2.83),(.65,2.76),(.36,2.69)]
    prism(side+'_Collar_Azure_Seam',[(s*x,z) for x,z in trim],.022,(0,-.255,0),'shoulder_'+side,'facet')
    waist=[(.10,1.58),(.30,1.73),(.46,2.11),(.31,2.21),(.22,1.97),(.10,1.83)]
    prism(side+'_Waist_Sweep',[(s*x,z) for x,z in waist],.23,(0,-.11,0),'body','edge')
    waistglow=[(.23,1.80),(.33,1.91),(.41,2.10),(.365,2.15),(.29,1.96)]
    prism(side+'_Waist_Mana_Inlay',[(s*x,z) for x,z in waistglow],.019,(0,-.237,0),'body','energy')
    # Two articulated armor segments with exposed mana links; square palms below.
    beam(side+'_Upper_Arm_Mana_Link',(s*.90,.035,2.70),(s*1.08,-.03,2.02),.11,.10,'upper_arm_'+side,'energy')
    upper=[(.76,2.55),(.93,2.79),(1.10,2.64),(1.03,2.21),(1.13,2.06),(.97,2.01),(.84,2.22)]
    prism(side+'_Upper_Arm_Casing',[(s*x,z) for x,z in upper],.30,(0,.04,0),'upper_arm_'+side,'armor')
    # Only one outward spur per arm, rather than a cloud of spines.
    spur=[(1.03,2.39),(1.17,2.47),(1.29,2.67),(1.25,2.38),(1.12,2.23)]
    prism(side+'_Elbow_Swept_Spur',[(s*x,z) for x,z in spur],.19,(0,.075,0),'upper_arm_'+side,'edge')
    beam(side+'_Forearm_Mana_Link',(s*1.08,-.03,2.02),(s*1.12,-.08,1.19),.10,.10,'forearm_'+side,'energy')
    lower=[(.98,1.87),(1.14,2.00),(1.27,1.84),(1.28,1.43),(1.18,1.17),(.99,1.35),(.95,1.60)]
    prism(side+'_Long_Angular_Vambrace',[(s*x,z) for x,z in lower],.33,(0,-.02,0),'forearm_'+side,'armor')
    front=[(1.025,1.45),(1.10,1.53),(1.14,1.92),(1.10,1.94),(1.035,1.75)]
    prism(side+'_Forearm_Azure_Seam',[(s*x,z) for x,z in front],.021,(0,-.198,0),'forearm_'+side,'facet')
    box(side+'_Square_Floating_Hand',(s*1.115,-.08,1.11),(.205,.23,.24),'hand_'+side,'edge')
    # The outer gauntlet flows into a single clipped blade, keeping the silhouette sinister.
    cuff=[(1.20,1.50),(1.31,1.61),(1.30,1.09),(1.17,.91),(1.13,.91),(1.20,1.21)]
    prism(side+'_Gauntlet_Downward_Blade',[(s*x,z) for x,z in cuff],.19,(0,.095,0),'hand_'+side,'armor')
    skirt=[(.21,1.67),(.40,1.77),(.45,1.52),(.34,1.04),(.29,.87),(.25,1.21)]
    prism(side+'_Lower_Armor_Fin',[(s*x,z) for x,z in skirt],.18,(0,.13,0),'tail_'+side,'armor')

# One simple cubic mana core floats in the open upper chest.
box('Azure_Mana_Core',centers['core'],(.29,.29,.29),'core','core',
    Euler((math.radians(12),math.radians(18),math.radians(14))).to_matrix())

# An abstract face plate with one narrow blue slit replaces the skull completely.
loft('Faceless_Crown_Mask',[(2.96,.07,.09,-.01),(3.09,.16,.12,-.01),
 (3.24,.20,.11,.0)],'head','edge')
box('Single_Crown_Light_Slit',(0,-.141,3.135),(.18,.015,.025),'head','energy')
beam('Crown_Neck_Energy',(0,.05,2.85),(0,.05,3.02),.075,.075,'head','energy')

def crown_annulus(label,outer,inner,z,thickness,kind):
    n=len(outer)
    vs=[(x,y,z+dz) for dz in (-thickness/2,thickness/2) for ring in (outer,inner) for x,y in ring]
    fs=[]
    for i in range(n):
        j=(i+1)%n
        fs.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
          (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    return mesh_part(label,vs,fs,'halo',kind)

# A broad horizontal octagonal blade halo, strongly visible from the game's camera.
outer=[(-.82,-.08),(-.59,-.30),(.59,-.30),(.82,-.08),(.82,.08),(.59,.30),(-.59,.30),(-.82,.08)]
inner=[(-.62,-.035),(-.47,-.19),(.47,-.19),(.62,-.035),(.62,.035),(.47,.19),(-.47,.19),(-.62,.035)]
crown_annulus('Wide_Horizontal_Crown',outer,inner,3.39,.065,'edge')
glow_outer=[(x*.98,y*.98) for x,y in outer]
glow_inner=[(x*1.045,y*1.10) for x,y in inner]
crown_annulus('Crown_Azure_Surface',glow_outer,glow_inner,3.426,.015,'energy')
for side,s in [('L',-1),('R',1)]:
    profile=[(.61,3.34),(.92,3.41),(.92,3.445),(.73,3.465),(.57,3.42)]
    prism(side+'_Crown_Swept_Tip',[(s*x,z) for x,z in profile],.085,(0,0,0),'halo','energy')
