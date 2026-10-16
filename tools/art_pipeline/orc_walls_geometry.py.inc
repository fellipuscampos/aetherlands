"""Low orc palisade -> reinforced stone/timber -> tusked clan fortress.

All solid parts use the proven hex-grid planes, including stepped square tusks.
"""
body_top={1:.183,2:.210,3:.227}[level]
coping_top=body_top+(.017 if level<3 else .022)
for edge in range(6):
    spans=[(-.449,.449)] if edge!=1 else [(-.449,-.120),(.120,.449)]
    for section,(left,right) in enumerate(spans):
        x=(left+right)/2; width=right-left
        edge_box(f'Edge_{edge}_Basalt_Foot_{section}',edge,x,0,width,.092,0,.032,'foundation')
        if level>=2:
            stone_top=.111 if level==2 else body_top
            for row in range(2 if level==2 else 3):
                rows=2 if level==2 else 3
                for column in range(4):
                    a=left+width*column/4; b=left+width*(column+1)/4
                    edge_box(f'Edge_{edge}_Basalt_Block_{section}_{row}_{column}',edge,(a+b)/2,0,b-a,.071,
                             .027+(stone_top-.027)*row/rows,.027+(stone_top-.027)*(row+1)/rows,'stone')
        if level<3:
            # Closed touching planks keep the ring readable from both sides.
            count=max(3,round(width/.065))
            for plank in range(count):
                a=left+width*plank/count; b=left+width*(plank+1)/count
                extra=.006 if (plank+edge)%3==0 else 0
                edge_box(f'Edge_{edge}_Palisade_Plank_{section}_{plank}',edge,(a+b)/2,0,b-a,.071,
                         .027 if level==1 else .108,body_top+extra,'door')
        edge_box(f'Edge_{edge}_Top_Binding_{section}',edge,x,0,width,.081,body_top,coping_top,'timber' if level==1 else 'iron')
        if level==1:
            edge_box(f'Edge_{edge}_Wood_Crossbar_{section}',edge,x,.031,width,.012,.073,.088,'timber')
        else:
            for z in (.063,.164):
                edge_box(f'Edge_{edge}_Iron_Strap_{section}_{z}',edge,x,.033,width,.012,z,z+.013,'iron')
                for sign in (-1,1):
                    xx=x+sign*min(.23,width*.29)
                    edge_box(f'Edge_{edge}_Rivet_{section}_{z}_{sign}',edge,xx,.040,.015,.004,z+.002,z+.011,'iron_light')
            count=4 if level==2 else 5
            if edge==1: count=2
            for merlon in range(count):
                xx=left+width*(merlon+.5)/count
                edge_box(f'Edge_{edge}_Jagged_Post_{section}_{merlon}',edge,xx,0,.041,.069,coping_top,coping_top+.026,'timber' if level==2 else 'stone')
                edge_box(f'Edge_{edge}_Jagged_Iron_Cap_{section}_{merlon}',edge,xx,0,.028,.055,coping_top+.025,coping_top+.038,'iron')
        if level==3:
            for sign in (-1,1):
                xx=x+sign*min(.20,width*.32)
                edge_box(f'Edge_{edge}_Heavy_Timber_Prop_{section}_{sign}',edge,xx,.030,.031,.019,.026,body_top,'timber')
                for z in (.063,.164):
                    edge_box(f'Edge_{edge}_Prop_Iron_Collar_{section}_{sign}_{z}',edge,xx,.034,.047,.017,z-.004,z+.016,'iron')

def stepped_tusk(part,center,z0,height,angle,width=.025,depth=.022):
    radial=Vector((math.cos(angle),math.sin(angle)))
    # A squared ivory horn, stepping gently toward the center as it narrows.
    for tier in range(3):
        rectangle(f'{part}_{tier}',Vector(center)-radial*(tier*.003),width*(1-tier*.29),depth*(1-tier*.26),
                  z0+height*tier/3,z0+height*(tier+1)/3,'bone','Architecture',angle)

