# More compact, deep skull; short arch connecting it to a compact heavy chest.
bone('chest',(0,-.22,1.66),(0,-.22,1.95),'root')
bone('hips',(0,.64,1.57),(0,.95,1.54))
bone('neck_01',(0,-.54,1.85),(0,-.80,2.01))
bone('neck_02',(0,-.80,2.01),(0,-1.18,1.94),'neck_01')
bone('head',(0,-1.18,1.94),(0,-1.83,1.88),'neck_02')
bone('jaw',(0,-1.18,1.69),(0,-1.85,1.64),'head')
torso,_=tube('Compact_torso',[(0,-.55,1.67),(0,-.10,1.73),(0,.47,1.62),(0,.97,1.52)],
    [.68,.94,.79,.53],[.66,.84,.69,.45],['chest','chest','hips','hips'],'body',.05)
neck,_=tube('Short_arched_neck',[(0,-.51,1.83),(0,-.77,2.02),(0,-.99,1.98),(0,-1.25,1.91)],
    [.59,.57,.53,.48],[.58,.54,.50,.46],['neck_01','neck_01','neck_02','head'],'body',.04)

head_begin=len(parts)
head_origin=Vector((0,-1.18,1.94)); head_R=Euler((math.radians(4),0,0)).to_matrix()
box('Deep_cranium',(0,-.25,.015),(.68,.64,.50),'head','body')
box('Upper_muzzle',(0,-.70,-.074),(.59,.57,.37),'head','body')
box('Squared_nose',(0,-.98,-.074),(.61,.15,.35),'head','scale')
box('Nose_bridge',(0,-.68,.117),(.31,.48,.051),'head','scale')
for s,suffix in [(1,'L'),(-1,'R')]:
    box('Cheek_'+suffix,(s*.321,-.21,-.065),(.11,.36,.39),'head','scale')
    box('Eye_recess_'+suffix,(s*.345,-.44,.075),(.017,.145,.13),'head','dark')
    box('Eye_'+suffix,(s*.357,-.458,.070),(.010,.080,.078),'head','eye')
    box('Brow_'+suffix,(s*.338,-.44,.147),(.085,.255,.073),'head','scale',Euler((-.20,0,0)).to_matrix())
    box('Nostril_'+suffix,(s*.159,-1.057,-.025),(.060,.010,.050),'head','dark')
    tapered('Horn_base_'+suffix,(s*.20,.015,.231),(s*.25,.32,.46),.155,.14,.11,.10,'head','horn')
    spike('Horn_tip_'+suffix,(s*.25,.32,.46),(s*.30,.57,.54),.11,.10,'head','horn')
    spike('Cheek_horn_'+suffix,(s*.35,-.035,-.015),(s*.45,.33,.035),.096,.083,'head','horn')
    for k,y in enumerate([-.52,-.67,-.82,-.97]):
        spike('Upper_tooth_%s_%d'%(suffix,k),(s*.238,y,-.259),(s*.238,y,-.299),.049,.051,'head','ivory')
jaw_begin=len(parts)
hinge=Vector((0,-.025,-.252)); jaw_R=Euler((math.radians(4),0,0)).to_matrix()
box('Lower_jaw',(0,-.512,-.354),(.535,1.035,.15),'jaw','body')
for s,suffix in [(1,'L'),(-1,'R')]:
    for k,y in enumerate([-.59,-.76,-.94]):
        spike('Lower_tooth_%s_%d'%(suffix,k),(s*.214,y,-.279),(s*.214,y,-.239),.043,.045,'jaw','ivory')
for obj in parts[jaw_begin:]:
    for v in obj.data.vertices: v.co=hinge+jaw_R@(v.co-hinge)
for obj in parts[head_begin:]:
    for v in obj.data.vertices: v.co=head_origin+head_R@v.co
    obj.data.update()
pivots['jaw']=(head_origin+head_R@hinge,head_origin+head_R@(hinge+jaw_R@Vector((0,-.65,0))),'head')

