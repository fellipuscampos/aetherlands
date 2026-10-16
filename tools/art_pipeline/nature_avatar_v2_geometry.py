# Reference: a headless root brute, a large arch around the exposed core and a hollow body.
centers={'body':Vector((0,.075,1.20)),'chest':Vector((0,.075,2.04)),
         'crown':Vector((0,.085,2.40)),'core':Vector((0,-.03,2.55)),
         'hanging_root_L':Vector((-.10,.01,1.38)),'hanging_root_R':Vector((.09,.08,1.36))}
parents={'body':'root','chest':'body','crown':'chest','core':'chest','hanging_root_L':'body','hanging_root_R':'body'}
def root_path(label,points,width,depth,bone,kind='wood'):
    for i in range(len(points)-1):
        beam(label+'_'+str(i),points[i],points[i+1],width*(1-.10*i),depth,bone,kind)
def splinter(label,a,b,width,bone,kind='wood_light'):
    # Closed, stepped wooden blade, with a square-ended tip and no rounded cone.
    a,b=Vector(a),Vector(b); length=(b-a).length
    R=(b-a).to_track_quat('Z','Y').to_matrix()
    profile=[(-width/2,0),(width/2,0),(width/2,length*.35),(width*.24,length*.35),
        (width*.24,length*.73),(width*.09,length*.73),(width*.09,length),
        (-width*.09,length),(-width*.09,length*.73),(-width*.24,length*.73),(-width*.24,length*.35),(-width/2,length*.35)]
    return prism(label,profile,width*.65,a,bone,kind,R)

# The torso remains see-through: a few major crossing roots form its outer structure.
root_path('Left_Trunk',[(-.33,.14,1.26),(-.47,.11,1.69),(-.38,.10,2.10),(-.57,.095,2.38)],.24,.30,'chest','wood')
root_path('Right_Trunk',[(.29,.15,1.23),(.41,.14,1.62),(.44,.08,2.09),(.61,.08,2.29)],.22,.28,'chest','wood')
root_path('Back_Spine',[(.15,.30,1.29),(.05,.33,1.79),(-.10,.30,2.17),(0,.27,2.45)],.15,.16,'chest','bark')
root_path('Crossed_Upper_Root',[(-.49,-.11,2.16),(-.18,-.24,2.03),(.15,-.20,2.14),(.53,-.07,2.31)],.17,.19,'chest','wood_light')
root_path('Pelvic_Root',[(-.41,-.065,1.18),(-.22,-.16,1.34),(.17,-.16,1.46),(.43,-.025,1.55)],.24,.27,'body','wood')
root_path('Pelvic_Back',[(-.30,.24,1.20),(.08,.31,1.40),(.35,.20,1.45)],.19,.24,'body','bark')

# Tall angular arch: the core occupies the place where a normal creature's face would be.
root_path('Core_Arch_Left',[(-.12,-.10,2.15),(-.39,-.09,2.41),(-.41,-.01,2.77),(-.23,.035,2.99),(.09,.05,3.07)],.18,.20,'crown','wood_light')
root_path('Core_Arch_Right',[(.19,-.10,2.15),(.42,-.04,2.37),(.44,.04,2.70),(.31,.05,2.94),(.07,.05,3.05)],.17,.19,'crown','wood')
root_path('Core_Back_Bough',[(-.31,.26,2.32),(-.30,.30,2.65),(-.11,.30,2.84),(.23,.27,2.81),(.36,.24,2.54)],.11,.14,'crown','bark')
splinter('Crown_Broken_Tip',(-.17,.015,2.99),(-.27,.02,3.16),.12,'crown')
box('Exposed_Druidic_Core',centers['core'],(.39,.39,.39),'core','core',Euler((math.radians(18),math.radians(25),math.radians(17))).to_matrix())
# Thin living root tendrils hang below the core without covering its front.
for i,(x,y,bottom) in enumerate([(-.15,.045,1.66),(.12,.10,1.73),(.03,.23,1.54)]):
    root_path('Inner_Vine_'+str(i),[(x,y,2.31),(x*.75,y,2.03),(x*.8+.035,y,bottom)],.028,.031,'chest','vine')

