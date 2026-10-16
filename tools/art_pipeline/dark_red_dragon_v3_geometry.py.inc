# A coherent horizontal quadruped. Limbs and wings are exact mirrored pairs.
bone('chest',(0,-.22,1.67),(0,-.22,1.97),'root')
bone('hips',(0,.63,1.58),(0,.96,1.55))
bone('neck_01',(0,-.58,1.88),(0,-.90,2.07))
bone('neck_02',(0,-.90,2.07),(0,-1.34,2.01),'neck_01')
bone('head',(0,-1.34,2.01),(0,-2.05,1.86),'neck_02')
bone('jaw',(0,-1.38,1.81),(0,-2.1,1.59),'head')
torso,_=tube('Solid_torso',[(0,-.57,1.69),(0,-.16,1.73),(0,.47,1.65),(0,.97,1.54)],
    [.62,.94,.84,.56],[.63,.82,.72,.49],['chest','chest','hips','hips'],'body',.035)
neck,_=tube('Solid_arched_neck',[(0,-.54,1.86),(0,-.86,2.08),(0,-1.12,2.06),(0,-1.40,1.98)],
    [.56,.53,.47,.43],[.56,.51,.45,.40],['neck_01','neck_01','neck_02','head'],'body',.035)
for i,(y,z,w) in enumerate([(-.73,1.76,.39),(-.93,1.81,.36),(-1.13,1.77,.34)]):
    box('Throat_scale_%d'%i,(0,y,z),(w,.17,.038),'neck_01' if i<2 else 'neck_02','belly')
for i,y in enumerate([-.41,-.18,.05,.28,.51,.73]):
    box('Belly_scale_%02d'%i,(0,y,1.32),(.57 if y<.3 else .48,.18,.035),'chest' if y<.1 else 'hips','belly')

# Build the WHOLE head in one local frame. Upper teeth are on the upper jaw;
# lower teeth follow a jaw rotated around its hinge, never independently guessed.
head_begin=len(parts)
head_origin=Vector((0,-1.34,2.01))
head_R=Euler((math.radians(10),0,0)).to_matrix()
box('Cranium',(0,-.26,.015),(.61,.64,.40),'head','body')
box('Upper_muzzle',(0,-.78,-.052),(.49,.70,.27),'head','body')
box('Squared_nose',(0,-1.12,-.052),(.51,.135,.26),'head','scale')
box('Nose_bridge',(0,-.71,.087),(.25,.65,.055),'head','scale')
box('Dark_palate',(0,-.69,-.18),(.36,.68,.016),'head','mouth')
for s,suffix in [(1,'L'),(-1,'R')]:
    box('Cheek_'+suffix,(s*.279,-.20,-.05),(.11,.34,.31),'head','scale')
    box('Eye_recess_'+suffix,(s*.311,-.431,.059),(.018,.14,.12),'head','dark')
    # A tilted upper eyelid gives a fierce expression instead of a round smile.
    box('Ember_eye_'+suffix,(s*.322,-.45,.059),(.010,.077,.073),'head','eye')
    box('Heavy_brow_'+suffix,(s*.31,-.431,.122),(.072,.23,.07),'head','scale',Euler((-.20,0,0)).to_matrix())
    box('Nostril_'+suffix,(s*.132,-1.190,-.015),(.057,.010,.045),'head','dark')
    tapered('Rear_horn_base_'+suffix,(s*.19,.0,.185),(s*.23,.31,.41),.15,.14,.11,.10,'head','horn')
    spike('Rear_horn_tip_'+suffix,(s*.23,.31,.41),(s*.29,.60,.51),.11,.10,'head','horn')
    tapered('Cheek_horn_base_'+suffix,(s*.30,-.05,-.025),(s*.36,.18,.015),.09,.08,.055,.05,'head','horn')
    spike('Cheek_horn_tip_'+suffix,(s*.36,.18,.015),(s*.41,.35,.025),.055,.05,'head','horn')
    for k,y in enumerate([-.55,-.72,-.88,-1.04]):
        # Short block teeth with tapered ends, all seated at z=-.186.
        tapered('Upper_tooth_root_%s_%d'%(suffix,k),(s*.184,y,-.183),(s*.184,y,-.226),.043,.045,.035,.038,'head','ivory')
        spike('Upper_tooth_tip_%s_%d'%(suffix,k),(s*.184,y,-.226),(s*.184,y,-.252),.035,.038,'head','ivory')

