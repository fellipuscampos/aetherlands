"""Six clan structures: heavy frames, pits, scaffolds and an industrial ram yard."""
if ROLE=='guardian':
    footprint=[(-.34,-.06),(.30,-.06),(.40,.26),(.06,.58),(-.37,.32)]
    polygon_prism('Clan_Basalt_Platform',footprint,.077,.19,'stone','02_HALL')
    polygon_prism('Clan_Command_Lodge',footprint,.19,.88,'door','02_HALL')
    for i,(x,y) in enumerate(footprint):
        support('Clan_Frame_'+str(i),x,y,.077,.92,.083)
    roof('Clan_Command',.01,.23,.83,.59,.90,7,True)
    for i,(x,y,h) in enumerate(((-.51,-.08,1.03),(.48,.06,.79))):
        turret('Clan_Iron_Tower_'+str(i),x,y,.23,h,reg='door',merlons=False)
        for z in (.29,.67,h+.07):
            box('Clan_Tower_Belt_%s_%s'%(i,z),(x,y,z),(.28,.28,.05),'iron','04_FOCUS')
        for sx in (-1,1):
            for sy in (-1,1):
                support('Clan_Upper_Post_%s_%s_%s'%(i,sx,sy),x+sx*.099,y+sy*.099,h+.09,h+.34,.05)
        roof('Clan_Tower_Canopy_'+str(i),x,y,.35,.34,h+.34,3,False)
    doorway('Clan_Great_Gate',.01,-.07,.19,.27,.48)
    crest('Clan_Shield',.01,-.10,.94,'guardian',1.03)
    for sx in (-1,1):
        dummy('Clan_Sentinel_'+str(sx),sx*.27,-.41,True)
    standard(.61,.29,1.25)
    design='Bastião orc de clã: salão pentagonal de madeira pesada sobre basalto, grande cobertura longitudinal de couro vermelho e duas torres desiguais de ferro com mirantes cobertos. Preserva os pórticos com presas e escudos do salão orc.'
elif ROLE=='warrior':
    polygon_prism('Blood_Pit',hexagon(.41,(0,-.07)),.077,.085,'sand','05_COURTYARD')
    # Three separate timber grandstands leave open entrances between them.
    for i,(x,y,w,d,a) in enumerate(((-.47,.03,.19,.51,0),(.47,.03,.19,.51,0),(0,.43,.56,.19,0))):
        for t in range(3):
            if i<2:
                px=x+(-1 if i==0 else 1)*(t-1)*.051; py=y
                sw,sd=.066,d
            else:
                px=x; py=y+(t-1)*.052; sw,sd=w,.068
            height=.10+t*.085
            box('Pit_Stand_%s_%s'%(i,t),(px,py,.077+height/2),(sw,sd,height),'door','05_COURTYARD')
            box('Pit_Iron_Seat_%s_%s'%(i,t),(px,py,.077+height+.007),(sw+.009,sd+.009,.018),'iron','05_COURTYARD')
    for sx in (-1,1):
        support('Pit_Gate_'+str(sx),sx*.19,-.48,.077,.78,.10)
        box('Pit_Gate_Iron_'+str(sx),(sx*.19,-.48,.72),(.13,.13,.064),'iron','04_FOCUS')
        tusk('Pit_Gate_Tusk_'+str(sx),(sx*.19,-.48,.75),.25,.10,.076,-sx,'04_FOCUS')
    box('Pit_Crossbeam',(0,-.48,.65),(.46,.11,.075),'timber','02_HALL')
    pavilion('Clan_Chief_Tribune',0,.45,.43,.20,.36,.32,3)
    # Filled supports under the chief's raised viewing box.
    for sx in (-1,1):
        support('Chief_Tribune_Foot_'+str(sx),sx*.15,.46,.077,.38,.072)
    crest('Pit_Axes',0,.305,.70,'warrior',.91)
    dummy('Arena_Straw',.18,.0)
    box('Arena_Drum',(-.19,-.02,.20),(.15,.15,.24),'door','06_TRAINING')
    box('Drum_Hide',(-.19,-.02,.328),(.16,.16,.019),'bone','06_TRAINING')
    standard(.63,.12,1.17)
    design='Arena orc aberta: fosso de areia, três arquibancadas pesadas separadas, tribuna do chefe e entrada baixa entre presas monumentais. Madeira, cintas de ferro e coberturas vermelhas evoluem o salão de armas do clã.'
