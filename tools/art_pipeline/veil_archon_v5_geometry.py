# Strict voxel geometry: all silhouettes are orthogonal steps, not sloping polygon plates.
centers={'body':Vector((0,.07,1.86)),'chest':Vector((0,.07,2.55)),
 'head':Vector((0,.02,3.12)),'core':Vector((0,-.31,2.49)),
 'crown_L':Vector((-.12,.02,3.12)),'crown_R':Vector((.12,.02,3.12)),
 'tail':Vector((0,.06,1.72)),'tail_L':Vector((-.24,.10,1.52)),
 'tail_R':Vector((.24,.10,1.52))}
parents={'body':'root','chest':'body','head':'chest','core':'chest',
 'crown_L':'head','crown_R':'head','tail':'body','tail_L':'body','tail_R':'body'}
for side,s in [('L',-1),('R',1)]:
    for name,c,parent in [('shoulder',(s*.70,.06,2.75),'chest'),
      ('upper_arm',(s*.88,.05,2.64),'chest'),
      ('forearm',(s*1.06,-.01,2.05),'upper_arm_'+side),
      ('hand',(-1.12,-.24,2.37) if side=='L' else (1.36,-.24,1.31),'forearm_'+side)]:
        centers[name+'_'+side]=Vector(c);parents[name+'_'+side]=parent

def stepped(label,profile,depth,y,bone,kind='dark',side=1):
    for a,b in zip(profile,profile[1:]+profile[:1]):
        assert abs(a[0]-b[0])<1e-7 or abs(a[1]-b[1])<1e-7,(label,a,b)
    return prism(label,[(side*x,z) for x,z in profile],depth,(0,y,0),bone,kind)

# The lower body drifts to one side as it narrows, like the reference's suspended black root.
tail=[(-.10,.24),(.02,.24),(.02,.48),(.10,.48),(.10,.88),(.18,.88),
 (.18,1.20),(.26,1.20),(.26,1.60),(.36,1.60),(.36,1.92),(.28,1.92),
 (.28,2.12),(.40,2.12),(.40,2.34),(-.40,2.34),(-.40,2.12),
 (-.28,2.12),(-.28,1.82),(-.20,1.82),(-.20,1.50),(-.12,1.50),
 (-.12,1.10),(-.20,1.10),(-.20,.80),(-.14,.80),(-.14,.48),(-.10,.48)]
stepped('Suspended_Stepped_Body',tail,.30,.14,'tail')
box('Recessed_Chest_Back',(0,.22,2.53),(.54,.30,.58),'chest','dark')

# A continuous dark V collar; its ends rise, its center falls over the chest opening.
collar=[(.08,2.64),(.24,2.64),(.24,2.60),(.40,2.60),(.40,2.44),
 (.56,2.44),(.56,2.52),(.72,2.52),(.72,2.60),(.88,2.60),
 (.88,2.68),(1.04,2.68),(1.04,2.84),(1.12,2.84),(1.12,3.00),
 (.96,3.00),(.96,2.92),(.72,2.92),(.72,2.84),(.40,2.84),
 (.40,2.76),(.08,2.76)]
rim=[(.24,2.68),(.40,2.68),(.40,2.64),(.56,2.64),(.56,2.72),
 (.80,2.72),(.80,2.80),(1.00,2.80),(1.00,2.88),(.80,2.88),
 (.80,2.84),(.56,2.84),(.56,2.76),(.24,2.76)]
