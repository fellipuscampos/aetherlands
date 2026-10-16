# User reference: a hunched black-rock creature, vast forelimbs, a small many-eyed head,
# and a crown of enormous cyan mineral columns physically rooted into its back.
C=Vector((0,-.38,1.54))
centers={'body':Vector((0,.28,1.95)),'core':C.copy(),'neck':Vector((0,-.10,2.61)),
 'head':Vector((0,-.91,2.45)),'jaw':Vector((0,-1.01,2.02))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def shape(label,cuboids,bone,kind='stone',R=None,pivot=None):
    o=solid(label,cuboids,bone,kind)
    if R is not None:
        p=Vector(pivot if pivot is not None else cuboids[0][0])
        for v in o.data.vertices:v.co=p+R@(v.co-p)
        o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    return o

# An actual thick body around the recessed heart. No square frame across the chest.
shape('Deep_Rock_Torso',[
 ((0,.44,2.03),(1.62,.56,1.20)),
 ((-.84,.16,2.09),(.56,1.15,1.14)),((.84,.16,2.09),(.56,1.15,1.14)),
 ((0,.54,1.43),(1.36,.60,.42)),((0,.93,1.73),(1.21,.74,.94))],'body','dark')
shape('Hunched_Upper_Back',[
 ((0,.28,2.60),(1.72,1.21,.41)),((0,.50,2.80),(1.25,.87,.25)),
 ((0,.70,2.79),(.85,.63,.22))],'body','stone')
for side,label in [(-1,'L'),(1,'R')]:
    shape('Great_Overlapping_Shoulder_'+label,[
     ((side*1.11,.04,2.45),(.89,1.15,.94)),
     ((side*1.21,.16,2.79),(.62,.93,.41)),
     ((side*1.34,.27,2.93),(.34,.64,.28))],'body','stone',
     Euler((math.radians(-12),math.radians(side*17),math.radians(side*-8))).to_matrix(),(side*1.11,.04,2.45))
    beam('Sweeping_Cowl_'+label,(side*1.21,-.38,2.76),(side*.83,-.57,1.97),.31,.46,'body','ridge')
    shape('Broken_Pectoral_Rock_'+label,[
     ((side*.85,-.40,1.89),(.31,.48,.66)),
     ((side*.78,-.41,1.55),(.24,.38,.29))],'body','stone',
     Euler((0,math.radians(side*10),0)).to_matrix(),(side*.85,-.40,1.89))
    shape('Forward_Thorax_Slab_'+label,[
     ((side*.65,-.65,1.61),(.27,.53,.75)),
     ((side*.63,-.60,1.18),(.24,.55,.33))],'body','stone')
    # Two front mineral outcrops pierce the dark shoulder mass.
    box('Shoulder_Crystal_'+label,(side*.95,-.23,2.78),(.28,.35,.61),'body','crystal',
        Euler((math.radians(-12),math.radians(side*29),0)).to_matrix())

shape('Lower_Thorax_Rock',[
 ((0,-.42,.90),(1.37,.65,.30)),
 ((-.44,-.53,.96),(.44,.40,.16)),((.44,-.53,.94),(.44,.40,.18))],'body','dark')

# A tiny, sheltered arthropod-like face under the massive mineral cowl.
beam('Connected_Neck',(0,-.07,2.66),(0,-.99,2.55),.65,.39,'neck','dark')
shape('Inset_Creature_Head',[
 ((0,-1.12,2.34),(.66,.49,.65)),((0,-1.11,2.60),(.48,.44,.18)),
 ((0,-1.16,2.09),(.53,.40,.23))],'head','face')
box('Recessed_Dark_Face',(0,-1.373,2.34),(.47,.023,.53),'head','face')
for side,label in [(-1,'L'),(1,'R')]:
    for i,(z,x) in enumerate([(2.50,.17),(2.34,.20),(2.18,.17)]):
        box('Luminous_Eye_'+label+str(i),(side*x,-1.397,z),(.079,.019,.102),'head','eye',
            Euler((0,math.radians(side*22),0)).to_matrix())
    shape('Angular_Face_Guard_'+label,[
     ((side*.37,-1.02,2.36),(.17,.47,.47)),
     ((side*.36,-1.02,2.10),(.16,.39,.25))],'head','ridge',
     Euler((0,math.radians(side*13),0)).to_matrix(),(side*.37,-1.02,2.36))
box('Small_Beast_Jaw',(0,-1.13,1.955),(.46,.45,.16),'jaw','dark')
box('Jaw_Cyan_Fault',(0,-1.365,1.945),(.26,.018,.054),'jaw','seam')

# Massive knuckle-bearing forelimbs and smaller splayed rear legs preserve the selected quadruped.
for side,label in [(-1,'L'),(1,'R')]:
    for front in (True,False):
        tag=('front_' if front else 'rear_')+label
        hip=Vector((side*(1.16 if front else .72),-.02 if front else .84,2.40 if front else 1.64))
        knee=Vector((side*(1.40 if front else .98),-.34 if front else 1.13,1.49 if front else .90))
        wrist=Vector((side*(1.51 if front else 1.13),-.81 if front else .98,.53 if front else .28))
        upper=tag+'_upper';lower=tag+'_lower';paw=tag+'_paw'
        centers.update({upper:hip,lower:knee,paw:wrist});parents.update({upper:'body',lower:upper,paw:lower})
        beam('Connected_Leg_'+tag,hip,knee,.48 if front else .35,.58 if front else .39,upper,'dark')
        if front:
            box('Heavy_Upper_Limb_'+tag,(hip+knee)/2,(.64,.77,1.00),upper,'stone',
                (knee-hip).to_track_quat('Z','Y').to_matrix())
            shape('Forearm_Monolith_'+tag,[
             ((0,0,.25),(.83,.86,.66)),((0,-.04,-.27),(.69,.77,.49)),
             ((side*.28,.05,.42),(.36,.67,.37))],lower,'stone',
             (knee-wrist).to_track_quat('Z','Y').to_matrix(),(0,0,0))
            # This local cuboid sculpture is placed along the lower limb as a single rigid block.
            o=parts[-1];d=(knee+wrist)/2
            for v in o.data.vertices:v.co+=d
            o.data.update()
            beam('Outer_Forearm_Ridge_'+tag,knee+Vector((side*.30,.06,.08)),wrist+Vector((side*.28,.04,.07)),.21,.21,lower,'dark')
        else:
            beam('Rear_Shin_'+tag,knee,wrist,.32,.37,lower,'dark')
            box('Rear_Haunch_'+tag,(hip+knee)/2,(.53,.62,.81),upper,'stone',
                (knee-hip).to_track_quat('Z','Y').to_matrix())
        if front:
            shape('Broad_Knuckle_Paw_'+tag,[
             ((wrist.x,wrist.y-.08,.275),(.84,1.02,.55)),
             ((wrist.x,wrist.y-.06,.55),(.66,.75,.34))],paw,'dark')
            for k in (-1,0,1):
                box('Rock_Knuckle_'+tag+str(k),(wrist.x+k*.26,wrist.y-.62,.22),(.22,.25,.28),paw,'stone')
        else:
            shape('Rear_Paw_'+tag,[
             ((wrist.x,wrist.y-.06,.16),(.57,.67,.32)),
             ((wrist.x,wrist.y-.03,.31),(.39,.46,.24))],paw,'dark')

# Huge square-section crystal columns, embedded into the upper back. Stepped ends stay voxel.
for label,x,y,z,w,d,h,rx,ry in [
 ('Central',0,.54,3.16,.85,.70,1.45,-13,0),
 ('Left',-.67,.38,3.05,.47,.56,1.23,-11,-22),
 ('Right',.68,.49,3.00,.50,.57,1.19,-15,24),
 ('Outer_Left',-1.16,.49,2.95,.33,.44,.83,-9,-34),
 ('Outer_Right',1.18,.60,2.85,.34,.43,.77,-14,36)]:
    bone='crystal_'+label.lower();base=Vector((x,y,z-h/2));centers[bone]=base;parents[bone]='body'
    shape('Back_Crystal_'+label,[
     ((x,y,z),(w,d,h)),((x,y,z+h/2-.03),(w*.80,d*.83,.22))],bone,'crystal',
     Euler((math.radians(rx),math.radians(ry),0)).to_matrix(),base)
    box('Rooted_Crystal_Collar_'+label,base+Vector((0,0,.14)),(w+ .16,d+.14,.35),'body','dark')

box('Recessed_Cubic_Elemental_Heart',C,(.54,.54,.54),'core','core',
    Euler((math.radians(10),math.radians(15),math.radians(25))).to_matrix())
