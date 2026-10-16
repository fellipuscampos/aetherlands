# A colossal mineral predator on four legs. All contours use rigid cuboids and stepped solids.
C=Vector((0,-.79,1.72))
centers={'body':Vector((0,.25,1.82)),'core':C.copy(),'neck':Vector((0,-.48,2.43)),
 'head':Vector((0,-1.04,2.54)),'jaw':Vector((0,-1.12,2.22))}
parents={'body':'root','core':'body','neck':'body','head':'neck','jaw':'head'}

def shape(label,cuboids,bone,kind='stone',R=None,pivot=None):
    o=solid(label,cuboids,bone,kind)
    if R is not None:
        p=Vector(pivot if pivot is not None else cuboids[0][0])
        for v in o.data.vertices:v.co=p+R@(v.co-p)
        o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
    return o

shape('Solid_Chest_And_Back',[
 ((0,.04,2.03),(1.53,.74,1.10)),((0,.57,1.91),(1.40,1.28,1.06)),
 ((0,1.18,1.70),(1.12,.92,.93)),((0,.56,1.39),(1.07,1.29,.39))],'body')
shape('Raised_Withers',[
 ((0,-.05,2.54),(1.25,1.13,.45)),((0,.21,2.73),(.91,.81,.23)),
 ((0,.51,2.69),(.66,.42,.19))],'body','ridge')
# Broad overlapping scapula slabs slope into the forelegs; no humanoid shoulder pads.
for side,label in [(-1,'L'),(1,'R')]:
    rot=Euler((math.radians(-9),math.radians(side*13),0)).to_matrix()
    shape('Great_Scapula_'+label,[
     ((side*.77,-.24,2.25),(.60,1.08,.86)),
     ((side*.86,-.29,2.55),(.48,.85,.36)),
     ((side*.92,-.15,2.72),(.33,.57,.27))],'body','stone',rot,(side*.77,-.24,2.25))
    shape('Open_Chest_Plate_'+label,[
     ((side*.77,-.65,1.93),(.36,.45,.67)),
     ((side*.72,-.63,1.51),(.28,.34,.27))],'body','ridge')
    box('Scapula_Fault_'+label,(side*1.016,-.41,2.45),(.048,.44,.16),'body','seam',
        Euler((0,0,math.radians(side*8))).to_matrix())

# A thick downward-reaching neck joins a broad, snarling, forward-facing mineral head.
beam('Muscular_Mineral_Neck',(0,-.37,2.49),(0,-1.02,2.62),.86,.68,'neck','dark')
shape('Predator_Cranium',[
 ((0,-1.25,2.69),(.98,.75,.56)),((0,-1.59,2.57),(.83,.55,.44)),
 ((0,-1.82,2.51),(.76,.57,.34))],'head','stone')
box('Dark_Maw_Interior',(0,-1.68,2.31),(.64,.69,.13),'head','mouth')
shape('Powerful_Lower_Jaw',[
 ((0,-1.59,2.20),(.81,1.01,.18)),((0,-1.27,2.27),(.92,.43,.23))],'jaw','ridge')
box('Muzzle_End',(0,-2.115,2.49),(.35,.04,.10),'head','dark')
for side,label in [(-1,'L'),(1,'R')]:
    # Two distinct recessed eyes and slanted brows make a predator, rather than a visor helmet.
    box('Eye_Socket_'+label,(side*.30,-1.884,2.73),(.24,.038,.15),'head','dark')
    box('Eye_'+label,(side*.30,-1.913,2.73),(.16,.018,.072),'head','eye',
        Euler((0,math.radians(side*-10),0)).to_matrix())
    box('Heavy_Brow_'+label,(side*.31,-1.885,2.835),(.34,.22,.13),'head','ridge',
        Euler((0,math.radians(side*15),0)).to_matrix())
    shape('Cheek_Plate_'+label,[
     ((side*.47,-1.20,2.50),(.22,.50,.39)),
     ((side*.52,-1.00,2.37),(.21,.27,.25))],'head','dark',
       Euler((math.radians(-12),math.radians(side*17),0)).to_matrix(),(side*.47,-1.20,2.50))
    shape('Backswept_Crown_Horn_'+label,[
     ((side*.39,-1.12,2.94),(.24,.38,.27)),
     ((side*.43,-.88,3.045),(.21,.35,.21)),
     ((side*.47,-.68,3.105),(.13,.27,.13))],'head','dark')
    # Block-cut saber fangs lie beside the mouth and clear the cubic throat/chest heart.
    shape('Great_Crystal_Fang_'+label,[
     ((side*.31,-2.17,2.30),(.14,.18,.30)),
     ((side*.31,-2.21,2.105),(.11,.14,.15)),
     ((side*.31,-2.24,2.025),(.065,.10,.075))],'head','crystal')
    for k in range(2):
        box('Lower_Tooth_'+label+str(k),(side*(.13+k*.19),-1.98,2.335),(.075,.12,.13),'jaw','crystal')

