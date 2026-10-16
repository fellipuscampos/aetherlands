# User reference: a spectral rib cage within massive, fractured black crescent carapaces.
centers={'body':Vector((0,.045,1.66)),'chest':Vector((0,.03,2.15)),
 'head':Vector((0,-.015,2.62)),'core':Vector((0,-.47,2.045)),
 'carapace_L':Vector((-.74,.075,2.22)),'carapace_R':Vector((.74,.075,2.22)),
 'blade_L':Vector((-.82,.015,1.40)),'blade_R':Vector((.82,.015,1.40)),
 'hip_L':Vector((-.24,.07,1.47)),'hip_R':Vector((.24,.07,1.47)),
 'tail_center':Vector((0,.065,1.17)),'tail_L':Vector((-.13,.115,1.12)),
 'tail_R':Vector((.13,.10,1.14))}
parents={'body':'root','chest':'body','head':'chest','core':'chest',
 'carapace_L':'chest','carapace_R':'chest','blade_L':'body','blade_R':'body',
 'hip_L':'body','hip_R':'body','tail_center':'body','tail_L':'body','tail_R':'body'}
def shell(label,profile,depth,center,bone,kind='obsidian'):
    # A planar inclined front, thick outer edge and flat back give a solid angular carapace.
    c=Vector(center); n=len(profile)
    vs=[c+Vector((x,-depth*.35-.32*(abs(x)-.70),z)) for x,z in profile]
    vs.extend(c+Vector((x,depth*.5,z)) for x,z in profile)
    fs=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    fs.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vs,fs,bone,kind)
def blue_inlay(label,profile,host_depth,center,bone):
    c=Vector(center); n=len(profile)
    front=[c+Vector((x,-host_depth*.35-.32*(abs(x)-.70)-.007,z)) for x,z in profile]
    vs=front+[v+Vector((0,.022,0)) for v in front]
    fs=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    fs.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vs,fs,bone,'blue_facet')

# The exposed structure is built from short rectangular ribs around an energy spine.
box('Spectral_Cervical_Spine',(0,.035,2.35),(.072,.072,.45),'chest','energy_dim')
box('Spectral_Abdominal_Spine',(0,.055,1.63),(.067,.07,.58),'body','energy_dim')
for i,z in enumerate((2.45,2.31,2.16,2.00,1.85)):
    for side,s in [('L',-1),('R',1)]:
        width=.30 if i<3 else .25
        a=(s*.075,-.025,z); b=(s*(width+.075),-.025,z+.060 if i<3 else z+.025)
        beam(side+'_Spectral_Rib_'+str(i),a,b,.062,.058,'chest','bone_blue')
        box(side+'_Rib_Outer_Knot_'+str(i),(s*(width+.075),-.010,z+.065 if i<3 else z+.035),(.060,.10,.083),'chest','bone_blue')
for side,s in [('L',-1),('R',1)]:
    beam(side+'_Spectral_Clavicle',(s*.065,.005,2.45),(s*.39,.01,2.50),.055,.056,'chest','bone_blue')
    beam(side+'_Outer_Collar_Shard',(s*.39,.04,2.48),(s*.61,.045,2.58),.15,.17,'chest','obsidian')
box('Spectral_Skull',(0,-.008,2.635),(.30,.28,.29),'head','skull_blue')
box('Spectral_Skull_Jaw',(0,-.027,2.435),(.25,.235,.074),'head','jaw_blue')
box('Skull_Neck_Link',(0,.025,2.49),(.074,.080,.13),'head','energy_dim')
prism('Blue_Soul_Flame',[(-.046,2.69),(.049,2.69),(.049,2.84),(.023,2.84),(.023,2.98),(-.013,2.98),
 (-.013,2.85),(-.046,2.85)],.045,(0,.13,0),'head','energy_dim')
box('Azure_Mana_Core',centers['core'],(.38,.38,.38),'core','core',Euler((math.radians(14),math.radians(20),math.radians(16))).to_matrix())

# The two dominant crescent shields are solid masses with stepped tips and blue inner facets.
outer=[(.72,1.59),(.96,1.59),(.96,1.77),(1.18,1.77),(1.18,1.94),(1.31,1.94),
 (1.31,2.22),(1.19,2.22),(1.19,2.48),(1.06,2.48),(1.06,2.71),(.94,2.71),
 (.94,3.13),(.84,3.13),(.84,2.83),(.73,2.83),(.73,2.59),(.66,2.59),(.66,2.32),(.59,2.32),
 (.59,2.09),(.68,2.09),(.68,1.84),(.72,1.84)]
