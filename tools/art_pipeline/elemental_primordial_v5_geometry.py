# Reference-led rebuild: a mineral creature sculpted from irregular voxel boulders,
# not stacked armor boxes. Its little tapered face is buried under the enormous back.
C=Vector((0,.02,1.65))
centers={'body':Vector((0,.55,1.95)),'core':C.copy(),'neck':Vector((0,-.15,2.50)),
 'head':Vector((0,-.74,2.35)),'jaw':Vector((0,-.90,2.04))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def shape(label,cuboids,bone,kind='stone',R=None,pivot=None):
    o=solid(label,cuboids,bone,kind)
    if R is not None:
        p=Vector(pivot if pivot is not None else cuboids[0][0])
        for v in o.data.vertices:v.co=p+R@(v.co-p)
        o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    return o

def rock(label,center,size,bone,kind='stone',angles=(0,0,0),grid=(5,5,7),seed=0):
    # A coarse superellipsoid cut by offset planes: broad broken faces and stepped corners.
    # Every occupied cell is a real cuboid, dissolved into one closed flat-shaded solid.
    c=Vector(center);s=Vector(size);nx,ny,nz=grid;boxes=[]
    for i in range(nx):
        for j in range(ny):
            for k in range(nz):
                x=(i+.5)/nx*2-1;y=(j+.5)/ny*2-1;z=(k+.5)/nz*2-1
                if abs(x)**3.2+abs(y)**3.2+abs(z)**3.2>1.04:continue
                if x*.40+y*.31+z*.54> .92+(seed%3)*.035:continue
                p=c+Vector((x*s.x/2,y*s.y/2,z*s.z/2))
                boxes.append((p,(s.x/nx,s.y/ny,s.z/nz)))
    return shape(label,boxes,bone,kind,Euler(tuple(math.radians(a) for a in angles)).to_matrix(),c)

# A deep torso leaves space for the heart. Irregular side masses close its silhouette.
rock('Heavy_Back_Mass',(0,1.04,2.18),(1.70,.76,1.46),'body','dark',grid=(7,5,7))
for side,label in [(-1,'L'),(1,'R')]:
    rock('Thorax_Mass_'+label,(side*.96,.36,2.03),(.64,1.64,1.44),'body','stone',grid=(5,7,7),seed=1)
rock('Compact_Hindquarters',(0,.96,1.37),(1.32,.54,.55),'body','dark',grid=(7,5,3))
rock('Great_Hunched_Withers',(0,.45,2.67),(1.66,1.47,.61),'body','stone',angles=(-7,0,0),grid=(7,7,3))

for side,label in [(-1,'L'),(1,'R')]:
    rock('Broken_Shoulder_Mass_'+label,(side*1.19,.14,2.51),(1.02,1.22,1.16),'body','stone',
         angles=(-10,side*19,side*-9),grid=(5,5,7),seed=2 if side<0 else 1)
    # Thick overlapping oblique rock blades enclose the face like the reference's carapace.
    profile=[(-.28,-.53),(-.10,-.53),(-.10,-.39),(.10,-.39),(.10,-.22),(.25,-.22),
      (.25,.39),(.12,.39),(.12,.56),(-.13,.56),(-.13,.42),(-.28,.42)]
    prism('High_Cowl_Blade_'+label,profile,.38,(side*.84,-.42,2.31),'body','ridge',
          Euler((math.radians(-14),math.radians(side*30),0)).to_matrix())
    # A low V of broken rock hides most of the cubic heart; it is no longer out on the surface.
    beam('Sloped_Breast_Rock_'+label,(side*.77,-.61,1.92),(side*.31,-.65,1.00),.25,.30,'body','stone')
    rock('Upper_Arm_Root_'+label,(side*1.24,-.01,2.20),(.68,.87,.75),'body','dark',angles=(0,side*8,0),grid=(5,5,5))

# Tapered, recessed six-eyed head. Its silhouette has no rectangular face plate or visor.
beam('Buried_Neck',(0,.05,2.65),(0,-.73,2.49),.57,.36,'neck','dark')
face=[(-.27,.43),(.27,.43),(.27,.30),(.31,.30),(.31,-.04),(.23,-.04),
 (.23,-.22),(.13,-.22),(.13,-.33),(-.13,-.33),(-.13,-.22),(-.23,-.22),
 (-.23,-.04),(-.31,-.04),(-.31,.30),(-.27,.30)]
prism('Tapered_Creature_Head',face,.40,(0,-.96,2.18),'head','face')
for side,label in [(-1,'L'),(1,'R')]:
    for i,(z,x) in enumerate([(2.46,.17),(2.29,.20),(2.09,.14)]):
        box('Small_Luminous_Eye_'+label+str(i),(side*x,-1.181,z),(.057,.035,.077),'head','eye',
            Euler((0,math.radians(side*27),0)).to_matrix())
    rock('Rock_Cheek_'+label,(side*.35,-.86,2.22),(.27,.51,.66),'head','stone',
         angles=(0,side*19,0),grid=(3,5,5))
    shape('Split_Mandible_'+label,[
     ((side*.105,-1.005,1.93),(.17,.34,.19)),
     ((side*.15,-1.00,2.015),(.19,.36,.11))],'jaw','dark')

# Colossal irregular forearms, without cuffs, knee caps or decorated fist panels.
for side,label in [(-1,'L'),(1,'R')]:
    for front in (True,False):
        tag=('front_' if front else 'rear_')+label
        hip=Vector((side*(1.27 if front else .73),.02 if front else .94,2.35 if front else 1.58))
        knee=Vector((side*(1.46 if front else .99),-.30 if front else 1.17,1.47 if front else .88))
        wrist=Vector((side*(1.60 if front else 1.15),-.75 if front else 1.03,.48 if front else .26))
        upper=tag+'_upper';lower=tag+'_lower';paw=tag+'_paw'
        centers.update({upper:hip,lower:knee,paw:wrist});parents.update({upper:'body',lower:upper,paw:lower})
        beam('Living_Limb_Joint_'+tag,hip,knee,.42 if front else .31,.51 if front else .34,upper,'dark')
        if front:
            rock('Upper_Rock_Limb_'+tag,(hip+knee)/2,(.69,.81,1.02),upper,'stone',
                 angles=(-13,side*8,0),grid=(5,5,7),seed=side+2)
            rock('Colossal_Forearm_'+tag,(knee+wrist)/2,(.91,1.02,1.22),lower,'stone',
                 angles=(-22,side*8,side*-3),grid=(5,5,7),seed=1)
            rock('Inner_Forearm_Shadow_'+tag,(knee+wrist)/2+Vector((side*-.22,-.02,-.13)),(.43,.91,.78),lower,'dark',
                 angles=(-19,side*12,0),grid=(3,5,5))
            rock('Great_Clawed_Paw_'+tag,(wrist.x,wrist.y-.10,.32),(.87,1.02,.64),paw,'dark',grid=(5,5,3))
            for k in (-1,1):
                # Two blunt hooked mineral talons, part of the actual paw rather than boxed knuckles.
                shape('Hooked_Rock_Claw_'+tag+str(k),[
                 ((wrist.x+k*.24,wrist.y-.60,.22),(.25,.26,.32)),
                 ((wrist.x+k*.24,wrist.y-.66,.095),(.24,.32,.15))],paw,'dark')
        else:
            rock('Rear_Haunch_'+tag,(hip+knee)/2,(.55,.61,.89),upper,'stone',angles=(-17,side*-14,0),grid=(5,5,5))
            beam('Rear_Shin_'+tag,knee,wrist,.32,.37,lower,'dark')
            rock('Rear_Paw_'+tag,(wrist.x,wrist.y-.04,.16),(.62,.73,.32),paw,'dark',grid=(5,5,3))

# Broken crystalline slabs, no mounting rings, neon frames or identical capped tubes.
for label,x,y,z,w,d,h,rx,ry in [
 ('Central',-.10,.87,3.12,.91,.72,1.57,-10,3),
 ('Left',-.77,.57,3.05,.57,.58,1.18,-8,-18),
 ('Right',.82,.72,2.99,.54,.63,1.07,-13,21),
 ('Outer_Left',-1.24,.48,2.91,.37,.48,.67,-13,-32),
 ('Outer_Right',1.28,.65,2.86,.38,.49,.63,-14,33)]:
    bone='crystal_'+label.lower();base=Vector((x,y,z-h/2));centers[bone]=base;parents[bone]='body'
    shape('Fractured_Back_Crystal_'+label,[
     ((x,y,z),(w,d,h)),
     ((x-w*.12,y,z+h/2+.035),(w*.64,d*.83,.21)),
     ((x+w*.27,y,z+h/2-.018),(w*.27,d*.75,.12))],bone,'crystal',
     Euler((math.radians(rx),math.radians(ry),0)).to_matrix(),base)
for side,label in [(-1,'L'),(1,'R')]:
    shape('Shoulder_Crystal_Shards_'+label,[
     ((side*.98,-.20,2.60),(.23,.31,.52)),
     ((side*1.11,-.15,2.66),(.14,.26,.33))],'body','crystal',
     Euler((math.radians(-14),math.radians(side*30),0)).to_matrix(),(side*.98,-.20,2.40))
box('Buried_Cubic_Elemental_Heart',C,(.62,.62,.62),'core','core',
    Euler((math.radians(10),math.radians(15),math.radians(25))).to_matrix())
