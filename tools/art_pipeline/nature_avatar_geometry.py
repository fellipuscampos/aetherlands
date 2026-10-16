# A living grove given a single deliberate silhouette; no stone armor or floating parts.
centers={'body':Vector((0,.08,1.1)),'chest':Vector((0,.05,1.95)),'head':Vector((0,.02,2.46)),'sapling':Vector((0,-.21,1.56))}
parents={'body':'root','chest':'body','head':'chest','sapling':'chest'}
box('Heartwood_Back',(0,.20,1.93),(.74,.25,.82),'chest','bark_dark')
box('Trunk_Lower',(0,.06,1.19),(.72,.55,.50),'body','bark')
box('Living_Hollow_Shadow',(0,.061,1.92),(.45,.07,.63),'chest','hollow')
# The trunk has a real front opening surrounding a living sprout.
for side,s in [('L',-1),('R',1)]:
    prism(side+'_Hollow_Trunk_Rail',[(s*x,z) for x,z in [(.21,1.53),(.46,1.53),(.46,1.76),(.51,1.76),(.51,2.14),(.39,2.14),(.39,2.36),(.25,2.36),(.25,2.11),(.21,2.11)]],.50,(0,.01,0),'chest','bark')
    beam(side+'_Chest_Cut_Edge',(s*.235,-.25,1.63),(s*.235,-.25,2.13),.055,.025,'chest','cut_wood')
box('Hollow_Upper_Lintel',(0,-.01,2.27),(.64,.47,.16),'chest','bark')
box('Hollow_Root_Sill',(0,-.045,1.56),(.66,.55,.15),'chest','bark')
box('Sapling_Soil',(0,-.15,1.647),(.31,.22,.065),'chest','moss')
beam('Sapling_Stem',(0,-.22,1.67),(.015,-.22,2.08),.048,.042,'sapling','sapwood')
for label,a,b,w in [('Left',(.005,-.22,1.86),(-.15,-.22,1.98),.12),('Right',(.015,-.22,1.98),(.145,-.22,2.11),.11)]:
    beam('Sapling_'+label+'_Twig',a,b,.026,.022,'sapling','sapwood')
    box('Sapling_'+label+'_Leaf',b,(w,.055,.09),'sapling','fresh_leaf',Euler((0,math.radians(-20 if label=='Left' else 20),0)).to_matrix())
box('Sapling_Apical_Bud',(.016,-.22,2.13),(.075,.065,.075),'sapling','fresh_leaf')
# A carved wooden face with recessed eyes; features remain texture-sized and cubic.
box('Neck',(0,.02,2.34),(.26,.32,.20),'head','bark_dark')
prism('Ancient_Wooden_Mask',[(-.28,-.23),(.28,-.23),(.28,.17),(.20,.17),(.20,.29),(-.20,.29),(-.20,.17),(-.28,.17)],.39,(0,.015,2.53),'head','mask')
for side,s in [('L',-1),('R',1)]:
    box(side+'_Eye_Recess',(s*.12,-.186,2.57),(.12,.016,.065),'head','hollow')
    box(side+'_Amber_Eye',(s*.12,-.198,2.57),(.063,.012,.032),'head','amber')
    box(side+'_Mask_Brow',(s*.12,-.202,2.625),(.17,.025,.045),'head','cut_wood')
box('Mask_Chin',(0,-.17,2.315),(.22,.12,.095),'head','cut_wood')
# Branch crown: broad empty spaces and a few strong forks instead of a busy halo.
for side,s in [('L',-1),('R',1)]:
    beam(side+'_Crown_Base',(s*.18,.07,2.69),(s*.32,.07,2.89),.13,.13,'head','bark')
    beam(side+'_Crown_Rising_Bough',(s*.32,.07,2.87),(s*.44,.07,3.10 if s<0 else 3.04),.095,.095,'head','bark')
    beam(side+'_Crown_Outer_Fork',(s*.32,.07,2.88),(s*.63,.07,2.99),.084,.085,'head','bark')
    box(side+'_Crown_Cut_Tip',(s*.44,.07,3.10 if s<0 else 3.04),(.094,.093,.045),'head','cut_wood')
    box(side+'_Crown_Leaf_Cluster',(s*.64,.075,2.97),(.22,.19,.105),'head','leaf_light')
