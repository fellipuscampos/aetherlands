# An ancient root sovereign: contiguous sculpted bark masses, a broad asymmetrical silhouette.
centers={'body':Vector((0,.10,1.19)),'chest':Vector((0,.025,2.04)),
 'crown':Vector((0,-.015,2.45)),'core':Vector((.015,-.19,2.60)),
 'hanging_root_L':Vector((-.11,-.12,1.24)),'hanging_root_R':Vector((.13,.04,1.23))}
parents={'body':'root','chest':'body','crown':'chest','core':'chest','hanging_root_L':'body','hanging_root_R':'body'}
def splinter(label,a,b,width,bone,kind='wood'):
    a,b=Vector(a),Vector(b); length=(b-a).length; R=(b-a).to_track_quat('Z','Y').to_matrix()
    profile=[(-width/2,0),(width/2,0),(width/2,length*.38),(width*.28,length*.38),
      (width*.28,length*.74),(width*.10,length*.74),(width*.10,length),
      (-width*.10,length),(-width*.10,length*.74),(-width*.28,length*.74),(-width*.28,length*.38),(-width/2,length*.38)]
    return prism(label,profile,width*.75,a,bone,kind,R)
def root_path(label,points,width,depth,bone,kind='wood'):
    for i in range(len(points)-1): beam(label+'_'+str(i),points[i],points[i+1],width*(1-.075*i),depth,bone,kind)

# Solid stepped roots outline a narrow, deep abdominal opening. No scaffolding-sized strips.
for side,s in [('L',-1),('R',1)]:
    profile=[(s*x,z) for x,z in [(.10,1.14),(.44,1.14),(.44,1.42),(.58,1.42),(.58,1.82),(.74,1.82),
      (.74,2.18),(.57,2.35),(.32,2.26),(.22,2.04),(.30,1.78),(.25,1.47),(.09,1.36)]]
    prism(side+'_Ancient_Trunk_Wall',profile,.58,(0,.04,0),'chest','bark')
    root_path(side+'_Trunk_Heartwood',[(s*.31,-.30,1.26),(s*.40,-.30,1.59),(s*.40,-.30,1.96),(s*.49,-.29,2.17)],.16,.10,'chest','wood')
    beam(side+'_Back_Trunk', (s*.26,.39,1.22),(s*.37,.35,2.14),.22,.24,'chest','bark_dark')
prism('Root_Breastplate',[(-.66,2.28),(-.29,2.30),(0,2.13),(.33,2.30),(.66,2.30),(.52,2.09),(.18,1.95),(-.18,1.95),(-.53,2.08)],.24,(0,-.245,0),'chest','wood')
prism('Pelvic_Trunk',[(-.48,1.14),(-.50,1.37),(-.27,1.48),(.23,1.47),(.47,1.36),(.45,1.13),(.23,1.03),(-.23,1.04)],.57,(0,.025,0),'body','bark')
beam('Pelvic_Root_Wrap',(-.42,-.31,1.12),(.42,-.31,1.40),.19,.16,'body','wood')

# A continuous, irregular root crown grows out of the torso, not a segmented geometric ring.
left=[(-.18,2.01),(-.47,2.13),(-.72,2.43),(-.72,2.77),(-.58,2.77),(-.58,2.96),(-.32,3.17),(-.10,3.17),
 (-.10,3.29),(.08,3.29),(.08,3.11),(.30,3.11),(.30,2.96),(-.08,2.96),(-.35,2.80),(-.44,2.59),(-.40,2.39),(-.11,2.23)]
