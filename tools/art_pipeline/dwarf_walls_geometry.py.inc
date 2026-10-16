"""Low granite wall -> copper-bound masonry -> carved runic fortification."""
body_top={1:.184,2:.206,3:.220}[level]
coping_top=body_top+(.022 if level<3 else .026)
for edge in range(6):
    spans=[(-.449,.449)] if edge!=1 else [(-.449,-.120),(.120,.449)]
    for section,(left,right) in enumerate(spans):
        x=(left+right)/2; width=right-left
        edge_box(f'Edge_{edge}_Granite_Foot_{section}',edge,x,0,width,.092,0,.032,'foundation')
        for course in range(3):
            columns=4 if level<3 else 5
            for column in range(columns):
                a=left+width*column/columns; b=left+width*(column+1)/columns
                edge_box(f'Edge_{edge}_Squared_Block_{section}_{course}_{column}',edge,(a+b)/2,0,b-a,.073,
                         .027+(body_top-.027)*course/3,.027+(body_top-.027)*(course+1)/3,
                         'stone' if level==1 or course!=1 else 'cutstone')
        edge_box(f'Edge_{edge}_Carved_Coping_{section}',edge,x,0,width,.086,body_top,coping_top,'cutstone')
        if level>=2:
            edge_box(f'Edge_{edge}_Copper_Binding_{section}',edge,x,.035,width,.007,.158,.170,'bronze')
            count=5 if level==2 else 6
            if edge==1: count=2
            for merlon in range(count):
                xx=left+width*(merlon+.5)/count
                top=coping_top+(.037 if level==2 else .042)
                edge_box(f'Edge_{edge}_Broad_Battlement_{section}_{merlon}',edge,xx,0,.061,.076,coping_top,top,'cutstone')
                edge_box(f'Edge_{edge}_Battlement_Slate_Cap_{section}_{merlon}',edge,xx,0,.063,.078,top,top+.011,'roof_dark')
        if level==3:
            for sign in (-1,1):
                xx=x+sign*min(.23,width*.32)
                edge_box(f'Edge_{edge}_Dressed_Buttress_{section}_{sign}',edge,xx,.026,.042,.026,.012,body_top,'cutstone')
                edge_box(f'Edge_{edge}_Rune_Panel_{section}_{sign}',edge,xx,.037,.045,.008,.098,.160,'roof_dark')
                edge_box(f'Edge_{edge}_Copper_Rune_Stem_{section}_{sign}',edge,xx,.040,.009,.005,.108,.150,'bronze')
                for z in (.106,.146):
                    edge_box(f'Edge_{edge}_Copper_Rune_Bar_{section}_{sign}_{z}',edge,xx,.040,.027,.005,z,z+.008,'bronze')
            edge_box(f'Edge_{edge}_Lower_Carved_Band_{section}',edge,x,0,width,.085,.056,.074,'cutstone')

for corner in range(6):
    angle=math.radians(30-60*corner)
    radial=Vector((math.cos(angle),math.sin(angle)))
    center=radial*.946
    tower_top={1:.220,2:.249,3:.265}[level]
    rectangle(f'Corner_{corner}_Granite_Shoe',center,.120,.110,0,.042,'foundation','Architecture',angle)
    rectangle(f'Corner_{corner}_Stone_Pier',center,.104,.094,.038,tower_top,'cutstone','Architecture',angle)
    if level==1:
        rectangle(f'Corner_{corner}_Slate_Flat_Cap',center,.122,.112,tower_top,tower_top+.026,'roof_dark','Architecture',angle)
    else:
        rectangle(f'Corner_{corner}_Copper_Collar',center,.114,.104,tower_top-.041,tower_top-.024,'bronze','Architecture',angle)
        rectangle(f'Corner_{corner}_Carved_Capital',center,.120,.110,tower_top,tower_top+.026,'cutstone','Architecture',angle)
        rectangle(f'Corner_{corner}_Rune_Socket',center-radial*.055,.004,.037,.107,.173,'roof_dark','Architecture',angle)
        rectangle(f'Corner_{corner}_Rune_Stem',center-radial*.058,.003,.008,.116,.164,'bronze','Architecture',angle)
        for z in (.112,.160):
            rectangle(f'Corner_{corner}_Rune_Bar_{z}',center-radial*.058,.003,.028,z,z+.008,'bronze','Architecture',angle)
        if level==2:
            tangent=Vector((-math.sin(angle),math.cos(angle)))
            for a,b in ((-1,-1),(-1,1),(1,-1),(1,1)):
                block_center=center+radial*(a*.032)+tangent*(b*.028)
                rectangle(f'Corner_{corner}_Battlement_{a}_{b}',block_center,.036,.036,tower_top+.026,tower_top+.074,'cutstone','Architecture',angle)
                rectangle(f'Corner_{corner}_Battlement_Cap_{a}_{b}',block_center,.038,.038,tower_top+.074,tower_top+.086,'roof_dark','Architecture',angle)
        else:
            top=tower_top+.022
            for tier in range(3):
                rectangle(f'Corner_{corner}_Slate_Roof_{tier}',center,.124-tier*.031,.112-tier*.027,
                          top+tier*.019,top+(tier+1)*.019,'roof','Architecture',angle)
            top+=.057
            rectangle(f'Corner_{corner}_Broad_Ridge',center,.058,.052,top,top+.016,'roof_dark','Architecture',angle)
            top+=.016
            # Low copper roof lanterns echo the dwarven civic hall.
            rectangle(f'Corner_{corner}_Lantern_Stone_Base',center,.046,.044,top,top+.017,'cutstone','Architecture',angle)
            rectangle(f'Corner_{corner}_Lantern_Amber',center+radial*.023,.003,.025,top+.003,top+.014,'glow','Architecture',angle)
            rectangle(f'Corner_{corner}_Lantern_Copper_Cap',center,.063,.057,top+.017,top+.026,'bronze','Architecture',angle)