jaw_begin=len(parts)
hinge=Vector((0,-.02,-.19)); jaw_R=Euler((math.radians(7),0,0)).to_matrix()
box('Lower_jaw',(0,-.61,-.256),(.415,1.19,.12),'jaw','body')
box('Lower_jaw_pale_edge',(0,-.61,-.308),(.43,1.20,.022),'jaw','belly')
box('Dark_tongue',(0,-.69,-.191),(.30,.78,.012),'jaw','mouth')
for s,suffix in [(1,'L'),(-1,'R')]:
    for k,y in enumerate([-.61,-.83,-1.035]):
        spike('Lower_tooth_%s_%d'%(suffix,k),(s*.158,y,-.191),(s*.158,y,-.141),.040,.042,'jaw','ivory')
for obj in parts[jaw_begin:]:
    for v in obj.data.vertices: v.co=hinge+jaw_R@(v.co-hinge)
for obj in parts[head_begin:]:
    for v in obj.data.vertices: v.co=head_origin+head_R@v.co
    obj.data.update()
pivots['jaw']=(head_origin+head_R@hinge,
    head_origin+head_R@(hinge+jaw_R@Vector((0,-.7,0))),'head')

# Legs bend in the sagittal plane: no roll, no sideways twisting, no giant cuffs.
for s,suffix in [(1,'L'),(-1,'R')]:
    for label,start,knee,wrist,hand,uw in [
        ('Front',(s*.47,-.39,1.66),(s*.47,-.69,1.09),(s*.47,-.47,.71),(s*.47,-.55,.60),.335),
        ('Hind',(s*.48,.64,1.57),(s*.48,.34,1.11),(s*.48,.72,.71),(s*.48,.59,.60),.37)]:
        a=label+'_upper_'+suffix; b=label+'_lower_'+suffix; c=label+'_hand_'+suffix
        bone(a,start,knee,'chest' if label=='Front' else 'hips')
        bone(b,knee,wrist,a); bone(c,wrist,Vector(hand)+Vector((0,-.25,-.04)),b)
        tapered(label+'_upper_'+suffix,start,knee,uw,.32,.285,.28,a,'body')
        # One aligned joint block covers both meeting bone ends.
        box(label+'_joint_'+suffix,knee,(.295,.295,.23),b,'body')
        tapered(label+'_lower_'+suffix,knee,wrist,.277,.28,.245,.245,b,'body')
        box(label+'_paw_'+suffix,hand,(.32,.35,.20),c,'body')
        for k,dx in enumerate([-.096,0,.096]):
            p=Vector(hand)+Vector((dx,-.165,-.015))
            tapered(label+'_digit_%s_%d'%(suffix,k),p,p+Vector((0,-.075,-.018)),.073,.07,.062,.058,c,'scale')
            spike(label+'_claw_%s_%d'%(suffix,k),p+Vector((0,-.07,-.018)),p+Vector((dx*.08,-.15,-.084)),.062,.058,c,'horn')

