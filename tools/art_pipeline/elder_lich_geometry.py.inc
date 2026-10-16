# An ancient mortal mage: hooded skull, worn vestments, connected arms and a fading lower body.
centers={'body':Vector((0,.04,1.72)),'chest':Vector((0,.04,2.19)),'head':Vector((0,.04,2.72))}
parents={'body':'root','chest':'body','head':'chest'}
box('Withered_Torso',(0,.055,2.19),(.50,.38,.52),'chest','shadow')
box('Spectral_Spine',(0,-.150,2.22),(.065,.035,.43),'chest','spirit_dim')
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    for j,z in enumerate((2.32,2.21,2.10)):
        box(side+'_Ancient_Rib_'+str(j),(sign*.132,-.182,z),(.19,.040,.056),'chest','bone')
    # Broad, asymmetric stepped lapels frame the remaining rib cage.
    prism(side+'_Mantle_Lapel',[(sign*x,z) for x,z in [(.11,2.42),(.36,2.42),(.49,2.32),(.49,2.19),(.33,2.19),(.33,1.97),(.24,1.97),(.24,2.30),(.11,2.30)]],.095,(0,-.125,0),'chest','cloth')
    beam(side+'_Collar_Trim',(sign*.12,-.195,2.40),(sign*.35,-.195,2.31),.036,.025,'chest','brass')
box('Neck_Remnant',(0,.005,2.50),(.095,.13,.15),'head','bone')

# Deep square cowl, with a real opening around a small weathered cubic skull.
box('Hood_Back',(0,.285,2.80),(.65,.115,.54),'head','cloth_dark')
box('Hood_Roof',(0,.035,3.025),(.63,.66,.14),'head','cloth')
box('Hood_Roof_Step',(0,.085,3.112),(.49,.51,.065),'head','cloth')
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    profile=[(sign*x,z) for x,z in [(.245,2.965),(.365,2.965),(.415,2.845),(.415,2.625),(.345,2.625),(.345,2.510),(.235,2.510),(.235,2.61),(.265,2.61),(.265,2.82),(.245,2.82)]]
    prism(side+'_Deep_Cowl',profile,.60,(0,.01,0),'head','cloth')
    box(side+'_Cowl_Inner_Shadow',(sign*.232,.006,2.77),(.055,.44,.33),'head','shadow')
    box(side+'_Hood_Edge',(sign*.296,-.302,2.81),(.031,.018,.27),'head','brass_dark')
box('Skull',(0,-.021,2.756),(.402,.365,.378),'head','skull_face')
box('Skull_Jaw',(0,-.047,2.535),(.292,.290,.067),'head','bone')
# A small antique diadem identifies a sovereign necromancer rather than a heavily armored monster.
box('Diadem_Band',(0,-.288,3.035),(.43,.046,.055),'head','brass')
for label,x,height in [('Center',0,.115),('Left',-.147,.068),('Right',.147,.068)]:
    box('Diadem_'+label,(x,-.286,3.066+height/2),(.043,.045,height),'head','brass')

box('Waist_Worn_Robe',(0,.07,1.79),(.46,.40,.33),'body','cloth_dark')
box('Antique_Belt',(0,-.015,1.765),(.49,.45,.060),'body','brass_dark')
box('Belt_Clasp',(0,-.256,1.765),(.11,.023,.095),'body','brass')
# A modest relic necklace, not an exposed energy core.
for sign in (-1,1): beam(('L' if sign<0 else 'R')+'_Relic_Chain',(sign*.09,-.242,2.35),(0,-.267,2.27),.014,.014,'chest','brass_dark')
box('Relic_Setting',(0,-.272,2.255),(.072,.028,.095),'chest','brass')
box('Relic_Green_Seal',(0,-.291,2.257),(.036,.012,.050),'chest','glow')

# Long robes taper and break into square-ended strips. No boots or ordinary legs.
for side,sign in [('L',-1),('R',1)]:
    name='robe_front_'+side; centers[name]=Vector((sign*.18,-.165,1.72)); parents[name]='body'
    profile=[(sign*x,z) for x,z in [(.035,1.74),(.355,1.74),(.355,1.36),(.40,1.36),(.40,.94),(.43,.94),(.43,.56),(.35,.56),(.35,.42),(.24,.42),(.24,.63),(.12,.63),(.12,.52),(.035,.52)]]
    prism(side+'_Front_Vestment',profile,.078,(0,-.163,0),name,'cloth')
    # Worn vertical edging is broad enough to survive the game's high camera.
    box(side+'_Vertical_Stole',(sign*.08,-.209,1.20),(.038,.018,.97),name,'brass_dark')
    box(side+'_Stole_Lower_End',(sign*.08,-.209,.705),(.082,.018,.034),name,'brass_dark')
    name='robe_side_'+side; centers[name]=Vector((sign*.35,.095,1.72)); parents[name]='body'
    profile=[(-.19,1.75),(.19,1.75),(.19,1.26),(.26,1.26),(.26,.70),(.19,.70),(.19,.34),(.08,.34),(.08,.50),(-.12,.50),(-.12,.75),(-.19,.75)]
    # Side panels face outward, perpendicular to the front panels.
    R=Matrix.Rotation(sign*math.pi/2,3,'Z')
    prism(side+'_Side_Vestment',profile,.085,(sign*.365,.12,0),name,'cloth_dark',R)

