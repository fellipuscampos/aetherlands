# A faceless arcane sovereign: folded ceremonial cloth, an open cowl and one exposed mana cube.
centers={'body':Vector((0,.07,1.38)),'chest':Vector((0,.045,2.12)),
 'crown':Vector((0,.03,2.73)),'core':Vector((0,-.29,2.465)),
 'mantle_L':Vector((-.69,.035,2.40)),'mantle_R':Vector((.69,.035,2.38)),
 'hand_L':Vector((-1.025,-.34,1.66)),'hand_R':Vector((1.075,-.37,1.71)),
 'veil_front':Vector((0,-.025,1.76)),'veil_back':Vector((0,.355,2.48)),
 'veil_side_L':Vector((-.55,.02,1.81)),'veil_side_R':Vector((.55,.02,1.81))}
parents={name:('root' if name=='body' else 'body' if name.startswith('veil_front') else 'chest') for name in centers}
parents['chest']='body'; parents['veil_side_L']=parents['veil_side_R']='body'
def trim(label,points,width,depth,bone,kind='silver'):
    for i in range(len(points)-1): beam(label+'_'+str(i),points[i],points[i+1],width,depth,bone,kind)

# The pointed, asymmetrical cowl surrounds the nucleus, rather than placing a box above it.
left=[(-.07,1.96),(-.39,2.08),(-.64,2.39),(-.64,2.78),(-.54,2.78),(-.54,2.96),(-.24,3.22),(.025,3.22),
 (.025,3.04),(-.26,2.86),(-.43,2.68),(-.43,2.31),(-.21,2.12),(-.025,2.09)]
right=[(.025,2.09),(.24,2.17),(.44,2.38),(.44,2.69),(.26,2.88),(-.025,3.045),(-.025,3.22),
 (.26,3.13),(.54,2.88),(.64,2.65),(.59,2.30),(.42,2.07),(.15,1.94)]
prism('Left_Pointing_Arcane_Cowl',left,.34,(0,.025,0),'crown','cloth')
prism('Right_Pointing_Arcane_Cowl',right,.32,(0,.04,0),'crown','cloth_dark')
trim('Left_Cowl_Silver_Edge',[(-.23,-.159,2.12),(-.50,-.159,2.40),(-.50,-.159,2.76),(-.21,-.159,3.05)],.050,.030,'crown')
trim('Right_Cowl_Silver_Edge',[(.25,-.133,2.15),(.51,-.133,2.40),(.50,-.133,2.71),(.20,-.133,3.02)],.047,.029,'crown','silver_dim')
prism('Cowl_Sovereign_Crest',[(-.055,-.085),(.055,-.085),(.055,.035),(.025,.035),(.025,.11),(-.025,.11),(-.025,.035),(-.055,.035)],.035,(0,-.125,3.19),'crown','silver_light')
box('Exposed_Azure_Mana_Core',centers['core'],(.44,.44,.44),'core','core',Euler((math.radians(13),math.radians(18),math.radians(16))).to_matrix())

# Broad sloped shoulder plates and a layered blue mantle create a regal silhouette.
for side,s in [('L',-1),('R',1)]:
    bone='mantle_'+side; dz=.04 if s<0 else -.015
    profile=[(s*x,z+dz) for x,z in [(.43,2.33),(.43,2.44),(.68,2.65),(.91,2.57),(1.20,2.38),
       (1.20,2.25),(.99,2.20),(.81,2.32),(.55,2.32)]]
    prism(side+'_Silver_Ceremonial_Shoulder',profile,.47,(0,.025,0),bone,'silver')
    # The inner silver layer follows the same cut, rather than forming a rectangular inset panel.
    profile=[(s*x,z+dz) for x,z in [(.48,2.42),(.68,2.58),(.89,2.51),(1.11,2.365),(1.11,2.31),(.87,2.40),(.67,2.49)]]
    prism(side+'_Shoulder_Highlight_Plane',profile,.024,(0,-.224,0),bone,'silver_light')
    profile=[(s*x,z) for x,z in [(.53,2.40),(.93,2.36),(1.10,2.19),(1.10,1.98),(.99,1.98),(.99,1.83),
       (.82,1.83),(.82,1.95),(.68,1.95),(.68,2.12),(.59,2.21)]]
    prism(side+'_Draped_Blue_Mantle',profile,.45,(0,.06,0),bone,'cloth')
    trim(side+'_Mantle_Silver_Hem',[(s*1.055,-.18,2.13),(s*1.055,-.18,2.03),(s*.93,-.18,1.94)],.024,.018,bone,'silver_dim')
    hand='hand_'+side; c=Vector((-1.025,-.34,1.48)) if side=='L' else Vector((1.075,-.37,1.53))
    R=Euler((math.radians(-6),math.radians(s*9),math.radians(s*4))).to_matrix()
    box(side+'_Single_Suspended_Hand',c,(.36,.36,.36),hand,'silver_dim',R)
    box(side+'_Hand_Blue_Binding',c+Vector((0,0,.14)),(.365,.365,.048),hand,'cloth_dark',R)
    # Thin arcane inscriptions are painted into the cuff; no fingers or monitor-like hand panels.