right=[(.12,2.02),(.43,2.17),(.65,2.41),(.65,2.71),(.51,2.91),(.34,3.06),(.16,3.06),(.16,2.88),(.33,2.73),(.38,2.57),(.31,2.37),(.04,2.23)]
prism('Sovereign_Crown_Left',left,.37,(0,-.01,0),'crown','bark')
prism('Sovereign_Crown_Right',right,.32,(0,.005,0),'crown','wood')
# Raised grain ridges follow the major root surfaces, with clear separation in value.
root_path('Crown_Left_Heartwood',[(-.23,-.206,2.18),(-.57,-.206,2.47),(-.55,-.206,2.78),(-.29,-.206,3.02),(.12,-.206,3.025)],.075,.035,'crown','wood_light')
root_path('Crown_Right_Dark_Cleft',[(.24,-.167,2.20),(.49,-.167,2.45),(.47,-.167,2.72),(.26,-.167,2.93)],.061,.027,'crown','bark_dark')
root_path('Rear_Crown_Root',[(-.43,.28,2.25),(-.48,.31,2.65),(-.27,.34,2.93),(.13,.33,2.96),(.43,.28,2.58)],.15,.18,'crown','bark_dark')
splinter('Crown_Left_Fork',(-.59,.045,2.85),(-.77,.08,3.18),.18,'crown','wood')
splinter('Crown_Right_Fork',(.49,.045,2.83),(.74,.08,3.13),.17,'crown','bark')
box('Exposed_Druidic_Core',centers['core'],(.445,.445,.445),'core','core',Euler((math.radians(14),math.radians(22),math.radians(17))).to_matrix())
# Root tendrils inside the chest emphasize depth while leaving the core fully visible.
for i,(x,y,bottom) in enumerate([(-.14,.07,1.44),(.13,.13,1.46),(.015,.26,1.37)]):
    root_path('Inner_Living_Root_'+str(i),[(x,y,2.23),(x*.7,y,1.93),(x*.8+.03,y,bottom)],.036,.038,'chest','vine')

# Enormous fused shoulder knots carry the silhouette. Left is higher and heavier.
for side,s in [('L',-1),('R',1)]:
    shoulder=Vector((s*.70,.015,2.22 if s<0 else 2.16)); elbow=Vector((s*.94,-.075,1.69)); wrist=Vector((s*1.07,-.28,1.045))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist}); parents.update({upper:'chest',fore:upper,hand:fore})
    # One irregular volumetric prism per mantle, not a plain square shoulder pad.
    profile=[(-.34,-.20),(.30,-.20),(.30,-.08),(.45,-.08),(.45,.20),(.32,.20),(.32,.39),(.12,.39),(.12,.51),(-.12,.51),(-.12,.36),(-.32,.36),(-.32,.16),(-.40,.16),(-.40,-.07),(-.34,-.07)]
    profile=[(s*x,z*(1.05 if s<0 else .86)) for x,z in profile]
    R=Euler((math.radians(-8),math.radians(-s*13),0)).to_matrix()
    prism(side+'_Great_Root_Shoulder',profile,.64,shoulder,upper,'bark',R)
    beam(side+'_Connected_Upper_Trunk',shoulder,elbow,.40,.44,upper,'bark_dark')
    beam(side+'_Upper_Arm_Outer_Root',shoulder+Vector((s*.12,-.15,-.02)),elbow+Vector((s*.12,-.15,.01)),.23,.19,upper,'wood')
    # Broad angular forearm tapers at the wrist, rather than many thin stick segments.
    a=elbow; b=wrist; length=(b-a).length; R=(b-a).to_track_quat('Z','Y').to_matrix()
    profile=[(-.26,-.06),(.26,-.06),(.26,.18),(.31,.18),(.31,length*.69),(.24,length*.69),(.24,length+.10),(-.23,length+.10),(-.23,length*.74),(-.30,length*.74),(-.30,.20),(-.26,.20)]
    prism(side+'_Massive_Root_Forearm',profile,.53,a,fore,'bark',R)
    beam(side+'_Forearm_Heartwood',elbow+Vector((-s*.12,-.305,-.10)),wrist+Vector((s*.10,-.28,.03)),.18,.075,fore,'wood')
    beam(side+'_Forearm_Cleft',elbow+Vector((s*.19,-.305,-.08)),wrist+Vector((s*.17,-.28,.07)),.038,.025,fore,'bark_dark')
    R=Euler((math.radians(-8),math.radians(s*8),math.radians(-s*4))).to_matrix()
    box(side+'_Single_Square_Hand',wrist+Vector((s*.025,-.07,-.21)),(.59,.57,.60),hand,'bark',R)
    box(side+'_Hand_Heartwood_Facet',wrist+Vector((s*.03,-.358,-.22)),(.37,.035,.43),hand,'wood',R)
    # Few strong branches produce a regal, threatening crown around the upper body.
    for i,(offset,end,width) in enumerate([
        ((s*.04,.085,.37),(s*.15,.10,.72),.21),
        ((s*.26,.11,.28),(s*.56,.12,.60),.19),
        ((s*.35,.12,.10),(s*.69,.14,.29),.17)]):
        if side=='R' and i==0: end=(s*.17,.10,.59)
        splinter(side+'_Shoulder_Ancient_Bough_'+str(i),shoulder+Vector(offset),shoulder+Vector(end),width,upper,'wood')
    splinter(side+'_Forearm_Broken_Root',elbow+Vector((s*.25,.07,-.16)),elbow+Vector((s*.51,.13,.06)),.18,fore,'wood')
    # Moss is rooted into the shoulder silhouette and painted with large dark-green clusters.
    for i,(offset,size) in enumerate([
        ((-s*.15,-.24,.32),(.30,.14,.22)),((s*.13,-.23,.26),(.27,.17,.22)),
        ((s*.29,.14,.05),(.19,.24,.19))]):
        box(side+'_Shoulder_Moss_'+str(i),shoulder+Vector(offset),size,upper,'moss' if i<2 else 'moss_dark',Euler((0,math.radians(s*10),0)).to_matrix())
    box(side+'_Forearm_Moss',(s*1.01,-.11,1.34),(.26,.16,.24),fore,'moss_dark')
    root_path(side+'_Shoulder_Grain_Crest',[shoulder+Vector((-s*.25,-.34,.22)),shoulder+Vector((s*.01,-.34,.33)),shoulder+Vector((s*.32,-.34,.06))],.065,.033,upper,'wood_light')

