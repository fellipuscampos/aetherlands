body_top={1:.180,2:.205,3:.216}[level]; coping_top=body_top+.024
for edge in range(6):
    spans=[(-.449,.449)] if edge!=1 else [(-.449,-.119),(.119,.449)]
    for section,(left,right) in enumerate(spans):
        x=(left+right)/2; width=right-left
        edge_box(f'Edge_{edge}_Moss_Foot_{section}',edge,x,0,width,.092,0,.030,'foundation')
        for course in range(3):
            columns=3 if level==1 else 4
            for column in range(columns):
                a=left+width*column/columns; b=left+width*(column+1)/columns
                region='cutstone' if level==3 or (level==2 and course==1) else 'stone'
                edge_box(f'Edge_{edge}_Masonry_{section}_{course}_{column}',edge,(a+b)/2,0,b-a,.071,
                    .025+(body_top-.025)*course/3,.025+(body_top-.025)*(course+1)/3,region)
        edge_box(f'Edge_{edge}_Ivory_Coping_{section}',edge,x,0,width,.086,body_top,coping_top,'cutstone')
        if level>=2:
            count=5 if level==2 else 6
            if edge==1: count=2
            for merlon in range(count):
                xx=left+width*(merlon+.5)/count
                edge_box(f'Edge_{edge}_Leaf_Merlon_Base_{section}_{merlon}',edge,xx,0,.041,.071,coping_top,coping_top+.030,'cutstone')
                edge_box(f'Edge_{edge}_Leaf_Merlon_Tip_{section}_{merlon}',edge,xx,0,.023,.051,coping_top+.030,coping_top+.046,'cutstone')
        if level>=2 and edge!=1:
            edge_box(f'Edge_{edge}_Branch_Post_{section}',edge,x,.032,.022,.012,.048,body_top-.012,'timber')
            for side in (-1,1):
                edge_box(f'Edge_{edge}_Branch_Capital_{section}_{side}',edge,x+side*.019,.032,.022,.013,body_top-.044,body_top-.030,'timber')
                edge_box(f'Edge_{edge}_Branch_End_{section}_{side}',edge,x+side*.035,.032,.017,.013,body_top-.030,body_top-.017,'timber')
        if level==3:
            edge_box(f'Edge_{edge}_Emerald_Inlay_{section}',edge,x,.036,width,.005,.079,.091,'roof_dark')
            for side in (-1,1):
                xx=x+side*min(.20,width*.3)
                edge_box(f'Edge_{edge}_Gold_Leaf_Stem_{section}_{side}',edge,xx,.039,.008,.005,.106,.137,'gold')
                edge_box(f'Edge_{edge}_Gold_Leaf_Middle_{section}_{side}',edge,xx,.039,.021,.005,.116,.132,'gold')
                edge_box(f'Edge_{edge}_Gold_Leaf_Tip_{section}_{side}',edge,xx,.039,.011,.005,.132,.143,'gold')

for corner in range(6):
    angle=math.radians(30-60*corner)
    radial=Vector((math.cos(angle),math.sin(angle)))
    center=radial*.946
    tower_top={1:.205,2:.255,3:.264}[level]
    rectangle(f'Corner_{corner}_Ivory_Pedestal',center,.116,.104,0,.045,'cutstone','Architecture',angle)
    rectangle(f'Corner_{corner}_Timber_Pillar',center,.081,.071,.041,tower_top,'timber','Architecture',angle)
    if level>=2:
        rectangle(f'Corner_{corner}_Ivory_Shaft',center,.094,.084,.076,tower_top-.028,'cutstone','Architecture',angle)
        rectangle(f'Corner_{corner}_Gold_Binding',center,.099,.089,tower_top-.030,tower_top-.018,'gold','Architecture',angle)
    rectangle(f'Corner_{corner}_Ivory_Capital',center,.114,.102,tower_top,tower_top+.019,'cutstone','Architecture',angle)
    layers={1:1,2:2,3:4}[level]; step=.015 if level==1 else .016
    for layer in range(layers):
        width=.124-layer*(.020 if level==3 else .027)
        depth=.112-layer*(.018 if level==3 else .024)
        rectangle(f'Corner_{corner}_Emerald_Roof_{layer}',center,width,depth,tower_top+.017+layer*step,tower_top+.017+(layer+1)*step,'roof','Architecture',angle)
    top=tower_top+.017+layers*step
    if level>=2:
        rectangle(f'Corner_{corner}_Roof_Ridge',center,.045,.039,top,top+.013,'roof_dark','Architecture',angle)
        top+=.013
        if level==2:
            rectangle(f'Corner_{corner}_Leaf_Bud',center,.014,.014,top,top+.016,'gold','Architecture',angle)
        else:
            rectangle(f'Corner_{corner}_Leaf_Stem',center,.009,.013,top,top+.016,'gold','Architecture',angle)
            rectangle(f'Corner_{corner}_Leaf_Blade',center,.025,.017,top+.009,top+.025,'gold','Architecture',angle)
            rectangle(f'Corner_{corner}_Leaf_Tip',center,.013,.011,top+.025,top+.036,'gold','Architecture',angle)

