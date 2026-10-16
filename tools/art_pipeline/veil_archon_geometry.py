# A sovereign of folded space: an empty ceremonial mantle, a visible core and a fractured gate.
centers={'body':Vector((0,.04,1.36)),'chest':Vector((0,.015,2.15)),
 'crown':Vector((0,.02,2.77)),'core':Vector((0,-.235,2.04)),
 'mantle_L':Vector((-.70,.02,2.46)),'mantle_R':Vector((.70,.02,2.46)),
 'hand_L':Vector((-1.10,-.33,1.80)),'hand_R':Vector((1.10,-.33,1.80)),
 'veil_L':Vector((-.36,.035,1.63)),'veil_R':Vector((.36,.035,1.63)),
 'veil_back':Vector((0,.32,2.45))}
parents={'body':'root','chest':'body','crown':'chest','core':'chest',
 'mantle_L':'chest','mantle_R':'chest','hand_L':'chest','hand_R':'chest',
 'veil_L':'body','veil_R':'body','veil_back':'chest'}

# An intentionally generous opening leaves the cube free to turn in the future animations.
for side,s in [('L',-1),('R',1)]:
    prism(side+'_Empty_Mantle_Chest_Rail',[(s*x,z) for x,z in [(.48,1.57),(.65,1.57),(.65,1.86),(.72,1.86),(.72,2.31),(.61,2.31),(.61,2.50),(.48,2.50)]],.36,(0,.015,0),'chest','blue')
    box(side+'_Chest_Silver_Inner_Edge',(s*.48,-.18,2.035),(.027,.027,.78),'chest','silver')
box('Ceremonial_High_Collar',(0,.015,2.59),(.99,.47,.16),'chest','blue_dark')
beam('Collar_Left_Silver',(-.48,-.232,2.59),(0,-.26,2.51),.065,.034,'chest','silver')
beam('Collar_Right_Silver',(0,-.26,2.51),(.48,-.232,2.59),.065,.034,'chest','silver')
box('Lower_Mantle_Bridge',(0,.07,1.49),(.95,.40,.14),'body','blue_dark')
box('Lower_Bridge_Silver_Line',(0,-.14,1.51),(.83,.028,.045),'body','silver_dim')
box('Arcane_Heart_Cube',centers['core'],(.50,.50,.50),'core','core',Euler((math.radians(14),math.radians(20),math.radians(18))).to_matrix())

# There is no face or head beneath this open, floating crown.
for side,s in [('L',-1),('R',1)]:
    prism(side+'_Crown_Upright',[(s*x,z) for x,z in [(.125,2.71),(.23,2.71),(.23,2.93),(.18,2.93),(.18,3.10),(.125,3.10)]],.23,(0,.015,0),'crown','silver')
    box(side+'_Crown_Inner_Blue',(s*.116,-.116,2.86),(.025,.024,.30),'crown','blue')
box('Crown_Top_Bridge',(0,.015,3.015),(.43,.23,.065),'crown','silver')
box('Crown_Central_Tine',(0,.015,3.125),(.095,.17,.17),'crown','silver_light')
box('Crown_Lower_Sill',(0,.015,2.715),(.39,.22,.055),'crown','blue_dark')

# Broad, stepped ceremonial shoulders. Only one major mass and a clear silver edge per side.
for side,s in [('L',-1),('R',1)]:
    bone='mantle_'+side
    profile=[(s*x,z) for x,z in [(.43,2.31),(.43,2.59),(.64,2.59),(.64,2.69),(.95,2.69),(1.22,2.49),
      (1.22,2.26),(1.05,2.26),(1.05,2.18),(.66,2.18),(.66,2.31)]]
    prism(side+'_Royal_Arcane_Mantle',profile,.53,(0,.035,0),bone,'blue')
    beam(side+'_Shoulder_Silver_Crest',(s*.65,-.248,2.64),(s*.96,-.248,2.64),.065,.035,bone,'silver_light')
    beam(side+'_Shoulder_Silver_Slope',(s*.96,-.248,2.64),(s*1.17,-.248,2.485),.065,.035,bone,'silver')
    box(side+'_Shoulder_Outer_Silver',(s*1.19,-.25,2.37),(.045,.035,.19),bone,'silver_dim')
    box(side+'_Shoulder_Inset',(s*.86,-.253,2.405),(.20,.018,.11),bone,'blue_dark')
    # One square-spiral arcane motif, painted in the shoulder inset, replaces scattered crystals.
    hand='hand_'+side
    box(side+'_Floating_Wrist_Cuff',(s*1.10,-.33,1.89),(.34,.37,.27),hand,'blue_dark')
    box(side+'_Cuff_Silver_Rim',(s*1.10,-.33,2.005),(.37,.40,.065),hand,'silver')
    box(side+'_Single_Square_Hand',(s*1.10,-.35,1.58),(.43,.42,.44),hand,'silver_dim')
    box(side+'_Hand_Blue_Facet',(s*1.10,-.571,1.59),(.28,.02,.28),hand,'blue')

# A hollow robe made of three broad planes. Its lower ends float, rather than form feet.
for side,s,bottom in [('L',-1,.39),('R',1,.48)]:
    bone='veil_'+side
    profile=[(s*x,z) for x,z in [(.16,1.62),(.54,1.62),(.54,1.35),(.65,1.35),(.65,.93),(.57,.93),(.57,bottom+.19),
      (.46,bottom+.19),(.46,bottom),(.32,bottom),(.32,bottom+.13),(.20,bottom+.13),(.20,1.10),(.16,1.10)]]
    R=Euler((math.radians(-4),math.radians(-s*4),0)).to_matrix()
    prism(side+'_Floating_Veil',profile,.11,(0,-.015,0),bone,'veil',R)
    beam(side+'_Veil_Silver_Edge',(s*.44,-.096,1.56),(s*.49,-.055,bottom+.20),.033,.022,bone,'silver_dim')
profile=[(-.39,2.49),(.39,2.49),(.39,1.55),(.50,1.55),(.50,.90),(.36,.90),(.36,.47),(.20,.47),(.20,.31),
 (-.12,.31),(-.12,.43),(-.34,.43),(-.34,.72),(-.49,.72),(-.49,1.47),(-.39,1.47)]
prism('Rear_Royal_Veil',profile,.12,(0,.335,0),'veil_back','veil_dark')
box('Rear_Veil_Silver_Collar',(0,.405,2.455),(.73,.025,.045),'veil_back','silver')

# Four large L-shaped portal fragments form one broken square, not a cloud of orbiting debris.
R=Matrix.Rotation(math.pi/4,3,'Y'); portal_center=Vector((0,.65,1.92))
corner=[(.47,.99),(1.04,.99),(1.04,.41),(.88,.41),(.88,.83),(.47,.83)]
for i,(sx,sz) in enumerate([(-1,1),(1,1),(1,-1),(-1,-1)]):
    bone='portal_corner_'+str(i); c=portal_center+R@Vector((sx*.755,0,sz*.70))
    centers[bone]=c; parents[bone]='root'
    prism('Fractured_Veil_Gate_'+str(i),[(sx*x,sz*z) for x,z in corner],.13,portal_center,bone,'portal',R)
