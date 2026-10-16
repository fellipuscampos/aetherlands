# Long lowered head, arched armor neck, chunky hovering quadruped.
bone('chest',(0,-.1,1.72),(0,-.1,2.0),'root')
bone('hips',(0,.63,1.62),(0,1,1.57))
bone('neck_01',(0,-.48,1.91),(0,-.89,2.12))
bone('neck_02',(0,-.89,2.12),(0,-1.38,1.96),'neck_01')
bone('head',(0,-1.38,1.96),(0,-2.05,1.84),'neck_02')
bone('jaw',(0,-1.62,1.59),(0,-2.42,1.42),'head')
torso,_=tube('Heavy_armoured_torso',[(0,-.55,1.75),(0,-.12,1.79),(0,.44,1.65),(0,.97,1.53)],
    [.61,.94,.79,.54],[.62,.83,.70,.46],['chest','chest','hips','hips'],'body',.04)
neck,frames=tube('Arched_armoured_neck',[(0,-.45,1.88),(0,-.77,2.12),(0,-1.12,2.09),(0,-1.51,1.91)],
    [.62,.58,.51,.46],[.59,.55,.48,.43],['neck_01','neck_01','neck_02','head'],'body',.035)
for s,suffix in [(1,'L'),(-1,'R')]:
    for i,(y,z) in enumerate([(-.50,1.95),(-.78,2.08),(-1.05,2.02)]):
        box('Neck_raised_scute_%s_%d'%(suffix,i),(s*(.305-.028*i),y,z),(.083,.255,.225),
            'neck_01' if i<2 else 'neck_02','scale',Euler((-.35,0,-s*.12)).to_matrix())
    box('Shoulder_armour_'+suffix,(s*.44,-.13,1.88),(.27,.48,.46),'chest','scale',Euler((0,-s*.25,0)).to_matrix())
for i,(y,z,w) in enumerate([(-.71,1.79,.43),(-.94,1.80,.39),(-1.15,1.71,.36)]):
    box('Throat_scute_%d'%i,(0,y,z-.14),(w,.19,.045),'neck_01' if i<2 else 'neck_02','belly',Euler((-.28,0,0)).to_matrix())
for i,y in enumerate([-.42,-.18,.06,.30,.54,.74]):
    box('Belly_scute_%02d'%i,(0,y,1.35 if y<0 else 1.28),(.56 if y<.4 else .44,.20,.042),
        'chest' if y<.1 else 'hips','belly')

# Much larger skull / long squared muzzle. Eyes are small ember-red recessed slots.
head_rot=Euler((math.radians(-10),0,0)).to_matrix()
box('Large_skull',(0,-1.65,1.97),(.65,.66,.49),'head','body',head_rot)
box('Heavy_long_muzzle',(0,-2.14,1.77),(.56,.76,.32),'head','body',head_rot)
box('Blunt_nose',(0,-2.49,1.704),(.57,.13,.28),'head','scale',head_rot)
box('Mouth_darkness',(0,-2.02,1.59),(.42,.75,.16),'head','mouth',head_rot)
jaw_rot=Euler((math.radians(-11),0,0)).to_matrix()
box('Long_lower_jaw',(0,-2.08,1.438),(.45,.93,.17),'jaw','body',jaw_rot)
box('Pale_lower_jaw',(0,-2.09,1.367),(.46,.94,.037),'jaw','belly',jaw_rot)
for s,suffix in [(1,'L'),(-1,'R')]:
    box('Deep_cheek_'+suffix,(s*.305,-1.61,1.854),(.13,.44,.28),'head','scale',head_rot)
    box('Eye_recess_'+suffix,(s*.333,-1.846,1.951),(.019,.15,.143),'head','dark',head_rot)
    box('Ember_eye_'+suffix,(s*.345,-1.872,1.962),(.013,.071,.095),'head','eye',head_rot)
    box('Angled_brow_'+suffix,(s*.335,-1.878,2.064),(.095,.30,.11),'head','scale',Euler((-.40,0,0)).to_matrix())
    box('Nostril_'+suffix,(s*.15,-2.559,1.77),(.075,.013,.043),'head','dark',head_rot)
    # Broad ridged nasal horns and swept, bent rear horns; not needle antlers.
    tapered('Nasal_ridge_'+suffix,(s*.19,-2.16,1.94),(s*.17,-1.84,2.12),.13,.13,.15,.12,'head','scale')
    tapered('Horn_base_'+suffix,(s*.20,-1.46,2.15),(s*.26,-1.12,2.47),.20,.18,.15,.14,'head','horn')
    tapered('Horn_middle_'+suffix,(s*.26,-1.12,2.47),(s*.28,-.86,2.61),.15,.14,.09,.09,'head','horn')
    spike('Horn_point_'+suffix,(s*.28,-.86,2.61),(s*.28,-.68,2.67),.09,.09,'head','horn')
    tapered('Cheek_horn_root_'+suffix,(s*.32,-1.4,1.92),(s*.40,-1.12,2.00),.12,.12,.09,.085,'head','horn')
    spike('Cheek_horn_end_'+suffix,(s*.40,-1.12,2.00),(s*.48,-.86,2.03),.095,.085,'head','horn')
    for k,y in enumerate([-1.83,-2.00,-2.17,-2.34,-2.46]):
        z=1.62+(y+2.02)*.16
        box('Upper_tooth_%s_%d'%(suffix,k),(s*.213,y,z-.055),(.058,.052,.11 if k<2 else .084),'head','ivory',head_rot)
    for k,y in enumerate([-1.90,-2.11,-2.31,-2.44]):
        z=1.55+(y+1.90)*.18
        spike('Lower_fang_%s_%d'%(suffix,k),(s*.176,y,z-.06),(s*.176,y,z+.015),.05,.05,'jaw','ivory')

