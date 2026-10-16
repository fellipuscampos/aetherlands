"""Six human layouts descended from the corresponding basic halls."""
if ROLE=='guardian':
    top=hexhall('Citadel_Keep',0,.16,.36,.077,.93,7)
    doorway('Keep_Gate',0,.16-.36*.866,.148,.27,.48)
    for i,(x,y,w,h) in enumerate(((-.50,-.11,.235,.83),(.50,-.11,.235,.83),(0,.57,.235,1.16))):
        turret('Citadel_Tower_'+str(i),x,y,w,h)
    for sx in (-1,1):
        beam('Gate_Wall_'+str(sx),(sx*.19,-.18,.37),(sx*.50,-.11,.37),.17,'stone','02_HALL')
        box('Keep_Buttress_'+str(sx),(sx*.28,-.14,.52),(.10,.14,.75),'cutstone','02_HALL')
        dummy('Sentinel_'+str(sx),sx*.32,-.42,True)
    crest('Master_Shield',0,-.217,.97,'guardian',1.08)
    standard(.59,.26,1.33)
    design='Cidadela humana: grande torreão hexagonal de sete cursos azuis, três torres de ameias, portal fortificado e contrafortes; evolução do salão hexagonal dos guardiões.'
elif ROLE=='warrior':
    # An open amphitheatre with a front entrance; seats occupy the rear semicircle.
    polygon_prism('Arena_Sand',hexagon(.61,(0,-.06)),.077,.087,'sand','05_COURTYARD')
    for tier in range(3):
        r=.49+tier*.064
        for i in range(9):
            a=math.radians(4+i*21.5)
            box('Arena_Seat_%s_%s'%(tier,i),(r*math.cos(a),-.06+r*math.sin(a),.116+tier*.073),(.14,.068,.078),'cutstone','05_COURTYARD',a+math.pi/2)
            # Every upper seat has its own filled masonry footing.
            box('Arena_Seat_Support_%s_%s'%(tier,i),(r*math.cos(a),-.06+r*math.sin(a),.077+(.078+tier*.073)/2),(.14,.068,.078+tier*.073),'stone','05_COURTYARD',a+math.pi/2)
    pavilion('Royal_Gallery',0,.47,.52,.19,.288,.43,5)
    for sx in (-1,1):
        turret('Arena_Gate_'+str(sx),sx*.37,-.42,.15,.45)
    crest('Champion_Blades',0,.355,.57,'warrior',.85)
    stair('Gallery_Access',-.44,.05,.14,5,.048,.067)
    dummy('Duel_Target',-.14,-.04)
    box('Victory_Platform',(.19,.07,.13),(.20,.18,.106),'stone','06_TRAINING')
    sword('Victory_Sword',(.19,.07,.48),.54,0,'06_TRAINING')
    support('Victory_Stand',.19,.07,.17,.47,.033,'timber','06_TRAINING')
    standard(.63,.08,1.17)
    design='Anfiteatro humano em ferradura: três arquibancadas de pedra, tribuna real coberta de azul, entrada entre duas pequenas torres e pátio de duelos. Mantém a alvenaria e a heráldica de espadas do salão de armas.'
elif ROLE=='ranger':
    turret('Scout_Stone_Base',.13,.16,.35,.70,merlons=False)
    hall('Scout_Timber_Top',.13,.16,.30,.30,.76,.54,6,reg='door')
    box('Scout_Gallery',(.13,.16,1.06),(.49,.47,.043),'door','04_FOCUS')
    for sx in (-1,1):
        beam('Scout_Bracket_'+str(sx),(.13+sx*.15,.16,.91),(.13+sx*.225,.16,1.04),.035,'timber','04_FOCUS')
    rail('Scout_Balustrade',(-.10,-.058),(.36,-.058),1.065,.17)
    hall('Archery_Lodge',-.40,.11,.22,.36,.077,.30,4,reg='door')
    doorway('Lodge_Entry',-.40,-.07,.148,.12,.23)
    stair('Tower_Stair',.42,-.22,.14,8,.077,.057)
    for i,(x,y) in enumerate(((-.22,-.38),(.04,-.49),(.28,-.37))):
        target('Marksman_'+str(i),x,y,.365,.098)
    crest('Ranger_Bow',.13,-.014,1.16,'ranger',.75)
    standard(-.60,.21,1.17)
    design='Torre humana de vigia com base de pedra, pavimento superior de madeira, varanda cercada, telhado azul e escadaria externa; cabana lateral e três alvos ampliam o campo dos patrulheiros.'