# Firm, wide stance with thick trunk thighs and spread root feet.
for side,s in [('L',-1),('R',1)]:
    hip=Vector((s*.29,.075,1.24)); knee=Vector((s*.43,.055,.72)); ankle=Vector((s*.50,-.075,.19))
    thigh='thigh_'+side; shin='shin_'+side; foot='root_foot_'+side
    centers.update({thigh:hip,shin:knee,foot:ankle}); parents.update({thigh:'body',shin:thigh,foot:shin})
    beam(side+'_Thigh_Trunk',hip,knee,.40,.45,thigh,'bark')
    beam(side+'_Thigh_Heartwood',hip+Vector((s*.13,-.21,-.02)),knee+Vector((s*.12,-.21,.02)),.10,.062,thigh,'wood')
    box(side+'_Knee_Root_Knot',knee,(.38,.43,.27),shin,'bark_dark')
    beam(side+'_Shin_Trunk',knee,ankle,.33,.36,shin,'bark')
    beam(side+'_Shin_Heartwood',knee+Vector((-s*.075,-.19,-.05)),ankle+Vector((s*.09,-.17,.04)),.13,.06,shin,'wood')
    box(side+'_Root_Heel',(s*.50,-.01,.125),(.40,.48,.25),foot,'bark')
    box(side+'_Root_Front',(s*.50,-.31,.075),(.31,.35,.15),foot,'wood')
    box(side+'_Root_Outer',(s*.77,-.10,.067),(.29,.29,.134),foot,'bark')
    box(side+'_Root_Rear',(s*.49,.29,.069),(.26,.28,.138),foot,'bark_dark')
    box(side+'_Hip_Moss',hip+Vector((s*.13,-.18,.035)),(.25,.14,.20),thigh,'moss_dark')
    splinter(side+'_Hip_Root',hip+Vector((s*.15,.11,.065)),hip+Vector((s*.40,.14,.30)),.17,thigh,'wood')
root_path('Lower_Living_Root_L',[(-.11,-.12,1.24),(-.16,-.16,1.03),(-.12,-.16,.75)],.075,.09,'hanging_root_L','vine')
root_path('Lower_Living_Root_R',[(.13,.04,1.23),(.11,-.02,.97),(.16,-.02,.66)],.065,.08,'hanging_root_R','vine')