for corner in range(6):
    angle=math.radians(30-60*corner)
    radial=Vector((math.cos(angle),math.sin(angle)))
    tangent=Vector((-math.sin(angle),math.cos(angle)))
    center=radial*.946
    width,depth=(.112,.102) if level==1 else (.120,.110)
    tower_top={1:.214,2:.237,3:.260}[level]
    rectangle(f'Corner_{corner}_Basalt_Platform',center,width,depth,0,.041,'foundation','Architecture',angle)
    rectangle(f'Corner_{corner}_Heavy_Post',center,width-.015,depth-.015,.038,tower_top,
              'timber' if level<3 else 'stone','Architecture',angle)
    for z in (.072,tower_top-.042):
        rectangle(f'Corner_{corner}_Iron_Collar_{z}',center,width-.004,depth-.004,z,z+.020,'iron','Architecture',angle)
    rectangle(f'Corner_{corner}_Iron_Parapet',center,width,depth,tower_top,tower_top+.022,'iron','Architecture',angle)
    top=tower_top+.022
    if level==2:
        for sign in (-1,1):
            stepped_tusk(f'Corner_{corner}_Tusk_{sign}',center+tangent*(sign*.030),top,.058,angle,.022,.022)
    if level==3:
        # A low rust-red gable, with a long dark ridge like the orc chief hall.
        for tier in range(3):
            rectangle(f'Corner_{corner}_Hide_Gable_{tier}',center,.124-tier*.040,.112-tier*.007,
                      top+tier*.020,top+(tier+1)*.020,'roof','Architecture',angle)
        top+=.060
        rectangle(f'Corner_{corner}_Iron_Ridge',center,.024,.099,top,top+.014,'iron','Architecture',angle)
        for sign in (-1,1):
            stepped_tusk(f'Corner_{corner}_Ridge_Tusk_{sign}',center+tangent*(sign*.035),top+.014,.034,angle,.019,.018)

door_top={1:.161,2:.188,3:.204}[level]
gate_cap={1:.238,2:.272,3:.301}[level]
for sign in (-1,1):
    edge_box(f'Gate_Heavy_Timber_Jamb_{sign}',1,sign*.112,0,.042,.071,0,gate_cap-.020,'timber')
    edge_box(f'Gate_Door_Leaf_{sign}',1,sign*.046,-.005,.088,.023,.009,door_top,'door')
    for z in (.054,.130):
        edge_box(f'Gate_Door_Iron_Band_{sign}_{z}',1,sign*.046,.011,.086,.009,z,z+.014,'iron')
        edge_box(f'Gate_Door_Rivet_{sign}_{z}',1,sign*.076,.017,.012,.004,z+.003,z+.011,'iron_light')
    edge_box(f'Gate_Iron_Handle_{sign}',1,sign*.016,.017,.013,.008,.084,.109,'iron_light')
edge_box('Gate_Heavy_Lintel',1,0,0,.266,.073,door_top,gate_cap-.020,'timber')
edge_box('Gate_Iron_Header',1,0,0,.275,.076,gate_cap-.020,gate_cap,'iron')
if level>=2:
    for tier in range(3):
        edge_box(f'Gate_Hide_Gable_{tier}',1,0,0,.267-tier*.065,.072-tier*.004,
                 gate_cap+tier*.017,gate_cap+(tier+1)*.017,'roof')
    edge_box('Gate_Iron_Ridge',1,0,0,.080,.066,gate_cap+.051,gate_cap+.065,'iron')
    edge_box('Gate_Clan_Faction',1,0,.038,.072,.004,door_top+.009,door_top+.045,'faction','Faction')
    edge_box('Gate_Clan_Jaw',1,0,.040,.032,.005,door_top+.017,door_top+.026,'bone')
    edge_box('Gate_Clan_Brow',1,0,.040,.045,.005,door_top+.034,door_top+.042,'iron_light')
    for sign in (-1,1):
        edge_box(f'Gate_Clan_Fang_{sign}',1,sign*.019,.040,.009,.005,door_top+.018,door_top+.037,'bone')
        edge_box(f'Gate_Tusk_Iron_Socket_{sign}',1,sign*.153,.019,.039,.039,.069,.133,'iron')
        # Taller ivory tusks flank the portal without exceeding the ring's width.
        for tier in range(3):
            edge_box(f'Gate_Standing_Tusk_{sign}_{tier}',1,sign*(.153-tier*.003),.019,
                     .030-tier*.009,.030-tier*.006,.127+tier*.039,.127+(tier+1)*.039,'bone')

DESIGN_BY_LEVEL={
    1:'Closed timber palisade on basalt, dark crossbars, six iron-bound square posts and a simple plank gate.',
    2:'Basalt and timber wall, black iron straps and rivets, jagged parapet, ivory corner tusks and rust-red gate gable.',
    3:'Heavy basalt wall with timber props and iron collars, short rust-red gabled corner turrets, ivory ridge tusks and tusked clan portal.'}
