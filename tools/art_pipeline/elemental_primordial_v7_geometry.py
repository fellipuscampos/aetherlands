# Direct reconstruction of the supplied creature's composition in large Hytale-like blocks.
# The enormous arms hang in front, inside two articulated crab legs. One dominant cyan
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

# Gigantic hanging arms, with their hands inward and forward, as in the reference.
for side,label in [(-1,'L'),(1,'R')]:
    shoulder=Vector((side*.94,-.14,2.23));elbow=Vector((side*.91,-.51,1.38));wrist=Vector((side*.62,-.87,.48))
    upper='arm_'+label;fore='forearm_'+label;hand='hand_'+label
    centers.update({upper:shoulder,fore:elbow,hand:wrist});parents.update({upper:'body',fore:upper,hand:fore})
    beam('Upper_Arm_'+label,shoulder,elbow,.44,.52,upper,'dark')
    slab('Upper_Arm_Rock_'+label,(shoulder+elbow)/2,(.54,.59,.88),upper,'stone',(-21,side*-2,0))
    # One broad monolithic forearm face, thick at the lower end, rather than a stack of cuffs.
    R=(elbow-wrist).to_track_quat('Z','Y').to_matrix();mid=(elbow+wrist)/2
    o=hexa('Huge_Forearm_'+label,(0,0,0),(.78,.68),(.60,.62),1.04,fore,'stone')
    for v in o.data.vertices:v.co=mid+R@v.co
    o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    slab('Forearm_Outer_Plane_'+label,mid+Vector((side*.23,-.10,.05)),(.19,.70,.88),fore,'ridge',(-22,side*17,0))
    # True crab chelae: a broad fixed palm/outer hook and an opposing articulated dactyl.
    # Both have square cross sections and a real opening visible through the geometry.
    fixed=[(-.22,.10),(.26,.10),(.26,-.03),(.38,-.03),(.38,-.27),(.27,-.27),
           (.27,-.41),(.08,-.41),(.08,-.34),(.03,-.34),(.03,-.23),(.17,-.23),
           (.17,-.12),(-.22,-.12)]
    mobile=[(-.36,.09),(-.16,.09),(-.16,-.03),(-.27,-.03),(-.27,-.10),(-.34,-.10),
            (-.34,-.22),(-.22,-.22),(-.22,-.29),(-.32,-.29),(-.32,-.35),(-.44,-.35),
            (-.44,-.18),(-.49,-.18),(-.49,-.03),(-.36,-.03)]
    center=wrist+Vector((0,-.035,0))
    claw='pincer_'+label
    centers[claw]=center+Vector((side*-.20,0,.025));parents[claw]=hand
    for part,profile,depth,bone in [('Fixed_Crab_Pincer',fixed,.45,hand),('Mobile_Crab_Pincer',mobile,.41,claw)]:
        o=prism(part+'_'+label,profile,depth,center,bone,'dark')
        if side<0:
            for v in o.data.vertices:v.co.x=2*center.x-v.co.x
            bm=bmesh.new();bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
        o['arthropod_part']='fixed propodus' if bone==hand else 'articulated opposing dactyl'
        o['pincer_open_gap_source_m']=.25


    # Arthropod legs: short rising coxa, bent armored merus, and a long pointed tarsus.
    hip=Vector((side*.80,.35,1.47));hinge=Vector((side*1.08,.40,1.31))
    knee=Vector((side*1.27,.37,.78));tip=Vector((side*1.36,.13,0))
    coxa='leg_'+label;merus='shin_'+label;tarsus='tarsus_'+label
    centers.update({coxa:hip,merus:hinge,tarsus:knee});parents.update({coxa:'body',merus:coxa,tarsus:merus})
    beam('Crab_Coxa_'+label,hip,hinge,.26,.28,coxa,'dark')
    R=(hinge-knee).to_track_quat('Z','Y').to_matrix();mid=(hinge+knee)/2
    o=hexa('Crab_Merus_'+label,(0,0,0),(.30,.31),(.38,.37),(hinge-knee).length+.08,merus,'stone')
    for v in o.data.vertices:v.co=mid+R@v.co
    o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    slab('Crab_Joint_'+label,knee,(.29,.31,.22),merus,'dark',(0,side*-11,0))
    # A real pointed blade with a square cross section, four flat sides and no sole or toes.
    R=(knee-tip).to_track_quat('Z','Y').to_matrix()
    vertices=[tip]+[knee+R@Vector((x*.15,y*.16,0)) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    mesh_part('Pointed_Crab_Tarsus_'+label,vertices,[(1,2,3,4),(0,2,1),(0,3,2),(0,4,3),(0,1,4)],tarsus,'dark',R)

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