elif ROLE=='cavalry':
    hall('Order_Gatehouse',0,.40,.48,.30,.077,.56,6)
    doorway('Order_Entry',0,.25,.148,.22,.38)
    crest('Order_Horseshoe',0,.217,.79,'cavalry',.92)
    for sx in (-1,1):
        pavilion('Stable_Wing_'+str(sx),sx*.44,.0,.29,.51,.077,.44,5)
        box('Stable_Straw_'+str(sx),(sx*.44,-.02,.108),(.23,.43,.015),'straw','06_TRAINING')
        horse('Order_Mount_'+str(sx),sx*.44,-.02,0,.69,.116)
        rail('Paddock_'+str(sx),(sx*.30,-.46),(sx*.52,-.32),.077,.15)
    roost('Griffon_Training_Perch',0,.39,1.31,.34)
    box('Order_Trough',(0,-.46,.137),(.23,.12,.12),'stone','06_TRAINING')
    box('Order_Water',(0,-.46,.202),(.17,.077,.017),'water','06_TRAINING')
    standard(.64,.19,1.24)
    design='Comando equestre humano de planta em U: corpo de oficiais ao fundo, duas alas de baias abertas, pátio central e poleiro elevado para treinamento de montarias aladas. Deriva do estábulo de madeira com brasão de ferradura.'
elif ROLE=='rogue':
    hall('Shadow_Townhouse',.10,.26,.52,.34,.077,.71,6)
    hexhall('Shadow_Watch',-.36,.12,.145,.077,1.14,5)
    hall('Shadow_Rear_Archive',.43,.33,.20,.22,.077,.41,4)
    doorway('Shadow_Door',.10,.09,.148,.22,.41)
    box('Shadow_Balcony',(.10,-.035,.733),(.51,.24,.041),'door','04_FOCUS')
    for sx in (-1,1):
        support('Balcony_Column_'+str(sx),.10+sx*.20,-.08,.077,.736,.044)
    rail('Balcony_Rail',(-.12,-.14),(.32,-.14),.754,.14)
    crest('Shadow_Hood',.10,.015,.97,'rogue',.83)
    box('Shadow_Cellar_Hatch',(-.18,-.40,.105),(.22,.17,.057),'door','05_COURTYARD')
    for sx in (-1,1):
        box('Hatch_Iron_'+str(sx),(-.18+sx*.072,-.40,.139),(.018,.17,.019),'iron','08_DETAILS')
    target('Knife_Target',.38,-.31,.35,.092)
    bench('Blade_Table',-.49,-.26)
    standard(.59,.18,1.22)
    design='Refúgio urbano humano de três alturas: casa de comando, torre hexagonal, arquivo baixo e varanda sustentada; alçapão, alvo de facas e bancada. A assimetria e o brasão de capuz evoluem a guilda dos ladinos.'
elif ROLE=='siege':
    for x in (-.30,.30):
        pavilion('Engineering_Bay_'+str(x),x,.30,.46,.37,.077,.63,5)
    box('Engineering_Partywall',(0,.30,.407),(.054,.37,.66),'stone','02_HALL')
    turret('Foundry_Chimney',-.53,.31,.13,1.13,merlons=False)
    box('Chimney_Mouth',(-.53,.31,1.235),(.092,.09,.012),'shadow','08_DETAILS')
    chassis('Great_Trebuchet',-.15,-.25,.34,.40)
    for sx in (-1,1):
        beam('Trebuchet_A_Frame_'+str(sx),(-.15+sx*.135,-.39,.28),(-.15+sx*.09,-.20,.70),.054,'timber','04_FOCUS')
        beam('Trebuchet_Rear_Frame_'+str(sx),(-.15+sx*.135,-.08,.28),(-.15+sx*.09,-.20,.70),.054,'timber','04_FOCUS')
    box('Trebuchet_Pivot',(-.15,-.20,.696),(.29,.047,.046),'iron','04_FOCUS')
    beam('Trebuchet_Arm',(-.15,-.38,.47),(-.15,.04,.97),.045,'door','04_FOCUS')
    box('Trebuchet_Counterweight',(-.15,-.37,.485),(.16,.13,.14),'stone','04_FOCUS')
    box('Trebuchet_Spoon',(-.15,.04,.988),(.14,.12,.044),'door','04_FOCUS')
    box('Trebuchet_Ammo',(-.15,.04,1.033),(.075,.068,.052),'ammunition','04_FOCUS')
    crane('Royal_Gantry',.57,-.15,1.38,.40)
    crest('Engineering_Cog',0,.082,.83,'siege',1.06)
    bench('Drawing_Table',-.54,-.31)
    standard(.54,.41,1.42)
    design='Grande oficina humana de duas naves azuis com baias abertas, chaminé de alvenaria, trebuchet de demonstração com contrapeso e guindaste alto; evolução do arsenal de montagem e catapulta.'
