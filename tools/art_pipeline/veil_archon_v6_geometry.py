# Sculpted unions of cuboids, with genuine depth and a large open chest cavity.
centers={'body':Vector((0,.10,1.94)),'chest':Vector((0,.10,2.52)),
 'head':Vector((0,.01,3.00)),'core':Vector((0,.0,2.45)),
 'crown_L':Vector((-.13,-.06,3.12)),'crown_R':Vector((.13,-.06,3.12)),
 'tail':Vector((0,.11,1.68)),'tail_L':Vector((-.28,.16,1.65)),
 'tail_R':Vector((.28,.16,1.65))}
parents={'body':'root','chest':'body','head':'chest','core':'chest',
 'crown_L':'head','crown_R':'head','tail':'body','tail_L':'body','tail_R':'body'}
for side,s in [('L',-1),('R',1)]:
    for name,c,parent in [('shoulder',(s*.64,.08,2.88),'chest'),
      ('upper_arm',(s*.87,.10,2.68),'chest'),
      ('forearm',(s*1.10,.06,2.03),'upper_arm_'+side),
      ('hand',(-1.14,-.36,2.43) if side=='L' else (1.33,-.36,1.41),'forearm_'+side)]:
        centers[name+'_'+side]=Vector(c);parents[name+'_'+side]=parent

def solid(label,cuboids,bone,kind='shell',side=1):
    # Boolean union on a cuboid grid. Dissolving coplanar internal edges preserves a closed mesh.
    bounds=[]
    for center,size in cuboids:
        c=Vector((side*center[0],center[1],center[2]));h=Vector(size)/2
        bounds.append((c-h,c+h))
    axes=[sorted(set(round(v[i],6) for a,b in bounds for v in (a,b))) for i in range(3)]
    occ=set()
    for i in range(len(axes[0])-1):
        for j in range(len(axes[1])-1):
            for k in range(len(axes[2])-1):
                p=Vector(tuple((axes[t][q]+axes[t][q+1])/2 for t,q in enumerate((i,j,k))))
                if any(all(a[t]<p[t]<b[t] for t in range(3)) for a,b in bounds):occ.add((i,j,k))
    vertices=[];faces=[];indices={}
    patterns=[((-1,0,0),[(0,0,0),(0,0,1),(0,1,1),(0,1,0)]),
      ((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)]),
      ((0,-1,0),[(0,0,0),(1,0,0),(1,0,1),(0,0,1)]),
      ((0,1,0),[(0,1,0),(0,1,1),(1,1,1),(1,1,0)]),
      ((0,0,-1),[(0,0,0),(0,1,0),(1,1,0),(1,0,0)]),
      ((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)])]
    for cell in sorted(occ):
        for direction,pattern in patterns:
            if tuple(a+b for a,b in zip(cell,direction)) in occ:continue
            face=[]
            for d in pattern:
                key=tuple(a+b for a,b in zip(cell,d))
                if key not in indices:
                    indices[key]=len(vertices);vertices.append(tuple(axes[t][key[t]] for t in range(3)))
                face.append(indices[key])
            faces.append(face)
    o=mesh_part(label,vertices,faces,bone,kind)
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.dissolve_limit(bm,angle_limit=.0001,verts=list(bm.verts),edges=list(bm.edges),use_dissolve_boundaries=False,delimit={'NORMAL'})
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    assert all(max(abs(c) for c in p.normal)>.9999 for p in o.data.polygons),label
    return o

def steps(label,profile,depth,y,bone,kind='shell',side=1):
    for a,b in zip(profile,profile[1:]+profile[:1]):
        assert abs(a[0]-b[0])<1e-7 or abs(a[1]-b[1])<1e-7,(label,a,b)
    return prism(label,[(side*x,z) for x,z in profile],depth,(0,y,0),bone,kind)

# One crooked, deeply sculpted floating root beneath a narrow waist.
solid('Crooked_Suspended_Body',[
 ((0,.13,1.83),(.50,.36,.36)),((.04,.15,1.57),(.42,.31,.28)),
 ((.08,.16,1.33),(.32,.26,.28)),((.08,.14,1.09),(.25,.22,.28)),
 ((.025,.12,.86),(.22,.19,.24)),((-.025,.09,.65),(.18,.16,.22)),
 ((-.045,.05,.46),(.14,.12,.20)),((-.06,.035,.30),(.10,.09,.16))],'tail')
solid('Waist_Heart', [((0,.10,2.00),(.52,.38,.24)),((0,.10,2.14),(.34,.32,.16))],'body','ridge')