# Asymmetric root shoulders and heavy low hands follow the reference's proportions.
for side,s in [('L',-1),('R',1)]:
    shoulder=Vector((s*.61,.075,2.21 if s<0 else 2.17))
    elbow=Vector((s*.83,.015,1.60 if s<0 else 1.58)); wrist=Vector((s*1.02,-.11,.95))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist}); parents.update({upper:'chest',fore:upper,hand:fore})
    beam(side+'_Root_Upper_Arm',shoulder,elbow,.25,.30,upper,'bark')
    root_path(side+'_Upper_Outer_Root',[shoulder+Vector((s*.09,-.14,.08)),elbow+Vector((s*.075,-.12,.08)),elbow+Vector((0,-.13,-.06))],.18,.15,upper,'wood')
    box(side+'_Shoulder_Root_Knot',shoulder+Vector((s*.025,0,.01)),(.39,.40,.36),upper,'bark')
    beam(side+'_Forearm_Trunk',elbow,wrist,.33,.35,fore,'wood')
    beam(side+'_Forearm_Outer_Bark',elbow+Vector((s*.15,.10,-.04)),wrist+Vector((s*.16,.10,.06)),.13,.19,fore,'bark')
    root_path(side+'_Forearm_Winding_Root',[elbow+Vector((-s*.09,-.18,-.03)),(s*.96,-.22,1.30),wrist+Vector((s*.12,-.13,-.05))],.12,.11,fore,'wood_light')
    R=Euler((math.radians(-8),math.radians(s*12),math.radians(-s*5))).to_matrix()
    box(side+'_Single_Block_Hand',wrist+Vector((s*.055,-.035,-.225)),(.43,.42,.53),hand,'wood',R)
    beam(side+'_Hand_Bark_Ridge',wrist+Vector((s*.18,.105,-.07)),wrist+Vector((s*.19,.105,-.41)),.11,.20,hand,'bark')
    # A few large moss masses and seed pods, rather than a dense set of red growths.
    for i,(offset,size,kind) in enumerate([
        ((s*.06,-.18,.12),(.25,.16,.22),'moss'),
        ((-s*.10,.10,.17),(.22,.19,.18),'moss_dark'),
        ((s*.15,.01,-.05),(.16,.20,.22),'moss')]):
        box(side+'_Shoulder_Moss_'+str(i),shoulder+Vector(offset),size,upper,kind)
    box(side+'_Forearm_Moss',(s*.94,-.18,1.18),(.18,.13,.22),fore,'moss_dark')
    box(side+'_Wrist_Seed_Pod',wrist+Vector((-s*.13,-.18,.035)),(.10,.10,.13),fore,'seed')
    splinter(side+'_Elbow_Splinter',elbow+Vector((s*.105,.085,-.04)),elbow+Vector((s*.32,.10,.14)),.115,fore)
    splinter(side+'_Hand_Splinter',wrist+Vector((s*.16,.12,-.18)),wrist+Vector((s*.38,.12,-.42)),.15,hand)
    tip_count=3 if s<0 else 2
    for i in range(tip_count):
        a=shoulder+Vector((s*(.055+i*.10),.055,.10-i*.035))
        b=a+Vector((s*(.16+i*.10),.025,.34-i*.035))
        splinter(side+'_Shoulder_Broken_Bough_'+str(i),a,b,.12 if i else .16,upper)

# Thin, splayed root legs make the massive arms and hollow chest more imposing.
for side,s in [('L',-1),('R',1)]:
    hip=Vector((s*.24,.095,1.34)); knee=Vector((s*.38,.08,.75)); ankle=Vector((s*.46,-.025,.18))
    thigh='thigh_'+side; shin='shin_'+side; foot='root_foot_'+side
    centers.update({thigh:hip,shin:knee,foot:ankle}); parents.update({thigh:'body',shin:thigh,foot:shin})
    beam(side+'_Thigh_Root',hip,knee,.22,.27,thigh,'bark')
    beam(side+'_Thigh_Outer_Root',hip+Vector((s*.13,-.08,.015)),knee+Vector((s*.12,-.08,-.045)),.15,.16,thigh,'wood')
    box(side+'_Knee_Knot',knee,(.25,.29,.24),shin,'bark')
    beam(side+'_Shin_Root',knee,ankle,.22,.24,shin,'wood')
    beam(side+'_Shin_Dark_Ridge',knee+Vector((s*.09,.08,-.05)),ankle+Vector((s*.075,.08,.06)),.095,.13,shin,'bark')
    box(side+'_Root_Heel',(s*.46,.015,.09),(.29,.33,.18),foot,'wood')
    box(side+'_Root_Front',(s*.46,-.215,.055),(.21,.25,.11),foot,'wood')
    box(side+'_Root_Side',(s*.65,-.015,.044),(.25,.18,.088),foot,'bark')
    box(side+'_Knee_Moss',knee+Vector((-s*.065,-.155,.045)),(.18,.10,.20),shin,'moss_dark')
    box(side+'_Hip_Moss',hip+Vector((s*.12,-.13,.01)),(.22,.18,.22),thigh,'moss')
    splinter(side+'_Hip_Broken_Root',hip+Vector((s*.08,.045,.04)),hip+Vector((s*.28,.08,.25)),.12,thigh)
root_path('Waist_Hanging_Root_L',[(-.10,.01,1.38),(-.14,-.025,1.08),(-.11,-.025,.82)],.055,.07,'hanging_root_L','vine')
root_path('Waist_Hanging_Root_R',[(.09,.08,1.36),(.08,.02,1.06),(.13,.02,.70)],.065,.08,'hanging_root_R','vine')