inner=[(.675,1.87),(.747,1.93),(.747,2.14),(.69,2.14),(.69,2.36),(.755,2.36),(.755,2.60),
 (.82,2.60),(.82,2.83),(.88,2.83),(.88,3.00),(.84,3.00),(.84,2.80),(.77,2.80),
 (.77,2.56),(.70,2.56),(.70,2.31),(.635,2.31),(.635,2.11),(.675,2.11)]
for side,s in [('L',-1),('R',1)]:
    bone='carapace_'+side; dz=.075 if s<0 else 0.
    profile=[(s*x,z+dz) for x,z in outer]
    shell(side+'_Massive_Black_Crescent',profile,.51 if s<0 else .46,(0,.08,0),bone)
    # The blue facet lies just forward of the inner carapace face, not on a floating overlay.
    blue_inlay(side+'_Blue_Crescent_Inner_Facet',[(s*x,z+dz) for x,z in inner],.51 if s<0 else .46,(0,.08,0),bone)
    # One broad angled plate creates the carapace's broken shoulder ridge.
    ridge=[(.78,2.04),(1.02,2.04),(1.02,2.20),(1.22,2.20),(1.22,2.43),(1.12,2.43),(.97,2.62),(.78,2.40)]
    prism(side+'_Outer_Shield_Fracture',[(s*x,z+dz) for x,z in ridge],.11,(0,-.215,0),bone,'obsidian_mid')
    # A separate long blade below each shield floats across a visible fracture gap.
    lower=[(.69,.45),(.79,.45),(.79,.65),(.90,.65),(.90,.88),(1.01,.88),(1.01,1.15),(.90,1.15),
      (.90,1.41),(.75,1.50),(.65,1.28),(.65,1.00),(.59,1.00),(.59,.82),(.69,.82)]
    dz_lower=.025 if s>0 else 0.
    shell(side+'_Suspended_Lower_Blade',[(s*x,z+dz_lower) for x,z in lower],.28,(0,.025,0),'blade_'+side)
    bevel=[(.705,.56),(.743,.56),(.743,.76),(.79,.76),(.79,1.03),(.74,1.03),(.70,.88),(.70,.71)]
    blue_inlay(side+'_Lower_Blue_Facet',[(s*x,z+dz_lower) for x,z in bevel],.28,(0,.025,0),'blade_'+side)

# Broken pelvic brackets and a few large dorsal fragments frame the empty spectral abdomen.
for side,s in [('L',-1),('R',1)]:
    hip=[(.11,1.12),(.28,1.12),(.28,1.28),(.41,1.28),(.41,1.48),(.33,1.48),(.33,1.68),
      (.23,1.76),(.18,1.57),(.18,1.34),(.11,1.34)]
    prism(side+'_Fractured_Pelvic_Arc',[(s*x,z) for x,z in hip],.20,(0,.035,0),'hip_'+side,'obsidian_mid')
    beam(side+'_Pelvic_Energy_Link',(s*.075,.045,1.36),(s*.22,.045,1.57),.048,.054,'body','bone_blue')
    bone='dorsal_'+side; centers[bone]=Vector((s*.47,.35,2.34)); parents[bone]='chest'
    back=[(.26,1.80),(.39,1.80),(.39,2.10),(.62,2.10),(.62,2.41),(.55,2.41),(.55,2.71),(.45,2.71),(.45,2.46),(.31,2.34)]
    prism(side+'_Dorsal_Obsidian_Blade',[(s*x,z) for x,z in back],.18,(0,.34,0),bone,'obsidian')

# Three angular mana wisps fade the lower silhouette; there are no feet or ordinary legs.
for label,x,depth,bottom in [('center',0,.075,.31),('L',-.13,.058,.49),('R',.13,.059,.58)]:
    profile=[(-.037,1.19),(.039,1.19),(.039,.81),(.023,.81),(.023,bottom+.12),(.011,bottom+.12),(.011,bottom),
      (-.014,bottom),(-.014,.66),(-.030,.66),(-.030,.92),(-.037,.92)]
    prism('Suspended_Mana_Wisp_'+label,profile,depth,(x,.095,0),'tail_'+label,'energy_dim')

# Four substantial free chips echo the reference without adding a cloud of tiny debris.
for i,(x,y,z,w,h,angle) in enumerate([(-1.39,.09,2.52,.16,.28,-14),(-1.16,.13,2.93,.12,.21,15),
  (1.465,.12,2.24,.16,.25,12),(1.17,.075,1.46,.13,.22,-16)]):
    bone='free_fragment_'+str(i); centers[bone]=Vector((x,y,z)); parents[bone]='root'
    profile=[(-w/2,-h/2),(w/2,-h/2),(w/2,h*.19),(w*.15,h*.19),(w*.15,h/2),(-w/2,h/2)]
    prism('Free_Obsidian_Fragment_'+str(i),profile,.13,(x,y,z),bone,'obsidian_mid',Euler((0,math.radians(angle),0)).to_matrix())