# Connected wooden arms, square hands, shoulder foliage attached to the upper-arm pivots.
for side,s in [('L',-1),('R',1)]:
    shoulder=Vector((s*.55,.01,2.15)); elbow=Vector((s*.78,-.045,1.63)); wrist=Vector((s*.83,-.20,1.20))
    upper='upper_arm_'+side; fore='forearm_'+side; hand='hand_'+side
    centers.update({upper:shoulder,fore:elbow,hand:wrist}); parents.update({upper:'chest',fore:upper,hand:fore})
    beam(side+'_Wooden_Upper_Arm',shoulder,elbow,.25,.27,upper,'bark')
    box(side+'_Elbow_Knot',elbow,(.25,.27,.21),fore,'bark_dark')
    beam(side+'_Wooden_Forearm',elbow,wrist,.29,.29,fore,'bark')
    box(side+'_Square_Root_Hand',wrist+Vector((0,-.015,-.105)),(.36,.36,.33),hand,'bark')
    box(side+'_Hand_Moss',(s*.83,-.025,1.24),(.33,.16,.045),hand,'moss')
    # Three deliberate layers, each built from contiguous angular leaf masses.
    for j,(x,y,z,size,kind) in enumerate([
        (.56,.025,2.38,(.55,.53,.20),'leaf_light'),
        (.68,.04,2.23,(.64,.63,.20),'leaf'),
        (.76,.105,2.065,(.59,.67,.17),'leaf_dark'),
        (.52,.34,2.19,(.43,.31,.25),'leaf')]):
        box(side+'_Leaf_Mantle_'+str(j),(s*x,y,z),size,upper,kind)
    box(side+'_Mantle_Outer_Step',(s*.995,.075,2.145),(.19,.38,.16),upper,'leaf')
    # One quiet moss patch on each forearm follows the actual branch surface.
    beam(side+'_Forearm_Moss',elbow+Vector((s*.153,.03,-.04)),wrist+Vector((s*.153,.03,.05)),.022,.14,fore,'moss')
# Legs are sturdy roots, not boots or stone-golem columns.
for side,s in [('L',-1),('R',1)]:
    hip=Vector((s*.245,.075,1.07)); knee=Vector((s*.32,.035,.61)); ankle=Vector((s*.385,-.035,.20))
    thigh='thigh_'+side; shin='shin_'+side; foot='root_foot_'+side
    centers.update({thigh:hip,shin:knee,foot:ankle}); parents.update({thigh:'body',shin:thigh,foot:shin})
    beam(side+'_Upper_Root',hip,knee,.33,.38,thigh,'bark')
    box(side+'_Root_Knee',knee,(.34,.37,.22),shin,'bark_dark')
    beam(side+'_Lower_Root',knee,ankle,.31,.36,shin,'bark')
    # Flat soles all contact Z=0; tapering stepped tips read as spread roots.
    box(side+'_Root_Heel',(s*.385,.01,.105),(.40,.47,.21),foot,'bark')
    box(side+'_Root_Front',(s*.385,-.29,.073),(.29,.34,.146),foot,'bark')
    box(side+'_Root_Outer',(s*.64,.01,.068),(.29,.24,.136),foot,'bark')
    box(side+'_Root_Rear',(s*.43,.34,.062),(.23,.26,.124),foot,'bark')
    box(side+'_Root_Moss',(s*.38,-.13,.222),(.30,.34,.047),foot,'moss')
# Sparse leaves growing from the waist; keep the hollow and mask unobstructed.
for side,s in [('L',-1),('R',1)]:
    box(side+'_Hip_Leaf',(s*.37,.015,1.16),(.34,.51,.17),'body','leaf_dark')
    box(side+'_Hip_Leaf_Step',(s*.44,.07,1.05),(.21,.36,.13),'body','leaf')
