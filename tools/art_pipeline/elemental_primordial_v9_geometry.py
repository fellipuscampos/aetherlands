# Direct reconstruction of the supplied creature's composition in large Hytale-like blocks.
# The enormous arms hang in front, above six articulated cuboid walking legs. One dominant cyan
# crystal mass rises above the carapace; the tiny head sits low inside the stone collar.
C=Vector((0,-.08,1.51))
centers={'body':Vector((0,.40,1.78)),'core':C.copy(),'neck':Vector((0,.04,2.37)),
 'head':Vector((0,-.73,2.18)),'jaw':Vector((0,-.82,1.79))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def hexa(label,center,lower,upper,height,bone,kind='stone',angles=(0,0,0)):
    # Eight corners and six large planar quad faces. Sharp boxes and modest rectangular tapers.
    c=Vector(center);R=Euler(tuple(math.radians(a) for a in angles)).to_matrix()
    vs=[c+R@Vector((x*s[0]/2,y*s[1]/2,z*height/2)) for z,s in [(-1,lower),(1,upper)]
        for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    return mesh_part(label,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,kind,R)

def slab(label,center,size,bone,kind='stone',angles=(0,0,0)):
    return box(label,center,size,bone,kind,Euler(tuple(math.radians(a) for a in angles)).to_matrix())

# A deep physical body, leaving a cavity around the buried cubic heart.
slab('Deep_Back',(0,.76,1.92),(1.30,.45,1.43),'body','dark',(-5,0,0))
for side,label in [(-1,'L'),(1,'R')]:
    slab('Thorax_Side_'+label,(side*.80,.20,1.98),(.48,1.30,1.23),'body','stone')
slab('Pelvis_Behind_Heart',(0,.74,1.09),(.76,.39,.33),'body','dark')

# The reference's broad, tall asymmetric shell. The head is below these masses, not atop them.
for side,label in [(-1,'L'),(1,'R')]:
    slab('Outer_Carapace_'+label,(side*1.09,.13,2.25),(.60,.89,1.03),'body','stone',(-8,side*26,side*-6))
    slab('Back_Carapace_'+label,(side*.86,.54,2.44),(.62,.89,.64),'body','dark',(-15,side*15,0))
    slab('High_Oblique_Rock_'+label,(side*.91,-.16,2.57),(.39,.58,.87),'body','ridge',(-10,side*24,side*-5))
    # One or two large squared cuts at the ends, instead of rounded voxel boulder contours.
    profile=[(-.21,-.54),(.10,-.54),(.10,-.40),(.28,-.40),(.28,.40),(.15,.40),
             (.15,.61),(-.19,.61),(-.19,.39),(-.28,.39),(-.28,-.30),(-.21,-.30)]
    prism('Face_Enclosing_Rock_'+label,profile,.32,(side*.67,-.58,2.00),'body','dark',
        Euler((math.radians(-8),math.radians(side*25),0)).to_matrix())

# The large diagonal stone blade crossing the lower face/throat on the right is key to the image.
beam('Right_Crossing_Breastplate',(.94,-.69,1.97),(.20,-.76,1.38),.32,.29,'body','ridge')
beam('Left_Descending_Breastplate',(-.66,-.70,1.83),(-.24,-.74,1.20),.25,.26,'body','stone')
slab('Low_Point_Of_Carapace',(0,-.66,1.02),(.37,.34,.31),'body','dark',(0,0,0))

# Small insect-like face: eyes are pixel-painted into its planar front, never separate buttons.
beam('Sheltered_Neck',(0,.14,2.47),(0,-.73,2.25),.46,.31,'neck','dark')
hexa('Small_Six_Eyed_Head',(0,-.81,1.99),(.29,.29),(.49,.33),.49,'head','face',(7,0,0))
slab('Small_Lower_Jaw',(0,-.86,1.737),(.28,.30,.12),'jaw','face',(7,0,0))
for side,label in [(-1,'L'),(1,'R')]:
    slab('Head_Cheek_'+label,(side*.25,-.77,1.985),(.13,.31,.36),'head','dark',(5,side*16,0))

# Every new limb piece is an actual eight-vertex cuboid: no silhouette extrusion,
# curved outline, tapered loft, pyramid, bevel or rounded surface.
def block(label,center,size,bone,kind='stone',R=None):
    o=box(label,center,size,bone,kind,R);o['construction']='cuboid';return o

def block_link(label,a,b,width,depth,bone,kind='stone'):
    o=beam(label,a,b,width,depth,bone,kind);o['construction']='cuboid';return o

# Long lateral roots support three independently articulated walking legs on each side.
for side,label in [(-1,'L'),(1,'R')]:
    block('Crab_Leg_Socket_Rail_'+label,(side*.76,.49,1.22),(.32,1.66,.36),'body','dark')

for side,label in [(-1,'L'),(1,'R')]:
    shoulder=Vector((side*.94,-.14,2.23));elbow=Vector((side*.91,-.51,1.38))
    upper='arm_'+label;fore='forearm_'+label;claw='pincer_'+label
    centers.update({upper:shoulder,fore:elbow});parents.update({upper:'body',fore:upper})
    # Retain the approved upper-arm attachment; all lower anatomy is rebuilt from blocks.
    beam('Upper_Arm_'+label,shoulder,elbow,.44,.52,upper,'dark')
    slab('Upper_Arm_Rock_'+label,(shoulder+elbow)/2,(.54,.59,.88),upper,'stone',(-21,side*-2,0))

    palm=Vector((side*.95,-.78,1.05))
    block('Massive_Cuboid_Chela_'+label,palm,(.78,.74,.70),fore,'stone')
    # The fixed jaw descends from the outside of the palm, with an angular inward bite.
    fixed_root=Vector((side*1.21,-.80,.78));fixed_bend=Vector((side*1.16,-.86,.43))
    fixed_tip=Vector((side*1.08,-.89,.27))
    block_link('Fixed_Pincer_Main_Block_'+label,fixed_root,fixed_bend,.29,.55,fore,'stone')
    block_link('Fixed_Pincer_Bite_Block_'+label,fixed_bend,fixed_tip,.20,.43,fore,'dark')
    # A separate bulky moving jaw opposes it. The open space is between these two real volumes.
    moving_root=Vector((side*.66,-.78,.76));moving_bend=Vector((side*.71,-.85,.42))
    moving_tip=Vector((side*.80,-.89,.27))
    centers[claw]=moving_root;parents[claw]=fore
    block_link('Moving_Pincer_Main_Block_'+label,moving_root,moving_bend,.26,.51,claw,'stone')
    block_link('Moving_Pincer_Bite_Block_'+label,moving_bend,moving_tip,.18,.40,claw,'dark')

    # Six walking legs form a front/middle/rear support footprint, not a pair of human thighs.
    for row,root_y,hinge_y,knee_y,tip_y,hinge_x,knee_x,tip_x in [
      ('front',-.12,-.30,-.58,-.86,1.13,1.40,1.63),
      ('middle',.49,.60,.67,.74,1.24,1.63,1.99),
      ('rear',1.04,1.31,1.56,1.80,1.14,1.43,1.72)]:
        tag=row+'_'+label
        hip=Vector((side*.79,root_y,1.39));hinge=Vector((side*hinge_x,hinge_y,1.48))
        knee=Vector((side*knee_x,knee_y,.73));contact=Vector((side*tip_x,tip_y,.08))
        terminal_root=contact+Vector((0,0,.07));mid=(knee+terminal_root)/2
        coxa='coxa_'+tag;merus='merus_'+tag;tibia='tibia_'+tag
        centers.update({coxa:hip,merus:hinge,tibia:knee})
        parents.update({coxa:'body',merus:coxa,tibia:merus})
        block_link('Crab_Coxa_Block_'+tag,hip,hinge,.34,.38,coxa,'dark')
        block('Crab_High_Joint_Block_'+tag,hinge,(.42,.43,.39),merus,'stone')
        block_link('Crab_Merus_Block_'+tag,hinge,knee,.36,.40,merus,'stone')
        block_link('Crab_Tibia_Upper_Block_'+tag,knee,mid,.29,.32,tibia,'dark')
        block_link('Crab_Tibia_Lower_Block_'+tag,mid,terminal_root,.19,.22,tibia,'dark')
        # Narrow squared end. No broad sole, toes or custom needle-shaped mesh.
        o=block('Crab_Contact_Tip_Block_'+tag,contact,(.12,.15,.16),tibia,'dark')
        o['walking_leg']=tag;o['ground_contact_source']=list(contact-Vector((0,0,.08)))


# Recreate the asymmetrical cluster, dominated by one broad central crystal rather than a crown.
crystals=[
 ('central',.03,.43,2.87,(1.02,.76),(.83,.65),1.12,-7,-3),
 ('left_inner',-.68,.33,2.70,(.37,.44),(.30,.36),.84,-9,-14),
 ('left_outer',-1.02,.10,2.49,(.29,.38),(.24,.30),.62,-8,-24),
 ('right_high',.88,.40,2.93,(.33,.38),(.28,.32),.61,-8,22),
 ('right_outer',1.15,.48,2.75,(.52,.53),(.40,.44),.63,-12,-27)]
for label,x,y,z,lower,upper,h,rx,ry in crystals:
    bone='crystal_'+label;centers[bone]=Vector((x,y,z-h/2));parents[bone]='body'
    hexa('Reference_Crystal_'+label,(x,y,z),lower,upper,h,bone,'crystal',(rx,ry,0))
for side,label in [(-1,'L'),(1,'R')]:
    hexa('Embedded_Cyan_Stone_'+label,(side*.76,-.29,2.20),(.23,.30),(.31,.32),.33,'body','crystal',(-13,side*29,0))

box('Internal_Cubic_Mana_Heart',C,(.58,.58,.58),'core','core',
    Euler((math.radians(10),math.radians(15),math.radians(25))).to_matrix())