# Front legs are long and heavy; the rear legs have a clear animal hock, rather than human knees.
for side,label in [(-1,'L'),(1,'R')]:
    for front in (True,False):
        tag=('front_' if front else 'rear_')+label
        hip=Vector((side*(.87 if front else .60),-.33 if front else 1.13,2.13 if front else 1.69))
        knee=Vector((side*(1.02 if front else .77),-.56 if front else 1.44,1.17 if front else 1.01))
        wrist=Vector((side*(1.08 if front else .74),-.93 if front else 1.05,.36))
        upper=tag+'_upper';lower=tag+'_lower';paw=tag+'_paw'
        centers.update({upper:hip,lower:knee,paw:wrist});parents.update({upper:'body',lower:upper,paw:lower})
        beam('Connected_Leg_'+tag,hip,knee,.47 if front else .43,.60 if front else .53,upper,'dark')
        box('Animal_Joint_'+tag,knee,(.46,.47,.37),lower,'stone')
        beam('Heavy_Lower_Leg_'+tag,knee,wrist,.43 if front else .35,.51 if front else .43,lower,'stone')
        rot=(wrist-knee).to_track_quat('Z','Y').to_matrix()
        box('Leg_Outer_Plate_'+tag,(hip+knee)/2+Vector((side*.18,.01,.05)),(.33,.73,.55),upper,'ridge',
            (knee-hip).to_track_quat('Z','Y').to_matrix())
        shape('Beast_Paw_'+tag,[
         ((wrist.x,wrist.y-.12,.18),(.65 if front else .55,.86 if front else .72,.36)),
         ((wrist.x,wrist.y-.05,.36),(.47,.56,.24))],paw,'dark')
        for k in (-1,0,1):
            box('Square_Claw_'+tag+str(k),(wrist.x+k*(.195 if front else .165),wrist.y-(.58 if front else .49),.13),
                (.13,.24,.15),paw,'crystal')

# Attached mineral plates follow the curved spine; all face edges remain square and sharp.
for i,(y,z,w,h) in enumerate([(.18,2.88,.32,.37),(.67,2.71,.29,.35),(1.09,2.41,.25,.31),(1.45,2.13,.20,.26)]):
    box('Dorsal_Crest_'+str(i),(0,y,z),(w,.36,h),'body','ridge',Euler((math.radians(20),0,0)).to_matrix())
    if i<3:box('Cold_Crest_Inlay_'+str(i),(0,y-.13,z+.06),(w*.78,.045,h*.48),'body','seam',Euler((math.radians(20),0,0)).to_matrix())

tailpoints=[Vector((0,1.44,1.63)),Vector((0,2.02,1.20)),Vector((.20,2.51,.95)),Vector((.45,2.83,1.16))]
last='body'
for i,(a,b) in enumerate(zip(tailpoints,tailpoints[1:])):
    name='tail_'+str(i);centers[name]=a;parents[name]=last;last=name
    beam('Articulated_Mineral_Tail_'+str(i),a,b,.35-i*.07,.37-i*.07,name,'dark')
box('Tail_Crystal_Tip',tailpoints[-1],(.27,.30,.31),last,'crystal',Euler((math.radians(-22),0,0)).to_matrix())
box('Cubic_Elemental_Heart',C,(.48,.48,.48),'core','core',
    Euler((math.radians(10),math.radians(15),math.radians(25))).to_matrix())
