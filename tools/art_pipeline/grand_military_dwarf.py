"""Granite military monuments with distinct vaults, terraced courts and machinery."""
if ROLE=='guardian':
    footprint=[(-.54,-.04),(.54,-.04),(.54,.22),(.24,.51),(-.24,.51),(-.54,.22)]
    polygon_prism('Deep_Fortress_Foot',footprint,.077,.20,'cutstone','02_HALL')
    polygon_prism('Deep_Fortress_Granite',footprint,.20,.77,'stone','02_HALL')
    for j in range(6):
        polygon_prism('Broad_Slate_Vault_'+str(j),[(x*(1-j*.115),.23+(y-.23)*(1-j*.105)) for x,y in footprint],.77+j*.047,.817+j*.047,'roof','03_ROOFS')
        box('Vault_Copper_Edge_'+str(j),(0,.23+(-.04-.23)*(1-j*.105)-.008,.78+j*.047),(1.08*(1-j*.115),.022,.026),'bronze','03_ROOFS')
    for sx in (-1,1):
        turret('Shoulder_Bastion_'+str(sx),sx*.43,-.13,.27,.71)
        box('Gate_Runestone_'+str(sx),(sx*.23,-.12,.51),(.12,.13,.60),'cutstone','02_HALL')
        box('Gate_Copper_Rune_'+str(sx),(sx*.23,-.193,.53),(.031,.02,.22),'bronze','08_DETAILS')
        dummy('Iron_Sentinel_'+str(sx),sx*.27,-.45,True)
    doorway('Fortress_Gate',0,-.08,.20,.28,.46)
    crest('Master_Copper_Shield',0,-.13,.86,'guardian',1.08)
    standard(.63,.14,1.19)
    design='Fortaleza anã baixa e larga de seis lados: massa contínua de granito, abóbada de ardósia em terraços, dois bastiões de ombro e portal entre monólitos rúnicos. Amplia a monumentalidade do salão anão sem repetir as três torres humanas.'
elif ROLE=='warrior':
    box('Square_Duel_Court',(0,-.09,.083),(.69,.57,.013),'sand','05_COURTYARD')
    for sx in (-1,1):
        for t in range(3):
            x=sx*(.41+t*.055);height=.12+t*.078
            box('Stone_Stand_%s_%s'%(sx,t),(x,-.01,.077+height/2),(.064,.57,height),'stone','05_COURTYARD')
            box('Copper_Seat_%s_%s'%(sx,t),(x,-.01,.077+height),(.071,.59,.021),'bronze','05_COURTYARD')
    hall('Hammer_Tribune',0,.41,.59,.26,.077,.46,5)
    doorway('Hammer_Tribune_Door',0,.28,.148,.22,.31)
    crest('Hammer_Champion',0,.25,.66,'warrior',1.0)
    for sx in (-1,1):
        support('Arena_Monolith_'+str(sx),sx*.31,-.46,.077,.57,.105,'cutstone','04_FOCUS')
        box('Monolith_Copper_Inlay_'+str(sx),(sx*.31,-.52,.39),(.046,.017,.19),'bronze','08_DETAILS')
    box('Arena_Anvil_Base',(-.17,-.01,.16),(.20,.18,.165),'stone','06_TRAINING')
    box('Arena_Anvil',(-.17,-.01,.265),(.23,.12,.061),'iron_light','06_TRAINING')
    dummy('Hammer_Practice',.18,-.10)
    bench('Arena_Armorer',-.05,-.40)
    standard(.63,.15,1.22)
    design='Arena anã retangular: arquibancadas de granito e cobre em dois lados, casa da tribuna ao fundo, monólitos rúnicos na entrada e bigorna de preparação. Deriva do salão de armas baixo e da tradição de reparo de armas anã.'