# Short upper limbs and substantial, hanging front hands. Hind limbs are tucked
# higher behind the chest; none of the hands is a flat terrestrial shoe.
for s,suffix in [(1,'L'),(-1,'R')]:
    for label,start,knee,wrist,hand,uw in [
        ('Front',(s*.43,-.39,1.62),(s*.52,-.74,1.19),(s*.51,-.54,.89),(s*.51,-.60,.75),.34),
        ('Hind',(s*.39,.66,1.52),(s*.57,.77,1.17),(s*.55,.51,.96),(s*.55,.43,.86),.36)]:
        a=label+'_upper_'+suffix; b=label+'_lower_'+suffix; c=label+'_hand_'+suffix
        bone(a,start,knee,'chest' if label=='Front' else 'hips')
        bone(b,knee,wrist,a); bone(c,wrist,Vector(hand)+Vector((0,-.08,-.22)),b)
        tapered(label+'_upper_'+suffix,start,knee,uw,.33,.295,.30,a,'body')
        # The block sits along the bisector of both limb segments.
        axis=((Vector(knee)-Vector(start)).normalized()+(Vector(wrist)-Vector(knee)).normalized()).normalized()
        R=axis.to_track_quat('Z','Y').to_matrix()
        box(label+'_joint_'+suffix,knee,(.30,.30,.18),b,'body',R)
        tapered(label+'_lower_'+suffix,knee,wrist,.30,.31,.28,.28,b,'body')
        box(label+'_palm_'+suffix,hand,(.355,.31,.285) if label=='Front' else (.28,.26,.22),c,'body')
        for k,dx in enumerate([-.108,0,.108] if label=='Front' else [-.081,0,.081]):
            p=Vector(hand)+Vector((s*dx,-.115,-.08 if label=='Front' else -.062))
            q=p+Vector((s*dx*.10,-.027,-.078))
            tapered(label+'_digit_%s_%d'%(suffix,k),p,q,.08,.078,.067,.061,c,'scale')
            spike(label+'_claw_%s_%d'%(suffix,k),q,q+Vector((s*dx*.12,-.057,-.108)),.067,.061,c,'horn')

wing_surfaces={}; wing_structure={}

def wing_shell(label,positions,panels,influences):
    # One manifold shell, with shared vertices across every sail and the body web.
    keys=list(positions); index={key:i for i,key in enumerate(keys)}
    points=[positions[key] for key in keys]; tris=[]
    for panel in panels:
        local=[positions[key] for key in panel]
        for tri in bpy_extras_tessellate([local]):
            local_indices=[int(v) if isinstance(v,int) else next(i for i,p in enumerate(local) if (p-v).length<1e-6) for v in tri]
            tris.append(tuple(index[panel[i]] for i in local_indices))
    normals=[Vector() for p in points]; edges={}
    # Orient all sail triangles coherently before building the thickness shell.
    reference=(positions['B']-positions['W']).cross(positions['Tip']-positions['W']).normalized()
    for row,tri in enumerate(tris):
        a,b,c=(points[i] for i in tri); n=(b-a).cross(c-a)
        if n.dot(reference)<0: tri=(tri[0],tri[2],tri[1]); n=-n; tris[row]=tri
        for i in tri: normals[i]+=n
        for i,j in zip(tri,(tri[1],tri[2],tri[0])):
            key=tuple(sorted((i,j))); edges.setdefault(key,[]).append((i,j))
    assert all(len(rows)<=2 for rows in edges.values()),label
    count=len(points); offsets=[n.normalized()*.010 for n in normals]
    verts=[p-off for p,off in zip(points,offsets)]+[p+off for p,off in zip(points,offsets)]
    faces=[tuple(reversed(tri)) for tri in tris]+[tuple(count+i for i in tri) for tri in tris]
    for rows in edges.values():
        if len(rows)==1:
            i,j=rows[0]; faces.append((i,j,count+j,count+i))
    weights=[influences[key] for key in keys]*2
    obj=mesh(label,verts,faces,next(iter(influences['S'])),'membrane',weights)
    return obj

def wing_edge(label,path,widths,depths,normal,joints):
    verts=[]; weights=[]
    for i,p in enumerate(path):
        axis=(path[min(i+1,len(path)-1)]-path[max(0,i-1)]).normalized()
        side=normal.cross(axis).normalized()
        verts.extend(p+side*sx*widths[i]/2+normal*sy*depths[i]/2 for sy in (-1,1) for sx in (-1,1))
        weights.extend([{joints[i]:1.0}]*4)
    faces=[(0,1,3,2),tuple(4*(len(path)-1)+j for j in (0,2,3,1))]
    for i in range(len(path)-1):
        a=4*i; b=a+4
        faces.extend([(a,a+1,b+1,b),(a+1,a+3,b+3,b+1),(a+3,a+2,b+2,b+3),(a+2,a,b,b+2)])
    return mesh(label,verts,faces,joints[0],'scale',weights)