elif ROLE=='ranger':
    # Tall open scaffold; no solid masonry tower copied from the human version.
    for sx in (-1,1):
        for sy in (-1,1):
            x=.02+sx*.19;y=.13+sy*.19
            support('Hunt_Scaffold_%s_%s'%(sx,sy),x,y,.077,1.36,.072)
    for sy in (-1,1):
        beam('Hunt_Crossbrace_'+str(sy),(-.17,.13+sy*.19,.25),(.21,.13+sy*.19,1.22),.038,'timber','04_FOCUS')
    for z in (.58,1.24):
        box('Hunt_Deck_'+str(z),(.02,.13,z),(.47,.45,.051),'door','04_FOCUS')
        rail('Hunt_Front_Rail_'+str(z),(-.20,-.09),(.24,-.09),z+.026,.15)
    roof('Hunt_Hide_Canopy',.02,.13,.57,.55,1.36,5,True)
    for side in (-1,1):
        for i in range(7):
            # Switchback timber staircase with grounded side stringers.
            box('Hunt_Stair_%s_%s'%(side,i),(.32 if side==1 else -.31,-.21+i*.06,.11+i*.078+(0 if side==1 else .55)),(.13,.078,.039),'door','05_COURTYARD')
        beam('Hunt_Stringer_'+str(side),(.32 if side==1 else -.31,-.22,.077+(0 if side==1 else .55)),(.32 if side==1 else -.31,.19,.63+(0 if side==1 else .55)),.052,'timber','05_COURTYARD')
    box('Hunt_Stair_Turn',(.01,.26,.64),(.78,.12,.048),'door','04_FOCUS')
    for sx in (-1,1):
        support('Hunt_Turn_Support_'+str(sx),sx*.32,.25,.077,.65,.065)
    crest('Hunt_Bow',.02,-.102,1.05,'ranger',.82)
    for sx in (-1,1):
        box('Hunt_Sign_Hanger_'+str(sx),(.02+sx*.083,-.089,1.19),(.024,.034,.13),'iron','07_FACTION')
    for i,(x,y) in enumerate(((-.42,-.30),(-.13,-.48),(.17,-.46))):
        target('Clan_Marksman_'+str(i),x,y,.34,.094)
    standard(.59,.28,1.16)
    design='Torre orc de patrulha em andaime aberto: quatro grandes postes, duas plataformas com travamentos diagonais, escada de madeira em retorno e cobertura de couro vermelho. Os alvos e arco reforçado mantêm a linguagem do campo orc.'
elif ROLE=='cavalry':
    pavilion('War_Mount_Longhouse',-.25,.23,.62,.48,.077,.57,7)
    box('War_Mount_Divider',(-.25,.23,.33),(.035,.45,.46),'timber','02_HALL')
    horse('Clan_Mount_A',-.43,.19,0,.70,.124)
    horse('Clan_Mount_B',-.08,.19,0,.70,.124)
    hall('Beast_Handler_Tent',.43,.20,.24,.36,.077,.34,4,reg='door')
    doorway('Handler_Entry',.43,.02,.148,.12,.24)
    crest('War_Mount_Shoe',-.25,-.027,.79,'cavalry',.95)
    roost('Tusked_Aerial_Perch',.42,.22,1.06,.31)
    for sx in (-1,1):
        box('Roost_Tusk_Socket_'+str(sx),(.42+sx*.10,.22,1.11),(.057,.071,.057),'iron','04_FOCUS')
        tusk('Roost_Tusk_'+str(sx),(.42+sx*.10,.22,1.135),.24,.063,.057,-sx,'04_FOCUS')
    rail('War_Mount_Front_Fence',(-.43,-.41),(.13,-.41),.077,.18)
    for i,x in enumerate((-.48,-.32,-.16)):
        support('War_Lance_'+str(i),x,-.43,.077,.67,.016,'timber','06_TRAINING')
        box('War_Lance_Point_'+str(i),(x,-.43,.69),(.032,.026,.065),'bone','06_TRAINING')
    box('Clan_Trough',(.27,-.28,.132),(.22,.13,.11),'stone','06_TRAINING')
    box('Clan_Water',(.27,-.28,.191),(.16,.09,.014),'water','06_TRAINING')
    standard(.61,-.01,1.24)
    design='Ordem orc de montarias em planta L: salão comprido de duas baias, abrigo separado dos tratadores, paliçada baixa, lanças e poleiro com presas. Evolui o estábulo orc sem adotar a planta humana em U.'