# One heavy cape with staggered square hems, forming a quiet, readable silhouette.
for label,x,w,bottom in [('Left',-.285,.285,.40),('Center',0,.33,.31),('Right',.285,.285,.48)]:
    offset={'Left':Vector((0,0,0)),'Center':Vector((0,.018,-.003)),'Right':Vector((0,.036,-.006))}[label]
    bone='cape_'+label.lower(); centers[bone]=Vector((x,.265,2.40))+offset; parents[bone]='chest'
    profile=[(-w/2,2.42),(w/2,2.42),(w/2,1.45),(w/2+.08,1.45),(w/2+.08,bottom+.15),(w/2-.01,bottom+.15),(w/2-.01,bottom),(-w/2+.025,bottom),(-w/2+.025,bottom+.23),(-w/2-.075,bottom+.23),(-w/2-.075,1.29),(-w/2,1.29)]
    R=Euler((math.radians(7),0,0)).to_matrix()
    profile=[(px,pz-2.42) for px,pz in profile]
    prism(label+'_Ancient_Cape',profile,.072,Vector((x,.265,2.42))+offset,bone,'cape',R)
for sign in (-1,1):
    side='L' if sign<0 else 'R'
    box(side+'_Mantle_Shoulder',(sign*.415,.025,2.365),(.35,.48,.125),'chest','cloth')
    box(side+'_Shoulder_Edging',(sign*.415,-.213,2.378),(.31,.022,.038),'chest','brass_dark')

# Arms remain anatomically continuous. Cubic bone hands match the game's hand language.
for side,sign in [('L',-1),('R',1)]:
    shoulder=Vector((sign*.45,.016,2.33)); elbow=Vector((sign*.555,-.055,1.955))
    wrist=Vector((sign*.635,-.330,1.845)) if side=='L' else Vector((sign*.495,-.370,1.905))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist})
    parents.update({upper:'chest',fore:upper,hand:fore})
    beam(side+'_Robe_Upper_Sleeve',shoulder,elbow,.262,.272,upper,'cloth')
    beam(side+'_Sleeve_Edge',elbow+Vector((0,0,.055)),elbow+Vector((0,0,-.026)),.280,.283,upper,'brass_dark')
    beam(side+'_Forearm_Bone',elbow,wrist,.093,.092,fore,'bone')
    beam(side+'_Forearm_Spectral_Remnant',elbow+Vector((0,.012,0)),wrist+Vector((0,.012,0)),.070,.070,fore,'spirit_dim')
    box(side+'_Square_Hand',wrist,(.168,.17,.145),hand,'bone')
    box(side+'_Wrist_Wrap',wrist+Vector((0,.033,.056)),(.177,.115,.035),hand,'cloth_dark')

# Staff and an open research tome distinguish the ancient scholar from a pure-energy manifestation.
centers['staff']=Vector((-.663,-.334,1.845)); parents['staff']='hand_L'
beam('Old_Staff_Shaft',(-.663,-.334,.58),(-.663,-.334,2.63),.069,.069,'staff','wood')
for z in (.62,1.40,2.51): box('Staff_Binding_'+str(z),(-.663,-.334,z),(.093,.091,.055),'staff','brass_dark')
for sign in (-1,1):
    beam(('Left' if sign<0 else 'Right')+'_Staff_Crook',(-.663+sign*.061,-.334,2.53),(-.663+sign*.132,-.334,2.77),.064,.067,'staff','bone')
    box(('Left' if sign<0 else 'Right')+'_Staff_Fork_End',(-.663+sign*.132,-.334,2.79),(.065,.066,.090),'staff','bone')
prism('Staff_Grave_Flame',[(-.062,2.59),(.067,2.59),(.067,2.73),(.025,2.73),(.025,2.87),(-.018,2.87),(-.018,2.80),(-.046,2.80),(-.046,2.69),(-.062,2.69)],.062,(-.663,-.334,0),'staff','glow')
centers['tome']=Vector((.523,-.416,1.992)); parents['tome']='hand_R'
R=Euler((math.radians(43),0,math.radians(-8))).to_matrix(); c=centers['tome']
for side,sign in [('Left',-1),('Right',1)]:
    box('Tome_'+side+'_Cover',c+R@Vector((sign*.115,0,-.025)),(.234,.302,.027),'tome','book_cover',R)
    box('Tome_'+side+'_Pages',c+R@Vector((sign*.112,0,.013)),(.211,.274,.056),'tome','paper',R)
box('Tome_Spine',c+R@Vector((0,0,-.004)),(.037,.30,.079),'tome','brass_dark',R)

# Residual spirit only emerges below the torn robe, not as an orbiting cube or a humanoid pair of legs.
for label,x,bottom,y in [('Left',-.145,.16,.07),('Center',.025,.10,.02),('Right',.188,.22,.11)]:
    bone='spectral_tail_'+label.lower(); centers[bone]=Vector((x,y,.88)); parents[bone]='body'
    profile=[(-.083,1.00),(.083,1.00),(.083,.54),(.043,.54),(.043,bottom+.07),(.013,bottom+.07),(.013,bottom),(-.034,bottom),(-.034,.37),(-.066,.37),(-.066,.66),(-.083,.66)]
    prism(label+'_Spectral_Remnant',profile,.11,(x,y,0),bone,'spirit_dim')