# Identical left/right bat wings. Short humerus, elbow bending out, wrist bending
# in again, then a long curved leading finger. Panels share one exact plane.
wing_areas={}
for s,suffix in [(1,'L'),(-1,'R')]:
    def wp(x,z): return Vector((s*x,.17+.30*(x-1.2)-.21*(z-3.1),z))
    shoulder=Vector((s*.41,.025,1.95))
    elbow=wp(1.12,2.55); wrist=wp(.97,3.10)
    bend=wp(1.62,3.87); tip=wp(2.38,4.03)
    trailing1=wp(2.08,3.30); trailing2=wp(2.31,2.52); trailing3=wp(1.38,1.83)
    flank=Vector((s*.34,.79,1.77))
    a='wing_upper_'+suffix; b='wing_fore_'+suffix; c='wing_fingers_'+suffix
    bone(a,shoulder,elbow); bone(b,elbow,wrist,a); bone(c,wrist,bend,b)
    tapered('Wing_upper_arm_'+suffix,shoulder,elbow,.185,.17,.15,.14,a,'body')
    tapered('Wing_forearm_'+suffix,elbow,wrist,.15,.14,.125,.12,b,'scale')
    tapered('Wing_leading_base_'+suffix,wrist,bend,.135,.125,.105,.10,c,'scale')
    tapered('Wing_leading_tip_'+suffix,bend,tip,.11,.105,.09,.085,c,'scale')
    # Wrist oriented along the forearm, not an unrotated cube jammed into the wing.
    R=(wrist-elbow).to_track_quat('Z','Y').to_matrix()
    box('Wing_wrist_'+suffix,wrist,(.16,.17,.16),c,'body',R)
    spike('Wing_thumb_'+suffix,wrist+Vector((0,-.05,0)),wrist+Vector((s*.055,-.23,.07)),.09,.082,c,'horn')
    for i,T in enumerate([trailing1,trailing2,trailing3]):
        tapered('Wing_finger_%s_%d'%(suffix,i),wrist,T,.09,.078,.046,.042,c,'scale')
    membrane('Wing_upper_membrane_'+suffix,[wrist,bend,tip,wp(2.21,3.76),wp(2.07,3.55),trailing1],c)
    membrane('Wing_middle_membrane_'+suffix,[wrist,trailing1,wp(1.98,3.06),wp(2.06,2.78),trailing2],c)
    membrane('Wing_lower_membrane_'+suffix,[wrist,trailing2,wp(1.94,2.40),wp(1.67,2.12),trailing3],c)
    membrane('Wing_inner_membrane_'+suffix,[elbow,wrist,trailing3,flank],a)

# Long square-section tail; this is the only intentionally asymmetric anatomy.
tail_path=[(0,.96,1.54),(.02,1.35,1.36),(.20,1.75,1.17),(.53,2.06,1.07),
    (.96,2.24,1.08),(1.40,2.23,1.22),(1.80,2.07,1.47),(2.12,1.81,1.75),
    (2.29,1.51,1.99),(2.26,1.20,2.09),(2.06,1.01,2.04),(1.84,1.09,1.88),(1.77,1.30,1.72)]
width=[.46,.40,.34,.28,.225,.18,.142,.11,.085,.062,.045,.029,.012]
joints=[]
for i,p in enumerate(tail_path):
    key='tail_%02d'%i
    end=tail_path[i+1] if i<len(tail_path)-1 else Vector(p)+Vector((0,.04,-.04))
    bone(key,p,end,'hips' if i==0 else joints[-1]); joints.append(key)
tail,frames=tube('Long_curled_tail',tail_path,width,[w*.9 for w in width],joints,'body',.025)
for i,(y,z) in enumerate([(-1.02,2.28),(-.75,2.29),(-.42,2.19),(-.10,2.18),(.22,2.11),(.52,2.02),(.82,1.89)]):
    joint='neck_02' if i==0 else 'neck_01' if i==1 else 'chest' if i<4 else 'hips'
    tapered('Dorsal_crest_%d'%i,(0,y,z),(0,y+.095,z+.13),.10,.09,.038,.035,joint,'horn')
for i in range(8):
    p=Vector(tail_path[i]); up=Vector((0,0,1)); up-=frames[i][2]*up.dot(frames[i][2]); up.normalize()
    b=p+up*width[i]*.43
    spike('Tail_crest_%02d'%i,b,b+up*(.09-.007*i)+frames[i][2]*.025,.061-.004*i,.057-.004*i,joints[i],'horn')