# A pleated, closed cloth volume with an irregular hem. The front never splits into two leg shapes.
def pleated_veil(label,bone,kind,center,widths,hems,y_offsets,depth):
    c=Vector(center); n=7; xs=[-1,-2/3,-1/3,0,1/3,2/3,1]
    vs=[]
    for row,(width,height,ybase) in enumerate(zip(widths,hems,y_offsets)):
        zrow=height if isinstance(height,list) else [height]*n
        front=[c+Vector((x*width/2,ybase+(-.035 if i%2==0 else .055),zrow[i])) for i,x in enumerate(xs)]
        back=[v+Vector((0,depth,0)) for v in reversed(front)]
        vs.extend(front+back)
    ring=2*n; fs=[]
    fs.append(tuple(reversed(range(ring))))
    for row in range(len(widths)-1):
        for i in range(ring):
            j=(i+1)%ring; a=row*ring; b=(row+1)*ring
            fs.append((a+i,a+j,b+j,b+i))
    fs.append(tuple((len(widths)-1)*ring+i for i in range(ring)))
    o=mesh_part(label,vs,fs,bone,kind)
    # Each folded face is planar: metric UVs remain exact even where the hem changes height.
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces)); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free(); o.data.update()
    return o
pleated_veil('Front_Folded_Royal_Veil','veil_front','cloth',(0,-.055,0),[1.10,.98,.64],
  [1.79,1.08,[.49,.39,.33,.21,.34,.43,.51]],[-.005,-.08,-.035],.085)
pleated_veil('Rear_Great_Mantle','veil_back','cloth_dark',(0,.33,0),[1.05,1.19,1.12],
  [2.52,1.27,[.55,.44,.43,.34,.48,.56,.65]],[.01,.095,.16],.09)
for side,s in [('L',-1),('R',1)]:
    profile=[(s*x,z) for x,z in [(.43,1.83),(.65,1.83),(.74,1.43),(.74,1.05),(.64,1.05),(.64,.73),(.52,.73),(.52,.91),(.40,.91),(.40,1.27)]]
    prism(side+'_Outer_Robe_Fold',profile,.115,(0,.10,0),'veil_side_'+side,'cloth_mid')
    trim(side+'_Robe_Silver_Thread',[(s*.54,-.108,1.72),(s*.47,-.145,1.23),(s*.29,-.066,.58)],.024,.014,'veil_front','silver_dim')
prism('Lower_Arcane_Lapel',[(-.44,1.93),(-.20,2.01),(0,1.88),(.22,2.01),(.43,1.94),(.24,1.75),(0,1.67),(-.25,1.77)],.16,(0,-.055,0),'chest','cloth_dark')
trim('Lapel_Silver_Line',[(-.37,-.145,1.91),(0,-.145,1.75),(.37,-.145,1.91)],.036,.022,'chest')

# One subtly engraved fractured portal supports the silhouette instead of overwhelming it.
R=Matrix.Rotation(math.pi/4,3,'Y'); gate=Vector((0,.655,1.86))
profile=[(.45,.97),(1.055,.97),(1.055,.365),(.90,.365),(.90,.815),(.45,.815)]
for i,(sx,sz) in enumerate([(-1,1),(1,1),(1,-1),(-1,-1)]):
    bone='gate_fragment_'+str(i); centers[bone]=gate+R@Vector((sx*.76,0,sz*.67)); parents[bone]='root'
    prism('Fractured_Arcane_Gate_'+str(i),[(sx*x,sz*z) for x,z in profile],.11,gate,bone,'portal',R)
    a=gate+R@Vector((sx*.50,-.064,sz*.925)); b=gate+R@Vector((sx*1.005,-.064,sz*.925))
    end=gate+R@Vector((sx*1.005,-.064,sz*.415))
    trim('Gate_Silver_Inlay_'+str(i),[a,b,end],.026,.018,bone,'portal_edge')
