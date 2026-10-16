# A physical elemental creature: planted limbs, a recessed heart and a heavy mineral silhouette.
C=Vector((0,-.24,1.89))
centers={'body':Vector((0,.12,1.55)),'core':C.copy(),'head':Vector((0,-.07,2.52))}
parents={'body':'root','core':'body','head':'body'}

def cluster(label,cuboids,bone,kind):
    return solid(label,cuboids,bone,kind)

# One substantial hollow chest, closed at the back; its cavity leaves the cube free to rotate.
cluster('Deep_Mineral_Chest',[
 ((-.70,.03,1.93),(.35,.88,1.14)),((.70,.03,1.93),(.35,.88,1.14)),
 ((0,.43,1.93),(1.40,.25,1.14)),((0,-.02,2.49),(1.40,.77,.24)),
 ((0,-.01,1.31),(1.24,.71,.22))],'body','stone')
cluster('Heavy_Abdomen',[
 ((0,.12,1.10),(1.12,.73,.30)),((0,.19,.94),(.89,.65,.25))],'body','dark')
cluster('Dorsal_Mineral_Ridge',[
 ((0,.56,2.39),(.47,.30,.53)),((0,.56,2.03),(.55,.33,.43)),
 ((0,.51,1.69),(.48,.27,.30))],'body','mineral')

# A nonhuman block head with a single luminous eye band, projecting brow and square jaw.
box('Short_Solid_Neck',(0,.05,2.57),(.43,.44,.22),'head','dark')
cluster('Mineral_Beast_Head',[
 ((0,-.10,2.77),(.67,.57,.43)),((0,-.23,2.59),(.57,.50,.20))],'head','stone')
box('Recessed_Face',(0,-.398,2.76),(.55,.038,.20),'head','face')
box('Overhanging_Brow',(0,-.39,2.905),(.76,.22,.13),'head','mineral')
box('Square_Lower_Jaw',(0,-.36,2.60),(.60,.22,.13),'head','dark')
for side,label in [(-1,'L'),(1,'R')]:
    # Square, stepped mineral horns are physically anchored to the head, not floating ornaments.
    cluster('Stepped_Crown_Horn_'+label,[
     ((side*.36,.035,2.91),(.22,.28,.32)),
     ((side*.47,.035,3.075),(.18,.25,.23)),
     ((side*.53,.035,3.23),(.12,.20,.17))],'head','mineral')
    shoulder=Vector((side*.90,.05,2.32)); elbow=Vector((side*1.19,-.08,1.75))
    wrist=Vector((side*1.39,-.27,1.00))
    upper='upper_arm_'+label;fore='forearm_'+label;hand='hand_'+label
    centers.update({upper:shoulder,fore:elbow,hand:wrist});parents.update({upper:'body',fore:upper,hand:fore})
    kind='ember' if side<0 else 'ice'
    beam('Connected_Shoulder_Joint_'+label,(side*.73,.06,2.28),(side*1.10,.06,2.28),.36,.48,upper,'dark')
    cluster('Broad_Elemental_Shoulder_'+label,[
     ((side*1.02,.08,2.36),(.63,.71,.48)),
     ((side*1.13,.09,2.59),(.45,.60,.19)),
     ((side*1.22,.10,2.71),(.24,.46,.15))],upper,kind)
    beam('Upper_Arm_'+label,shoulder,elbow,.37,.44,upper,'dark')
    box('Square_Elbow_'+label,elbow,(.39,.43,.35),fore,'stone')
    beam('Massive_Forearm_'+label,elbow,wrist,.54,.59,fore,kind)
    # Plain, solid square hands follow the game's hand design.
    box('Square_Fist_'+label,wrist+Vector((side*.035,-.045,-.19)),(.63,.66,.46),hand,kind)
    # Small attached ridges, rather than separate flame or particle-shaped meshes.
    beam('Forearm_Mineral_Ridge_'+label,elbow+Vector((side*.12,.18,.015)),wrist+Vector((side*.12,.18,.12)),.14,.15,fore,'mineral' if side<0 else 'ice_light')
    hip=Vector((side*.39,.15,1.00)); knee=Vector((side*.51,.04,.58));ankle=Vector((side*.55,-.015,.25))
    thigh='thigh_'+label;shin='shin_'+label;foot='foot_'+label
    centers.update({thigh:hip,shin:knee,foot:ankle});parents.update({thigh:'body',shin:thigh,foot:shin})
    beam('Solid_Thigh_'+label,hip,knee,.43,.54,thigh,'stone')
    box('Heavy_Knee_'+label,knee,(.49,.59,.33),shin,'mineral')
    beam('Short_Weightbearing_Shin_'+label,knee,ankle,.39,.44,shin,'dark')
    cluster('Planted_Block_Foot_'+label,[
     ((side*.55,-.15,.145),(.59,.81,.29)),
     ((side*.55,-.12,.285),(.44,.57,.21))],foot,'stone')

box('Recessed_Cubic_Elemental_Heart',C,(.52,.52,.52),'core','core',
    Euler((math.radians(10),math.radians(12),math.radians(20))).to_matrix())
