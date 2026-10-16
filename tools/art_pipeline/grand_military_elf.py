"""Military pavilions, living trees, elevated pods and open botanical engineering."""
if ROLE=='guardian':
    # Three slender pavilions frame the approach to a living sentinel crown.
    hexhall('Leaf_Shield_Pavilion',0,.27,.24,.077,.65,7)
    for sx in (-1,1):
        pavilion('Sentinel_Wing_'+str(sx),sx*.40,.11,.27,.38,.077,.51,5)
        tree('Living_Sentinel_'+str(sx),sx*.46,.35,1.20,.15)
        dummy('Leaf_Sentinel_'+str(sx),sx*.26,-.38,True)
        beam('Living_Gate_Branch_'+str(sx),(sx*.46,.13,.36),(sx*.29,-.10,.80),.039,'timber','04_FOCUS')
    doorway('Shield_Pavilion_Gate',0,.27-.24*.866,.148,.21,.39)
    crest('Leaf_Master_Shield',0,-.055,.79,'guardian',.92)
    box('Leaf_Master_Shield_Mount',(0,.015,.74),(.15,.17,.18),'timber','07_FACTION')
    for sx in (-1,1):
        box('Living_Approach_Foot_'+str(sx),(sx*.22,-.17,.102),(.082,.085,.05),'cutstone','05_COURTYARD')
        support('Living_Approach_'+str(sx),sx*.22,-.17,.10,.52,.028)
        beam('Living_Arch_'+str(sx),(sx*.22,-.17,.50),(0,-.17,.63),.031,'timber','05_COURTYARD')
    standard(.64,.09,1.22)
    design='Bastião élfico de três pavilhões: salão hexagonal de escudos, duas alas abertas, árvores sentinelas e arco de galhos na aproximação. Evolui o pavilhão e o mirante vivo do salão élfico; não usa torres de ameias.'
elif ROLE=='warrior':
    polygon_prism('Leaf_Duel_Paving',hexagon(.39,(0,-.08)),.077,.103,'cutstone','05_COURTYARD')
    polygon_prism('Leaf_Duel_Inlay',hexagon(.31,(0,-.08)),.103,.108,'formation','05_COURTYARD')
    for i,(x,y,a) in enumerate(((-.43,.04,.0),(.43,.04,.0),(0,.44,.0))):
        for j in range(2):
            r=.085+j*.050
            height=.11+j*.077
            polygon_prism('Petal_Stand_%s_%s'%(i,j),hexagon(r,(x,y)),.077,.077+height,'cutstone','05_COURTYARD')
        tree('Arena_Shade_'+str(i),x,y,1.15,.145)
    pavilion('Leaf_Duel_Judges',0,.40,.38,.21,.27,.36,4)
    for sx in (-1,1):
        support('Judges_Foot_'+str(sx),sx*.13,.40,.077,.31,.04)
    crest('Leaf_Duel_Swords',0,.257,.52,'warrior',.79)
    for sx in (-1,1):
        support('Duel_Gate_'+str(sx),sx*.22,-.49,.077,.69,.035)
        beam('Duel_Gate_Bough_'+str(sx),(sx*.22,-.49,.66),(sx*.06,-.49,.81),.028,'timber','05_COURTYARD')
        leaf('Duel_Gate_Leaf_'+str(sx),(sx*.21,-.50,.62),.077,.12,.021,'gold','05_COURTYARD')
    dummy('Leaf_Duel_Target',.15,-.08)
    bench('Sword_Care_Bench',-.18,-.34)
    standard(.63,.17,1.22)
    design='Arena élfica de duelo em pétalas: piso hexagonal claro, três terraços pequenos com árvores de sombra, tribuna leve e portal de galhos abertos. Mantém espadas finas, madeira e folhas do salão de armas élfico.'
elif ROLE=='ranger':
    tree('Great_Lookout_Tree',-.02,.17,1.71,.29)
    for i,(r,z) in enumerate(((.29,.54),(.32,1.03),(.25,1.48))):
        polygon_prism('Tree_Lookout_Deck_'+str(i),hexagon(r,(-.02,.17)),z,z+.04,'door','04_FOCUS')
        for sx in (-1,1):
            beam('Tree_Deck_Branch_%s_%s'%(i,sx),(-.02,.17,z-.20),(-.02+sx*r*.69,.17,z+.01),.035,'timber','04_FOCUS')
        rail('Tree_Deck_Rail_'+str(i),(-.02-r*.70,.17-r*.866),(-.02+r*.70,.17-r*.866),z+.04,.13)
    pavilion('Leaf_Lookout_Pod',.0,.16,.31,.25,1.48,.27,4)
    for i in range(12):
        z=.11+i*.105
        x=.23 if i<6 else -.24
        y=-.13+i*.062 if i<6 else .23-(i-6)*.062
        box('Tree_Stair_'+str(i),(x,y,z),(.13,.085,.033),'door','05_COURTYARD')
    beam('Tree_Stair_Stringer_A',(.23,-.13,.08),(.23,.18,.66),.039,'timber','05_COURTYARD')
    beam('Tree_Stair_Stringer_B',(-.24,.24,.70),(-.24,-.07,1.30),.039,'timber','05_COURTYARD')
    box('Tree_Stair_Turn',(-.01,.26,.684),(.59,.13,.041),'door','05_COURTYARD')
    support('Tree_Turn_Stilt',-.24,.26,.077,.70,.036,'timber','05_COURTYARD')
    for i,(x,y) in enumerate(((-.44,-.22),(-.12,-.44),(.29,-.33))):
        target('Woodland_Target_'+str(i),x,y,.33,.089)
    crest('Woodland_Bow',.0,-.009,1.68,'ranger',.65)
    standard(.58,.23,1.18)
    design='Mirante élfico numa árvore viva: três plataformas apoiadas nos galhos, escada envolvente de madeira, guarda-corpos e pequeno abrigo elevado com telhado verde. O bosque e os arcos do campo básico tornam-se a própria estrutura da torre.'
