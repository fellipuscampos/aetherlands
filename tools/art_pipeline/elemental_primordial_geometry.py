# A four-element living tempest, sculpted as thick cuboid cloud masses and an open vortex.
C=Vector((0,-.18,2.11));centers={'body':C.copy(),'core':C.copy()};parents={'body':'root','core':'root'}
def cluster(label,cuboids,bone,kind,pivot=None):
    if bone not in centers:
        centers[bone]=Vector(pivot if pivot is not None else cuboids[0][0]);parents[bone]='body'
    return solid(label,cuboids,bone,kind)

# A deep grey cloud crown sweeps behind the exposed nucleus, with an opening at the front.
cluster('Broad_Storm_Cloud_Crown',[
 ((-.80,.24,2.75),(.50,.62,.38)),((-.43,.25,2.96),(.49,.58,.36)),
 ((0,.30,3.02),(.51,.57,.36)),((.43,.28,2.91),(.50,.58,.40)),
 ((.82,.25,2.75),(.45,.53,.37)),((.10,.44,2.72),(.53,.38,.35))],
 'crown','cloud',(0,.28,2.78))
cluster('Upper_Pale_Wind_Ridge',[
 ((-.52,.02,3.08),(.35,.28,.18)),((-.23,.05,3.20),(.31,.28,.17)),
 ((.07,.06,3.22),(.32,.27,.17)),((.36,.06,3.09),(.33,.29,.18))],
 'crown_ridge','mist',(0,.06,3.08))
cluster('Rear_Descending_Storm_Wall',[
 ((.60,.63,2.49),(.42,.31,.36)),((.35,.66,2.20),(.44,.32,.37)),
 ((.02,.66,1.95),(.40,.32,.34)),((-.27,.59,1.73),(.39,.34,.31))],
 'rear_cloud','cloud',(.19,.63,2.12))

# Charred mineral blocks and two voxel flames form the fire side of the tempest.
cluster('Charred_Fire_Carapace',[
 ((-.88,.03,2.59),(.48,.43,.36)),((-.97,.05,2.32),(.43,.42,.31)),
 ((-.85,.025,2.08),(.38,.41,.27)),((-.70,.04,1.88),(.32,.36,.25))],
 'fire_shell','ember',(-.85,.03,2.34))
flame=[(-.14,0),(.14,0),(.14,.17),(.08,.17),(.08,.37),(.02,.37),(.02,.51),
 (-.04,.51),(-.04,.30),(-.11,.30),(-.11,.12),(-.14,.12)]
for i,(x,y,z,angle) in enumerate([(-1.08,.08,2.61,-13),(-.73,.18,2.74,12)]):
    bone='flame_'+str(i);centers[bone]=Vector((x,y,z));parents[bone]='fire_shell'
    prism('Voxel_Fire_Plume_'+str(i),flame,.21,(x,y,z),bone,'flame',Euler((0,math.radians(angle),0)).to_matrix())

# The water mass has solid angular ice, with stepped crystal tips and pixel-painted depth.
cluster('Water_Ice_Carapace',[
 ((.88,-.005,2.57),(.43,.40,.41)),((1.00,.02,2.24),(.41,.43,.36)),
 ((.86,.015,1.94),(.40,.38,.33)),((.66,.055,1.72),(.35,.34,.27))],
 'water_shell','ice',(.89,.02,2.25))
crystal=[(-.14,-.18),(.14,-.18),(.14,.20),(.08,.20),(.08,.39),(.015,.39),
 (.015,.52),(-.045,.52),(-.045,.31),(-.10,.31),(-.10,.03),(-.14,.03)]
for i,(x,y,z,angle) in enumerate([(1.10,.12,2.49,18),(.87,.24,2.73,-9)]):
    bone='ice_spire_'+str(i);centers[bone]=Vector((x,y,z));parents[bone]='water_shell'
    prism('Stepped_Ice_Spire_'+str(i),crystal,.25,(x,y,z),bone,'ice_light',Euler((0,math.radians(angle),0)).to_matrix())

# Earth closes the lower flank: a single sculpted floating boulder, with mineral strata.
cluster('Earth_Basalt_Anchor',[
 ((-.73,.005,1.62),(.55,.48,.39)),((-.58,.04,1.34),(.46,.42,.27)),
 ((-.89,.06,1.52),(.32,.40,.27)),((-.64,.16,1.73),(.34,.36,.28))],
 'earth_anchor','stone',(-.71,.07,1.53))
cluster('Earth_Mineral_Crest',[
 ((-.77,-.259,1.65),(.33,.06,.11)),((-.59,-.204,1.37),(.22,.06,.09))],
 'earth_crest','mineral',(-.68,-.23,1.56))

# Three open, thick square wind curls rotate as they narrow, forming the floating funnel.
for label,z,r,w,angle in [('upper',1.39,.58,.19,-18),('middle',1.02,.42,.16,24),('lower',.67,.27,.13,65)]:
    bone='wind_'+label;centers[bone]=Vector((0,.06,z));parents[bone]='body'
    profile=[(-r,-r),(r,-r),(r,-r+w),(-r+w,-r+w),(-r+w,r-w),
      (r-w,r-w),(r-w,.10),(r,.10),(r,r),(-r,r)]
    R=Euler((math.radians(90),0,math.radians(angle))).to_matrix()
    prism('Open_Wind_Vortex_'+label,profile,w,(0,.06,z),bone,'wind',R)
cluster('Terminal_Mist_Point',[
 ((.10,.085,.43),(.20,.18,.20)),((.055,.055,.285),(.12,.13,.15))],
 'mist_tip','mist',(.055,.055,.33))

# Two substantial cloud curls add weather mass without a halo or an exterior cable.
cluster('Left_Wind_Shoulder',[
 ((-1.07,.24,1.98),(.35,.36,.27)),((-1.20,.26,2.17),(.21,.29,.21)),
 ((-1.21,.29,2.33),(.17,.25,.18))],'left_gust','cloud',(-1.12,.25,2.14))
cluster('Right_Mist_Sweep',[
 ((.85,.12,1.48),(.35,.34,.24)),((1.05,.15,1.65),(.27,.31,.21)),
 ((1.16,.18,1.81),(.18,.24,.20))],'right_gust','mist',(.98,.15,1.64))

# The single white-cyan cube is physically suspended in the clear eye of the tempest.
box('Cyan_Elemental_Heart',C,(.55,.55,.55),'core','core',
    Euler((math.radians(15),math.radians(18),math.radians(14))).to_matrix())