elif ROLE=='ranger':
    hexhall('Survey_Granite_Tower',-.06,.19,.25,.077,1.17,5)
    polygon_prism('Survey_Gallery',hexagon(.33,(-.06,.19)),.86,.91,'cutstone','04_FOCUS')
    for i,(x,y) in enumerate(hexagon(.29,(-.06,.19))):
        box('Survey_Merlon_'+str(i),(x,y,.991),(.086,.078,.17),'stone','04_FOCUS')
        box('Survey_Copper_Cap_'+str(i),(x,y,1.087),(.095,.089,.03),'bronze','04_FOCUS')
        beam('Survey_Gallery_Corbel_'+str(i),(-.06+(x+.06)*.7,.19+(y-.19)*.7,.68),(x,y,.87),.040,'cutstone','04_FOCUS')
    doorway('Survey_Entry',-.06,.19-.25*.866,.148,.20,.33)
    stair('Survey_Stair',.31,-.21,.14,8,.075,.059)
    box('Survey_Landing',(.20,.26,.69),(.37,.17,.04),'cutstone','05_COURTYARD')
    support('Survey_Landing_Pier',.31,.25,.077,.68,.085,'cutstone','05_COURTYARD')
    for i,(x,y) in enumerate(((-.39,-.28),(-.05,-.44),(.26,-.31))):
        target('Crossbow_Target_'+str(i),x,y,.36,.092)
    crest('Survey_Crossbow',-.06,-.060,.68,'ranger',.78)
    bench('Bolt_Workbench',-.46,.09)
    standard(.59,.26,1.22)
    design='Torre anã de levantamento em granito hexagonal: galeria de observação com seis contrafortes e ameias de cobre, coroa curta de ardósia e acesso lateral em pedra. Alvos e bancada de virotes ampliam o campo de treino anão.'
elif ROLE=='cavalry':
    # Three monumental stone arches are real open bays, not a solid barn.
    for i,x in enumerate((-.44,0,.44)):
        support('Order_Vault_Pier_'+str(i),x,.18,.077,.78,.13,'cutstone')
    box('Order_Vault_Back',(0,.47,.424),(.94,.07,.694),'stone','02_HALL')
    box('Order_Vault_Lintel',(0,.18,.79),(1.02,.14,.11),'stone','02_HALL')
    roof('Order_Stone_Vault',0,.34,1.07,.42,.844,5,True)
    for sx in (-1,1):
        horse('Armored_Mount_'+str(sx),sx*.22,.22,0,.78,.077)
        box('Bay_Straw_'+str(sx),(sx*.22,.22,.087),(.30,.35,.018),'straw','06_TRAINING')
        box('Order_Copper_Panel_'+str(sx),(sx*.44,.101,.50),(.079,.028,.24),'bronze','08_DETAILS')
    roost('Iron_Aerial_Dock',0,.34,1.34,.40)
    crest('Order_Iron_Shoe',0,.081,.84,'cavalry',.88)
    stair('Dock_Stair',.51,-.14,.13,6,.060,.063)
    rail('Order_Court_Rail',(-.46,-.40),(.20,-.40),.077,.17,'cutstone')
    box('Order_Stone_Trough',(-.44,-.17,.143),(.19,.13,.13),'cutstone','06_TRAINING')
    box('Order_Trough_Water',(-.44,-.17,.214),(.14,.088,.014),'water','06_TRAINING')
    standard(.61,.06,1.29)
    design='Ordem anã como grande cavalariça abobadada: três pilares de granito delimitam duas baias reais, lintel maciço, ardósia baixa e doca aérea central com cobre. Amplia os apoios minerais e as montarias do estábulo anão.'