# Blocky pointed portal: progressively narrower ivory header courses.
door_top={1:.164,2:.192,3:.207}[level]
tiers={1:2,2:3,3:3}[level]; tier_height=.024 if level<3 else .028
for side in (-1,1):
    edge_box(f'Gate_Ivory_Jamb_{side}',1,side*.111,0,.032,.070,0,door_top+.047,'cutstone')
    edge_box(f'Gate_Timber_Leaf_{side}',1,side*.046,-.005,.088,.022,.009,door_top,'door')
    for z in (.054,.129):
        edge_box(f'Gate_Wood_Brace_{side}_{z}',1,side*.046,.010,.085,.008,z,z+.011,'timber')
    edge_box(f'Gate_Leaf_Handle_{side}',1,side*.017,.016,.012,.008,.088,.107,'gold')
    edge_box(f'Gate_Branch_Post_{side}',1,side*.151,.025,.022,.015,.013,door_top-.008,'timber')
    edge_box(f'Gate_Branch_Arm_{side}',1,side*.141,.025,.044,.015,door_top-.035,door_top-.020,'timber')
for tier in range(tiers):
    edge_box(f'Gate_Point_Header_{tier}',1,0,0,.246-tier*.058,.071,
        door_top+tier*tier_height,door_top+(tier+1)*tier_height,'cutstone')
top=door_top+tiers*tier_height
if level>=2:
    for layer in range(2 if level==2 else 3):
        edge_box(f'Gate_Emerald_Canopy_{layer}',1,0,0,.209-layer*.053,.071-layer*.015,
            top+layer*.014,top+(layer+1)*.014,'roof')
    top+=.014*(2 if level==2 else 3)
    edge_box('Gate_Owner_Faction',1,0,.038,.053,.004,door_top+.012,door_top+.041,'faction','Faction')
    edge_box('Gate_Gold_Leaf_Stem',1,0,.040,.007,.005,door_top+.014,door_top+.045,'gold')
    edge_box('Gate_Gold_Leaf_Blade',1,0,.040,.023,.005,door_top+.023,door_top+.037,'gold')
    edge_box('Gate_Gold_Leaf_Tip',1,0,.040,.013,.005,door_top+.037,door_top+.049,'gold')
if level==3:
    edge_box('Gate_Emerald_Crest_Socket',1,0,0,.043,.042,top,top+.010,'roof_dark')
    edge_box('Gate_Leaf_Finial_Stem',1,0,0,.009,.012,top+.010,top+.020,'gold')
    edge_box('Gate_Leaf_Finial_Blade',1,0,0,.029,.017,top+.016,top+.030,'gold')
    edge_box('Gate_Leaf_Finial_Tip',1,0,0,.014,.011,top+.030,top+.043,'gold')


DESIGN_BY_LEVEL={1:'Moss stone perimeter, ivory coping, short timber corner posts and a simple stepped pointed gate.',
 2:'Ivory stepped merlons, timber branch braces, emerald corner caps, leaf buds and an emerald portal.',
 3:'Dressed ivory stone, emerald inlays, embossed gold leaves, four-tier short emerald turrets and leaf finials.'}