elif ROLE=='rogue':
    # Broad low stealth den, elevated rear observation cage, concealed side hatch.
    footprint=[(-.50,-.04),(.30,-.04),(.47,.24),(.08,.52),(-.48,.33)]
    polygon_prism('Sneak_Den_Foot',footprint,.077,.15,'stone','02_HALL')
    polygon_prism('Sneak_Den_Wood',footprint,.15,.58,'door','02_HALL')
    for i,(x,y) in enumerate(footprint):
        support('Sneak_Frame_'+str(i),x,y,.077,.60,.075)
    roof('Sneak_Broad_Hide',-.05,.21,1.07,.64,.61,5,True)
    doorway('Sneak_Entry',-.19,-.05,.148,.25,.34)
    crest('Sneak_Hood',-.19,-.16,.67,'rogue',.89)
    box('Sneak_Sign_Bracket',(-.19,-.075,.605),(.14,.16,.19),'timber','07_FACTION')
    turret('Sneak_Rear_Lookout',.22,.42,.18,.89,reg='door',merlons=False)
    roof('Sneak_Lookout',.22,.42,.29,.28,.998,3)
    box('Sneak_Cellar',(.38,-.24,.108),(.27,.21,.060),'door','05_COURTYARD')
    for sx in (-1,1):
        box('Cellar_Iron_Band_'+str(sx),(.38+sx*.082,-.24,.145),(.026,.21,.017),'iron','08_DETAILS')
    pavilion('Sneak_Prep_Awning',-.39,-.26,.29,.19,.077,.33,2)
    bench('Poison_Bench',-.39,-.26)
    for i,(x,y) in enumerate(((.54,.20),(.41,.44),(-.51,.39))):
        box('Camouflage_Shrub_'+str(i),(x,y,.18),(.15,.13,.20),'foliage','08_DETAILS')
    target('Sneak_Knife_Target',.09,-.42,.32,.083)
    standard(.59,.05,1.14)
    design='Refúgio orc baixo e largo de cinco lados, gaiola de observação recuada, abrigo de preparo e grande alçapão lateral; arbustos encobrem os flancos. A cabana e as coberturas de couro vermelho evoluem a guilda orc.'
elif ROLE=='siege':
    pavilion('Ram_Assembly_Hangar',-.26,.25,.64,.44,.077,.65,6)
    hall('Iron_Forge',.40,.28,.26,.36,.077,.47,4,reg='stone')
    for x,h in ((.32,1.16),(.47,1.35)):
        box('Forge_Stack_'+str(x),(x,.38,(h+.077)/2),(.10,.12,h-.077),'stone','04_FOCUS')
        box('Forge_Stack_Cap_'+str(x),(x,.38,h),(.14,.16,.04),'iron','04_FOCUS')
        box('Forge_Stack_Mouth_'+str(x),(x,.38,h+.022),(.067,.085,.012),'shadow','08_DETAILS')
    chassis('Great_Clan_Ram',-.10,-.24,.38,.49)
    for sx in (-1,1):
        support('Ram_Cage_'+str(sx),-.10+sx*.16,-.24,.25,.70,.052)
    roof('Ram_Hide',-.10,-.24,.47,.58,.705,3,True,False)
    box('Ram_Battering_Log',(-.10,-.25,.455),(.13,.65,.13),'timber','04_FOCUS')
    box('Ram_Iron_Nose',(-.10,-.578,.455),(.17,.085,.17),'iron_light','04_FOCUS')
    for sx in (-1,1):
        beam('Ram_Hanging_Chain_'+str(sx),(-.10+sx*.055,-.22,.72),(-.10+sx*.055,-.22,.49),.016,'iron','04_FOCUS')
    crane('Clan_Loading_Crane',-.57,.23,1.37,.37)
    # Boom points inward rather than beyond the hex edge.
    for obj in parts:
        if obj['part'].startswith('Clan_Loading_Crane'):
            for v in obj.data.vertices:
                v.co.x=2*(-.57)-v.co.x
    crest('Clan_Foundry_Cog',-.26,.011,.92,'siege',.93)
    bench('Clan_Iron_Bench',.49,-.25)
    standard(.60,.19,1.38)
    design='Arsenal orc de aríetes: hangar de madeira ligado a uma forja de basalto com duas chaminés desiguais, aríete coberto e suspenso por correntes, guindaste de clã e bancada de ferro. Evolui as ferragens, presas e oficina aberta do arsenal básico.'