elif ROLE=='cavalry':
    # Stable wings set at different depths around a tall central living roost.
    pavilion('Leaf_Stable_Left',-.37,.15,.30,.46,.077,.50,6)
    pavilion('Leaf_Stable_Right',.34,.28,.34,.34,.077,.43,5)
    horse('Leaf_Mount_Left',-.37,.10,0,.70,.124)
    horse('Leaf_Mount_Right',.34,.26,0,.73,.124)
    tree('Aerial_Order_Tree',0,.37,1.43,.24)
    roost('Leaf_Nest',0,.37,1.21,.35)
    # Curved approach rail is formed by three short branch segments.
    for i,(a,b) in enumerate((((-.48,-.30),(-.27,-.43)),((-.27,-.43),(.0,-.50)),((.0,-.50),(.25,-.40)))):
        rail('Leaf_Paddock_'+str(i),a,b,.077,.13)
    pavilion('Order_Leaf_Portal',-.03,-.07,.34,.14,.077,.48,4)
    crest('Leaf_Order_Shoe',-.03,-.163,.66,'cavalry',.76)
    box('Leaf_Trough',(.42,-.15,.129),(.17,.12,.104),'cutstone','06_TRAINING')
    box('Leaf_Trough_Water',(.42,-.15,.185),(.13,.082,.012),'water','06_TRAINING')
    standard(.63,.07,1.18)
    design='Ordem élfica em meia-lua: duas cavalariças leves em profundidades diferentes, árvore central com ninho aéreo e pórtico avançado de folhas. Evolui as baias abertas, madeira fina e vegetação do estábulo élfico.'
elif ROLE=='rogue':
    tree('Shadow_Tree_Left',-.31,.23,1.48,.21)
    tree('Shadow_Tree_Right',.31,.28,1.19,.19)
    hexhall('Shadow_Left_Pod',-.31,.23,.19,.69,.44,6)
    hexhall('Shadow_Right_Pod',.31,.28,.17,.48,.36,5)
    for x,y,z in ((-.31,.23,.69),(.31,.28,.48)):
        for sx in (-1,1):
            support('Pod_Stilt_%s_%s'%(x,sx),x+sx*.15,y-.07,.077,z,.029)
    box('Shadow_Bridge',(0,.24,.733),(.42,.16,.042),'door','04_FOCUS')
    for x in (-.13,.13):
        support('Shadow_Bridge_Pile_'+str(x),x,.24,.077,.73,.027)
    rail('Shadow_Bridge_Rail',(-.21,.153),(.21,.153),.754,.14)
    stair('Shadow_Pod_Stair',-.31,-.27,.17,8,.075,.063)
    doorway('Shadow_Pod_Gate',-.31,.23-.19*.866,.74,.17,.30)
    crest('Leaf_Shadow_Hood',-.31,-.055,1.12,'rogue',.72)
    # Bracket connects the hanging coat-of-arms to the pod's actual front.
    box('Shadow_Sign_Bracket',(-.31,.015,1.12),(.10,.16,.038),'timber','07_FACTION')
    box('Leaf_Secret_Hatch',(.12,-.30,.108),(.20,.15,.060),'door','05_COURTYARD')
    target('Leaf_Knife_Target',.43,-.19,.30,.083)
    bench('Leaf_Blade_Bench',.10,-.47)
    standard(.62,.15,1.12)
    design='Refúgio élfico de duas casas suspensas: árvores e estacas sustentam pods hexagonais em alturas distintas, unidos por ponte cercada; escadaria, alçapão e treino de facas no solo. A guilda evolui para uma rede escondida entre copas.'
elif ROLE=='siege':
    # Two open wing roofs at contrasting angles around botanical lifting gear.
    pavilion('Living_Assembly_Left',-.35,.20,.35,.48,.077,.57,6)
    pavilion('Living_Assembly_Right',.32,.36,.45,.24,.077,.48,5)
    tree('Living_Hoist_Tree',.16,.28,1.53,.22)
    beam('Living_Hoist_Bough',(.16,.28,1.18),(.50,-.02,1.38),.052,'timber','04_FOCUS')
    box('Leaf_Hoist_Rope',(.50,-.02,1.14),(.012,.012,.48),'rope','04_FOCUS')
    box('Leaf_Hoist_Load',(.50,-.02,.884),(.12,.11,.049),'door','04_FOCUS')
    ballista('Great_Leaf_Ballista',-.13,-.27,.54)
    crest('Leaf_Engineering_Cog',-.35,-.062,.81,'siege',.88)
    # A rear branch fixes the sign to the pavilion's lintel.
    box('Leaf_Cog_Mount',(-.35,-.025,.76),(.19,.074,.15),'timber','07_FACTION')
    bench('Leaf_Design_Bench',.45,-.27)
    for i,(x,y) in enumerate(((-.56,-.30),(-.47,-.48))):
        box('Leaf_Timber_Stock_'+str(i),(x,y,.128),(.12,.18,.10),'timber','06_TRAINING')
    standard(.62,.19,1.24)
    design='Arsenal élfico botânico: dois pavilhões abertos com coberturas em alas, árvore-guindaste de galho vivo, grande balista de madeira e área de projetos. Amplia a oficina básica sem usar chaminés ou massas de granito das outras civilizações.'