# Consistent quadruped joints. Continuous square-section limbs prevent broken
# elbows and keep the four hands at the same hovering level.
for s,suffix in [(1,'L'),(-1,'R')]:
    for label,upper,knee,wrist,hand,uw in [
        ('Front',(s*.43,-.34,1.70),(s*.62,-.66,1.10),(s*.61,-.43,.72),(s*.61,-.55,.61),.36),
        ('Hind',(s*.36,.68,1.53),(s*.64,.47,1.04),(s*.63,.83,.73),(s*.63,.68,.61),.39)]:
        parent='chest' if label=='Front' else 'hips'
        a=label+'_upper_'+suffix; b=label+'_lower_'+suffix; c=label+'_hand_'+suffix
        bone(a,upper,knee,parent); bone(b,knee,wrist,a); bone(c,wrist,(hand[0],hand[1]-.14,hand[2]-.19),b)
        tube(label+'_continuous_limb_'+suffix,[upper,knee,wrist],
            [uw,.30,.25],[uw*.95,.32,.26],[a,b,b],'body',.035)
        box(label+'_heavy_hand_'+suffix,hand,(.34,.38,.22),c,'body')
        for k,dx in enumerate([-.105,0,.105] if label=='Front' else [-.083,0,.083]):
            base=Vector(hand)+Vector((dx,-.17,-.04))
            joint=base+Vector((dx*.10,-.070,-.025))
            tapered(label+'_finger_%s_%d'%(suffix,k),base,joint,.084,.083,.066,.06,c,'scale')
            spike(label+'_talon_%s_%d'%(suffix,k),joint,joint+Vector((dx*.15,-.070,-.084)),.063,.06,c,'horn')