door_top={1:.165,2:.192,3:.217}[level]
gate_top={1:.238,2:.276,3:.302}[level]
for sign in (-1,1):
    edge_box(f'Gate_Squared_Pilaster_{sign}',1,sign*.111,0,.045,.071,0,gate_top-.018,'cutstone')
    edge_box(f'Gate_Wood_Leaf_{sign}',1,sign*.046,-.004,.088,.023,.009,door_top,'door')
    for z in (.057,.135):
        edge_box(f'Gate_Copper_Door_Band_{sign}_{z}',1,sign*.046,.012,.087,.009,z,z+.012,'bronze')
        edge_box(f'Gate_Door_Rivet_{sign}_{z}',1,sign*.076,.018,.011,.004,z+.002,z+.010,'iron_light')
    edge_box(f'Gate_Copper_Handle_{sign}',1,sign*.016,.017,.013,.008,.087,.109,'bronze')
edge_box('Gate_Carved_Lintel',1,0,0,.267,.073,door_top,gate_top-.019,'cutstone')
edge_box('Gate_Copper_Header',1,0,0,.273,.074,gate_top-.019,gate_top,'bronze' if level>=2 else 'cutstone')
if level==1:
    edge_box('Gate_Slate_Flat_Cap',1,0,0,.277,.074,gate_top,gate_top+.014,'roof_dark')
elif level==2:
    edge_box('Gate_Slate_Vault',1,0,0,.282,.074,gate_top,gate_top+.019,'roof')
    edge_box('Gate_Copper_Ridge',1,0,0,.091,.054,gate_top+.019,gate_top+.030,'bronze')
else:
    for tier in range(3):
        edge_box(f'Gate_Slate_Vault_{tier}',1,0,0,.278-tier*.066,.074-tier*.008,
                 gate_top+tier*.017,gate_top+(tier+1)*.017,'roof')
    edge_box('Gate_Copper_Ridge',1,0,0,.091,.054,gate_top+.051,gate_top+.066,'bronze')
    for sign in (-1,1):
        edge_box(f'Gate_Lantern_Iron_{sign}',1,sign*.132,.036,.026,.012,.228,.272,'iron')
        edge_box(f'Gate_Lantern_Amber_{sign}',1,sign*.132,.040,.016,.004,.235,.263,'glow')
        edge_box(f'Gate_Lantern_Copper_Lid_{sign}',1,sign*.132,.036,.031,.013,.270,.279,'bronze')
if level>=2:
    edge_box('Gate_Owner_Faction',1,0,.038,.064,.004,door_top+.010,door_top+.054,'faction','Faction')
    edge_box('Gate_Hammer_Handle',1,0,.040,.008,.005,door_top+.016,door_top+.045,'bronze')
    edge_box('Gate_Hammer_Head',1,0,.040,.037,.005,door_top+.039,door_top+.050,'bronze')

DESIGN_BY_LEVEL={
    1:'Plain granite masonry, carved coping, short squared stone piers and a copper-bound plank gate.',
    2:'Copper-bound masonry, broad slate-capped battlements, carved piers with copper runes and a hammer civic gate badge.',
    3:'Heavy dressed granite, rune-bearing buttresses, short slate-roofed corner towers with copper lanterns and a carved hammer portal.'}