for side,s in [('L',-1),('R',1)]:
    # Wide inverted-V shoulders made of rising cuboid layers, not thin diagonal plates.
    solid(side+'_Swept_V_Collar',[
      ((.22,.015,2.77),(.40,.36,.16)),((.49,.035,2.85),(.30,.40,.18)),
      ((.73,.065,2.94),(.28,.43,.19)),((.96,.095,3.04),(.27,.37,.18)),
      ((1.115,.12,3.115),(.15,.25,.15)),
      ((.55,.075,2.69),(.24,.30,.24)),((.76,.105,2.77),(.26,.34,.26))],
      'shoulder_'+side,'ridge',s)
    # Chest shell encloses a real hollow that remains clear of the rotating cube.
    solid(side+'_Open_Chest_Shell',[
      ((.42,.065,2.52),(.20,.43,.56)),((.35,.095,2.25),(.22,.38,.20)),
      ((.25,.115,2.13),(.23,.33,.15)),((.48,.20,2.71),(.25,.30,.19))],
      'chest','shell',s)
    # Thin inner mineral facets on recessed surfaces make the opening legible.
    solid(side+'_Inner_Chest_Lip',[
      ((.315,-.158,2.51),(.055,.026,.30)),((.265,-.108,2.285),(.10,.026,.065))],
      'chest','edge',s)
    # Outer backward thorns are slender cuboids with clipped, square ends.
    solid(side+'_Raised_Dorsal_Spur',[
      ((.69,.29,2.79),(.13,.20,.26)),((.75,.34,3.00),(.105,.15,.18)),
      ((.79,.38,3.145),(.075,.11,.13))],'shoulder_'+side,'shell',s)
    solid(side+'_Upper_Arm_Carapace',[
      ((.91,.12,2.62),(.31,.38,.31)),((.98,.13,2.35),(.28,.34,.30)),
      ((1.065,.12,2.12),(.23,.30,.24)),((1.15,.17,2.49),(.13,.22,.26)),
      ((1.225,.20,2.68),(.075,.14,.14))],'upper_arm_'+side,'shell',s)
    # The dangling outer sleeve has changing depth as well as width.
    solid(side+'_Long_Sculpted_Arm_Mantle',[
      ((1.065,.135,1.90),(.27,.34,.31)),((1.10,.14,1.65),(.31,.37,.27)),
      ((1.08,.17,1.40),(.31,.33,.28)),((1.00,.20,1.15),(.23,.26,.26)),
      ((.965,.22,.94),(.16,.19,.22)),((.965,.235,.78),(.105,.13,.14)),
      ((1.26,.20,1.66),(.11,.20,.24)),((1.32,.23,1.84),(.075,.13,.14))],
      'forearm_'+side,'shell',s)
    # Rear root fins are short accents; the principal body ends in one long point.
    solid(side+'_Rear_Root_Fin',[
      ((.31,.23,1.61),(.18,.22,.28)),((.34,.255,1.38),(.14,.18,.24)),
      ((.33,.28,1.18),(.095,.13,.19))],'tail_'+side,'shell',s)

# Hollow upper body at the back; the center is physically empty in front and on both sides.
solid('Chest_Rear_Arch',[
 ((-.35,.34,2.53),(.14,.16,.55)),((.35,.34,2.53),(.14,.16,.55)),
 ((0,.34,2.82),(.78,.16,.14)),((0,.34,2.23),(.67,.16,.14))],'chest','shell')
box('Crimson_Mana_Core',centers['core'],(.34,.34,.34),'core','core',
    Euler((math.radians(10),math.radians(12),math.radians(11))).to_matrix())

# The tiny central void belongs to the crown, rather than a humanoid head or mask.
solid('Crown_Heart_Void',[
 ((-.09,-.035,3.04),(.08,.13,.22)),((.09,-.035,3.04),(.08,.13,.22)),
 ((0,-.035,2.94),(.18,.13,.07)),((0,-.035,3.155),(.22,.13,.07))],'head','ridge')
horn=[(.02,3.015),(.11,3.015),(.11,3.08),(.23,3.08),(.23,3.15),
 (.40,3.15),(.40,3.22),(.64,3.22),(.64,3.27),(.92,3.27),(.92,3.305),
 (1.07,3.305),(1.07,3.35),(.86,3.35),(.86,3.395),(.59,3.395),
 (.59,3.355),(.78,3.355),(.78,3.315),(.59,3.315),(.59,3.28),
 (.36,3.28),(.36,3.215),(.19,3.215),(.19,3.145),(.08,3.145),
 (.08,3.095),(.02,3.095)]
for side,s in [('L',-1),('R',1)]:
    steps(side+'_Open_Arcane_Crown',horn,.105,-.08,'crown_'+side,'crown',s)

# Energy arms are three-dimensional cuboids with a broad palm. They sit forward of the sleeve.
solid('Raised_Left_Spectral_Arm',[
 ((-1.075,-.29,2.105),(.13,.13,.22)),((-1.12,-.33,2.29),(.11,.12,.21))],
 'forearm_L','energy')
box('Left_Square_Spectral_Palm',(-1.14,-.36,2.44),(.19,.17,.19),'hand_L','energy')
solid('Right_Spectral_Arm',[
 ((1.08,-.29,1.985),(.13,.13,.19)),((1.15,-.31,1.83),(.12,.12,.20)),
 ((1.23,-.335,1.67),(.12,.11,.19)),((1.31,-.36,1.505),(.11,.10,.18))],
 'forearm_R','energy')
box('Right_Square_Spectral_Palm',(1.34,-.37,1.385),(.18,.17,.19),'hand_R','energy')