# Tall, swept sails rather than radiating fans. The complete root web is part of
# the same mesh. Every spar is centered on the sail plane, including the elbow.
for s,suffix in [(1,'L'),(-1,'R')]:
    def wp(x,z): return Vector((s*x,-.12+.30*(x-.43)-.18*(z-1.94),z))
    p={'S':wp(.43,1.94),'E':wp(.99,2.57),'W':wp(.91,3.18),
       'B':wp(1.36,4.10),'Tip':wp(1.99,4.32),'U0':wp(1.89,4.07),
       'U1':wp(1.77,3.81),'U2':wp(1.70,3.52),'T1':wp(1.71,3.27),
       'M0':wp(1.76,3.08),'T2':wp(1.99,2.80),'L0':wp(1.72,2.61),
       'L1':wp(1.42,2.30),'T3':wp(1.11,1.96),'F':wp(.39,1.47)}
    a='wing_upper_'+suffix; b='wing_fore_'+suffix; c='wing_fingers_'+suffix
    bone(a,p['S'],p['E']); bone(b,p['E'],p['W'],a); bone(c,p['W'],p['B'],b)
    panels=[['W','B','Tip','U0','U1','U2','T1','M0','T2'],
            ['W','T2','L0','L1','T3'],['E','W','T3','F'],['S','E','F']]
    influences={key:{c:1.0} for key in p}
    influences['S']={a:1.0}; influences['E']={a:.45,b:.55}
    influences['F']={a:.5,'hips':.5}
    surface=wing_shell('Continuous_wing_membrane_'+suffix,p,panels,influences)
    normal=(p['B']-p['W']).cross(p['Tip']-p['W']).normalized()
    leading=wing_edge('Continuous_wing_arm_'+suffix,[p[k] for k in ['S','E','W','B','Tip']],
        [.18,.16,.145,.115,.095],[.11,.105,.095,.087,.078],normal,[a,b,c,c,c])
    ribs=[]
    for i,key in enumerate(['T2','T3']):
        ribs.append(wing_edge('Wing_spar_%s_%d'%(suffix,i),[p['W'],p[key]],[.095,.047],[.064,.050],normal,[c,c]))
    front_normal=normal if normal.y<0 else -normal
    spike('Wing_thumb_'+suffix,p['W']+front_normal*.035,p['W']+front_normal*.145+Vector((0,0,.047)),.078,.068,c,'horn')
    wing_surfaces[suffix]=surface
    wing_structure[suffix]={'parts':[leading]+ribs,'anchors':p,'normal':normal}

# A heavy dipping root, long rising mid-tail, and a small open hook at the tip.
tail_controls=[(0,.94,1.52),(.08,1.32,1.24),(.35,1.65,1.01),(.73,1.87,.96),
    (1.18,1.98,1.09),(1.64,1.98,1.30),(2.08,1.88,1.57),(2.46,1.65,1.86),
    (2.74,1.38,2.16),(2.93,1.15,2.34),(3.17,1.02,2.37),(3.34,1.04,2.18),
    (3.30,1.18,1.97),(3.10,1.32,1.87),(2.92,1.37,1.97)]
control_width=[.47,.42,.355,.30,.25,.205,.167,.13,.099,.075,.058,.042,.031,.020,.010]
# Arc-length sampling rounds the hook and removes the sharp mid-tail elbows.
dense=[]; dense_width=[]
def tail_curve(a,b,c,d,t):
    return .5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
controls=[Vector(p) for p in tail_controls]
for i in range(len(controls)-1):
    for k in range(12):
        t=k/12
        dense.append(tail_curve(controls[max(0,i-1)],controls[i],controls[i+1],controls[min(i+2,len(controls)-1)],t))
        dense_width.append(control_width[i]*(1-t)+control_width[i+1]*t)
dense.append(controls[-1]); dense_width.append(control_width[-1])
length=[0.0]
for a,b in zip(dense,dense[1:]): length.append(length[-1]+(b-a).length)
tail_path=[]; width=[]
for i in range(27):
    # Give the small hook as many sections as the much longer tail base.
    # Uniform sampling gave the hook only four segments, making it triangular.
    hook_start=length[8*12]
    distance=hook_start*i/13 if i<=13 else hook_start+(length[-1]-hook_start)*(i-13)/13
    k=next((k for k in range(len(length)-1) if length[k+1]>=distance),len(length)-2)
    t=(distance-length[k])/(length[k+1]-length[k])
    tail_path.append(dense[k].lerp(dense[k+1],t))
    width.append(dense_width[k]*(1-t)+dense_width[k+1]*t)
joints=[]
for i,p in enumerate(tail_path):
    name='tail_%02d'%i; end=tail_path[i+1] if i<len(tail_path)-1 else Vector(p)+Vector((-.04,.02,.04))
    bone(name,p,end,'hips' if i==0 else joints[-1]); joints.append(name)
tail,frames=tube('Long_rising_hooked_tail',tail_path,width,[w*.91 for w in width],joints,'body',.035)
for i,(y,z) in enumerate([(-.84,2.27),(-.56,2.23),(-.23,2.18),(.10,2.14),(.42,2.02),(.73,1.91)]):
    joint='neck_02' if i==0 else 'neck_01' if i==1 else 'chest' if i<4 else 'hips'
    tapered('Dorsal_crest_%d'%i,(0,y,z),(0,y+.085,z+.11),.10,.09,.038,.035,joint,'horn')