elif ROLE=='rogue':
    # Stepped rock precinct with a single low concealed entrance.
    for i,(w,d,h,x,y) in enumerate(((1.03,.56,.30,-.02,.16),(.76,.42,.26,-.11,.21),(.47,.29,.21,-.20,.24))):
        bottom=.077+sum((.30,.26,.21)[:i])
        box('Understone_Terrace_'+str(i),(x,y,bottom+h/2),(w,d,h),'stone','02_HALL')
        roof('Understone_Slate_'+str(i),x,y,w+.04,d+.035,bottom+h-.026,2,True,False)
    doorway('Understone_Secret_Gate',-.15,-.13,.148,.25,.32)
    crest('Understone_Hood',-.15,-.157,.48,'rogue',.78)
    for sx in (-1,1):
        support('Hidden_Gate_Pier_'+str(sx),-.15+sx*.22,-.15,.077,.61,.095,'cutstone')
        box('Gate_Copper_Sigil_'+str(sx),(-.15+sx*.22,-.206,.40),(.036,.02,.15),'bronze','08_DETAILS')
    box('Understone_Vent',(.37,.23,.61),(.17,.17,.50),'stone','04_FOCUS')
    roof('Understone_Vent_Cap',.37,.23,.23,.23,.86,2,False,False)
    box('Understone_Vent_Slit',(.37,.137,.68),(.079,.021,.12),'shadow','08_DETAILS')
    target('Understone_Knife_Target',.31,-.31,.31,.094)
    bench('Hidden_Blade_Table',-.43,-.36)
    box('Understone_Sealed_Hatch',(.09,-.50,.104),(.20,.14,.056),'iron','05_COURTYARD')
    standard(.61,.14,1.17)
    design='Refúgio anão encaixado em três terraços de rocha: entrada recuada entre pilares, coberturas baixas de ardósia, ventilação fortificada e alçapão de metal. A guilda assimétrica evolui para uma sede protegida dentro da pedra.'
elif ROLE=='siege':
    pavilion('Colossus_Assembly_Vault',-.15,.29,.77,.43,.077,.61,5)
    for x,h in ((.38,1.36),(.54,1.11)):
        box('Copper_Smelter_'+str(x),(x,.32,(.077+h)/2),(.14,.16,h-.077),'stone','04_FOCUS')
        for z in (.29,.70,h-.09):
            box('Smelter_Copper_Collar_%s_%s'%(x,z),(x,.32,z),(.17,.19,.062),'bronze','04_FOCUS')
        box('Smelter_Cap_'+str(x),(x,.32,h),(.19,.21,.036),'bronze','04_FOCUS')
        box('Smelter_Mouth_'+str(x),(x,.32,h+.023),(.083,.10,.014),'shadow','08_DETAILS')
    chassis('Colossus_Test_Chassis',-.07,-.26,.42,.46)
    box('Colossus_Armored_Body',(-.07,-.26,.41),(.33,.37,.25),'iron','04_FOCUS')
    box('Colossus_Copper_Crest',(-.07,-.455,.42),(.24,.025,.11),'bronze','04_FOCUS')
    box('Colossus_Boiler',(-.07,-.12,.58),(.19,.17,.20),'bronze','04_FOCUS')
    box('Colossus_Boiler_Flue',(-.07,-.12,.77),(.07,.07,.21),'iron','04_FOCUS')
    for sx in (-1,1):
        box('Colossus_Arm_Base_'+str(sx),(-.07+sx*.20,-.26,.47),(.14,.13,.14),'bronze','04_FOCUS')
        beam('Colossus_Piston_'+str(sx),(-.07+sx*.20,-.28,.47),(-.07+sx*.20,-.49,.34),.047,'iron_light','04_FOCUS')
    crane('Copper_Assembly_Gantry',-.57,.22,1.38,.39)
    for obj in parts:
        if obj['part'].startswith('Copper_Assembly_Gantry'):
            for v in obj.data.vertices:
                v.co.x=2*(-.57)-v.co.x
    crest('Colossus_Cog',-.15,.052,.79,'siege',.96)
    bench('Copper_Parts_Bench',.47,-.24)
    standard(.63,.12,1.27)
    design='Arsenal anão de máquinas: abóbada aberta de granito, duas torres de fundição cintadas de cobre, pórtico de montagem e chassi de cerco com caldeira e pistões. Evolui a oficina básica para engenharia pesada, com volumetria industrial própria.'