# Reference wings: long bent leading arm, broad upper sail, only two major
# trailing lobes. They rise above the back instead of forming a triangular fan.
for s,suffix in [(1,'L'),(-1,'R')]:
    wing_begin=len(parts)
    def wp(x,z): return Vector((s*x,.25+.32*(x-1.2)-.23*(z-3.1),z))
    shoulder=Vector((s*.44,-.015,1.98))
    elbow=wp(.89,2.60); wrist=wp(1.08,3.20)
    bend=wp(1.64,4.02); tip=wp(2.35,4.23)
    t1=wp(1.96,3.42); t2=wp(2.30,2.73); t3=wp(1.38,1.84)
    flank=Vector((s*.34,.81,1.76))
    a='wing_upper_'+suffix; b='wing_fore_'+suffix; c='wing_sail_'+suffix
    bone(a,shoulder,elbow); bone(b,elbow,wrist,a); bone(c,wrist,bend,b)
    tapered('Wing_arm_'+suffix,shoulder,elbow,.255,.23,.20,.19,a,'body')
    tapered('Wing_forearm_'+suffix,elbow,wrist,.205,.19,.17,.16,b,'scale')
    tapered('Wing_leading_lower_'+suffix,wrist,bend,.17,.16,.13,.13,c,'scale')
    tapered('Wing_leading_top_'+suffix,bend,tip,.145,.14,.115,.11,c,'scale')
    box('Wing_angular_wrist_'+suffix,wrist,(.25,.24,.23),c,'body')
    spike('Wing_thumb_'+suffix,wrist+Vector((0,-.12,.01)),wrist+Vector((s*.03,-.36,.13)),.13,.115,c,'horn')
    for i,T in enumerate([t1,t2,t3]):
        tapered('Wing_spar_%s_%d'%(suffix,i),wrist,T,.12 if i==1 else .089,.098,.07,.06,c,'scale')
    # A wide tall first membrane has a bent top perimeter, unlike the rejected fan.
    top_notch=wp(1.98,3.68)
    membrane('Tall_upper_sail_'+suffix,[wrist,bend,tip,wp(2.13,3.87),top_notch,t1],c)
    membrane('Middle_sail_'+suffix,[wrist,t1,wp(1.84,3.20),wp(1.96,2.96),t2],c)
    membrane('Lower_sail_'+suffix,[wrist,t2,wp(1.86,2.56),wp(1.61,2.25),t3],c)
    membrane('Inner_sail_'+suffix,[elbow,wrist,t3,flank],a)
    # Pose equal-sized wings by rotating them as whole articulated appendages.
    # Never stretch one side's geometry to imitate the photo's perspective.
    R=Euler((0,math.radians(-20 if s==1 else -25),0)).to_matrix()
    for obj in parts[wing_begin:]:
        for v in obj.data.vertices: v.co=shoulder+R@(v.co-shoulder)
        obj.data.update()
    for key in (a,b,c):
        p,q,parent=pivots[key]
        pivots[key]=(shoulder+R@(p-shoulder),shoulder+R@(q-shoulder),parent)

# Segmented tapering tail curls up in a rounded hook rather than a flat crescent.
tail_path=[(0,.97,1.53),(.04,1.32,1.35),(.23,1.69,1.16),(.57,2.00,1.04),
    (.99,2.18,1.07),(1.40,2.17,1.20),(1.78,2.03,1.42),(2.10,1.82,1.67),
    (2.31,1.57,1.93),(2.35,1.30,2.10),(2.23,1.05,2.17),(2.01,.94,2.10),
    (1.84,1.04,1.95),(1.81,1.22,1.78)]
tail_width=[.46,.41,.355,.29,.24,.195,.155,.122,.095,.075,.059,.044,.030,.012]
tail_joints=[]
for i,p in enumerate(tail_path):
    name='tail_%02d'%i
    end=tail_path[i+1] if i<len(tail_path)-1 else Vector(p)+Vector((0,.06,-.07))
    bone(name,p,end,'hips' if i==0 else tail_joints[-1]); tail_joints.append(name)
tail,frames=tube('Continuous_hooked_tail',tail_path,tail_width,[w*.9 for w in tail_width],tail_joints,'body',.025)
for i in range(10):
    p=Vector(tail_path[i]); up=Vector((0,0,1)); up-=frames[i][2]*frames[i][2].z; up.normalize()
    # Raised overlapping armor bands, separated from the body by only 0.01 m.
    axis=frames[i][2]; x=frames[i][0]; y=frames[i][1]
    R=Matrix((x,y,axis)).transposed()
    box('Tail_armour_band_%02d'%i,p+up*(tail_width[i]*.39),
        (tail_width[i]*.92,.055,max(.035,tail_width[i]*.34)),tail_joints[i],'scale',R)
for i,(y,z) in enumerate([(-.93,2.37),(-.58,2.26),(-.21,2.20),(.19,2.12),(.51,2.02),(.78,1.91)]):
    joint='neck_02' if i==0 else 'neck_01' if i==1 else 'chest' if i<4 else 'hips'
    tapered('Low_back_crest_%02d'%i,(0,y,z),(0,y+.10,z+.14),.15,.095,.045,.04,joint,'horn')