for side,s in [('L',-1),('R',1)]:
    stepped(side+'_Broad_V_Collar',collar,.34,.015,'shoulder_'+side,'dark',s)
    stepped(side+'_Collar_Top_Ridge',rim,.045,-.174,'shoulder_'+side,'ridge',s)
    # Armor grows inward to frame the cubic nucleus; no skeletal bars or face.
    chest=[(.28,2.56),(.44,2.56),(.44,2.64),(.60,2.64),(.60,2.48),
      (.52,2.48),(.52,2.24),(.40,2.24),(.40,2.08),(.24,2.08),
      (.24,2.20),(.32,2.20),(.32,2.40),(.28,2.40)]
    stepped(side+'_Chest_Carapace',chest,.24,.005,'chest','dark',s)
    waist=[(.12,1.64),(.28,1.64),(.28,1.80),(.40,1.80),(.40,1.96),
      (.48,1.96),(.48,2.12),(.36,2.12),(.36,2.04),(.28,2.04),
      (.28,1.88),(.20,1.88),(.20,1.76),(.12,1.76)]
    stepped(side+'_Jagged_Waist_Sweep',waist,.24,-.035,'body','ridge',s)
    veins=[(.20,1.80),(.26,1.80),(.26,1.92),(.34,1.92),(.34,2.04),
      (.40,2.04),(.40,2.12),(.34,2.12),(.34,2.08),(.28,2.08),
      (.28,1.98),(.20,1.98)]
    stepped(side+'_Waist_Rose_Mana',veins,.024,-.17,'body','energy',s)
    # Long jagged black sleeves follow the reference, with a single outswept upper thorn.
    upper=[(.76,2.36),(.84,2.36),(.84,2.16),(.92,2.16),(.92,2.00),
      (1.08,2.00),(1.08,2.12),(1.16,2.12),(1.16,2.40),(1.24,2.40),
      (1.24,2.64),(1.16,2.64),(1.16,2.56),(1.04,2.56),
      (1.04,2.72),(.88,2.72),(.88,2.60),(.76,2.60)]
    stepped(side+'_Stepped_Upper_Arm',upper,.29,.035,'upper_arm_'+side,'dark',s)
    upperlight=[(.86,2.20),(.92,2.20),(.92,2.40),(1.00,2.40),(1.00,2.56),
      (.94,2.56),(.94,2.46),(.86,2.46)]
    stepped(side+'_Upper_Arm_Mana',upperlight,.028,-.128,'upper_arm_'+side,'energy',s)
    mantle=[(.96,.72),(1.04,.72),(1.04,.88),(1.16,.88),(1.16,1.04),
      (1.28,1.04),(1.28,1.48),(1.20,1.48),(1.20,1.80),
      (1.12,1.80),(1.12,2.00),(.96,2.00),(.96,1.80),(.88,1.80),
      (.88,1.52),(.96,1.52)]
    stepped(side+'_Long_Broken_Arm_Mantle',mantle,.25,.055,'forearm_'+side,'dark',s)
    outer=[(1.18,1.36),(1.26,1.36),(1.26,1.68),(1.34,1.68),
      (1.34,1.92),(1.26,1.92),(1.26,1.80),(1.18,1.80)]
    stepped(side+'_Mantle_Outer_Thorn',outer,.16,.11,'forearm_'+side,'ridge',s)
    fin=[(.24,.90),(.32,.90),(.32,1.18),(.40,1.18),(.40,1.50),
      (.48,1.50),(.48,1.66),(.32,1.66),(.32,1.50),(.24,1.50)]
    stepped(side+'_Lower_Body_Fin',fin,.17,.14,'tail_'+side,'dark',s)

# Asymmetric spellcaster pose: left spectral arm raised, right extended down and outward.
left=[(-1.18,2.08),(-1.06,2.08),(-1.06,2.40),(-1.18,2.40)]
stepped('Raised_Left_Mana_Forearm',left,.10,-.22,'forearm_L','energy')
box('L_Square_Mana_Palm',(-1.12,-.24,2.435),(.17,.16,.17),'hand_L','energy')
right=[(.98,1.96),(1.08,1.96),(1.08,1.82),(1.20,1.82),(1.20,1.62),
 (1.32,1.62),(1.32,1.46),(1.40,1.46),(1.40,1.28),(1.30,1.28),
 (1.30,1.38),(1.22,1.38),(1.22,1.54),(1.10,1.54),(1.10,1.74),(.98,1.74)]
stepped('Outstretched_Right_Mana_Forearm',right,.10,-.22,'forearm_R','energy')
box('R_Square_Mana_Palm',(1.35,-.24,1.245),(.17,.16,.17),'hand_R','energy')

# No skull, helmet, neck, mouth, or human mask. The crown grows from a small dark void.
head=[(-.08,2.98),(.08,2.98),(.08,3.10),(.16,3.10),(.16,3.22),
 (.08,3.22),(.08,3.28),(-.08,3.28),(-.08,3.22),(-.16,3.22),
 (-.16,3.10),(-.08,3.10)]
stepped('Faceless_Crown_Void',head,.16,.025,'head','dark')
# Open horns instead of an octagonal angel halo: shallow steps sweep to long side points.
horn=[(.04,3.12),(.16,3.12),(.16,3.20),(.32,3.20),(.32,3.28),
 (.56,3.28),(.56,3.32),(.88,3.32),(.88,3.36),(1.00,3.36),
 (1.00,3.40),(.76,3.40),(.76,3.44),(.48,3.44),(.48,3.40),
 (.72,3.40),(.72,3.36),(.48,3.36),(.48,3.32),(.24,3.32),
 (.24,3.24),(.12,3.24),(.12,3.20),(.04,3.20)]
for side,s in [('L',-1),('R',1)]:
    stepped(side+'_Open_Rose_Crown_Horn',horn,.072,-.04,'crown_'+side,'energy',s)

box('Rose_Mana_Core',centers['core'],(.32,.32,.32),'core','core',
    Euler((math.radians(10),math.radians(14),math.radians(10))).to_matrix())
# Explicitly enforce the user's blocky requirement on every solid except the rotating cube.
for o in parts:
    if o['rig_bone']=='core':continue
    for p in o.data.polygons:
        assert max(abs(c) for c in p.normal)> .99999,('Non-voxel face',o.name,p.index)
