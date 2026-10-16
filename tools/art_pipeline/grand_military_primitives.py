"""Small architectural and mechanical components; layouts remain in race recipes."""
def support(name,x,y,z0,z1,width=.06,reg=POST,group='02_HALL'):
    box(name+'_Foot',(x,y,z0+.027),(width+.044,width+.044,.054),'cutstone',group)
    box(name+'_Shaft',(x,y,(z0+z1)/2),(width,width,z1-z0),reg,group)
    box(name+'_Capital',(x,y,z1-.022),(width+.033,width+.033,.044),TRIM,group)
    if CIV in ('orc','dwarf'):
        for z in (z0+.10,z1-.10):
            box(name+'_Belt_'+str(z),(x,y,z),(width+.016,width+.016,.031),TRIM,'08_DETAILS')
    elif CIV=='elf':
        beam(name+'_Branch',(x,y,z1-.13),(x+.075,y,z1-.012),.026,'timber',group)

def pavilion(name,x,y,w,d,z0,h,steps=5):
    box(name+'_Floor',(x,y,z0+.025),(w,d,.05),'cutstone','02_HALL')
    for sx in (-1,1):
        for sy in (-1,1):
            support(name+'_%s_%s'%(sx,sy),x+sx*(w/2-.025),y+sy*(d/2-.025),z0+.04,z0+h,.06)
    box(name+'_Front_Lintel',(x,y-d/2+.01,z0+h),(w+.04,.069,.052),POST,'02_HALL')
    box(name+'_Rear_Lintel',(x,y+d/2-.01,z0+h),(w+.04,.069,.052),POST,'02_HALL')
    box(name+'_Backwall',(x,y+d/2-.01,z0+h/2), (w,.04,h-.04),BODY,'02_HALL')
    return roof(name,x,y,w+.10,d+.08,z0+h+.026,steps,False)

def turret(name,x,y,w,h,z0=.077,reg='stone',merlons=True):
    box(name+'_Foot',(x,y,z0+.05),(w+.045,w+.045,.10),'cutstone','04_FOCUS')
    box(name+'_Core',(x,y,z0+h/2),(w,w,h),reg,'04_FOCUS')
    box(name+'_Gallery',(x,y,z0+h),(w+.054,w+.054,.065),'cutstone','04_FOCUS')
    box(name+'_Slit',(x,y-w/2-.005,z0+h*.58),(.045,.015,h*.25),'shadow','08_DETAILS')
    if merlons:
        for sx in (-1,1):
            for sy in (-1,1):
                box(name+'_Merlon_%s_%s'%(sx,sy),(x+sx*w*.36,y+sy*w*.36,z0+h+.082),(.072,.072,.116),'cutstone','04_FOCUS')
                if CIV=='dwarf':
                    box(name+'_Copper_Cap_%s_%s'%(sx,sy),(x+sx*w*.36,y+sy*w*.36,z0+h+.145),(.079,.079,.024),'bronze','04_FOCUS')
    return z0+h+.147

def hexhall(name,x,y,r,z0,h,steps=6):
    polygon_prism(name+'_Foot',hexagon(r+.025,(x,y)),z0,z0+.065,'cutstone','02_HALL')
    polygon_prism(name+'_Walls',hexagon(r,(x,y)),z0+.065,z0+h,BODY,'02_HALL')
    for i,(px,py) in enumerate(hexagon(r,(x,y))):
        support(name+'_Pier_'+str(i),px,py,z0+.062,z0+h,.054)
    for i in range(steps):
        polygon_prism(name+'_Roof_'+str(i),hexagon(r+.07-i*(r/steps),(x,y)),z0+h+i*PITCH,z0+h+(i+1)*PITCH,'roof','03_ROOFS')
    return z0+h+steps*PITCH

def stair(name,x,y,width,count,rise=.045,depth=.064,z0=.077,direction=1):
    for i in range(count):
        height=(i+1)*rise
        box(name+'_'+str(i),(x,y+direction*i*depth,z0+height/2),(width,depth+.018,height),'cutstone','05_COURTYARD')

def rail(name,a,b,z0,h=.15,reg=POST):
    for j,(x,y) in enumerate((a,b)):
        support(name+'_Post_'+str(j),x,y,z0,z0+h,.035,reg,'05_COURTYARD')
    for z in (z0+h*.45,z0+h-.02):
        beam(name+'_Bar_'+str(z),(a[0],a[1],z),(b[0],b[1],z),.025,reg,'05_COURTYARD')

def tree(name,x,y,h=1.3,r=.25,z0=.077,canopy=True):
    box(name+'_Root',(x,y,z0+.03),(r*.66,r*.72,.06),'timber','04_FOCUS')
    box(name+'_Trunk',(x,y,z0+h*.43),(r*.35,r*.37,h*.86),'timber','04_FOCUS')
    for i,(dx,dy) in enumerate(((-r*.60,0),(r*.65,.07),(0,-r*.6))):
        beam(name+'_Root_Branch_'+str(i),(x,y,z0+.10),(x+dx,y+dy,z0+.025),.051,'timber','04_FOCUS')
    for i,(dx,dy) in enumerate(((-r*.7,0),(r*.7,.035),(0,r*.6))):
        beam(name+'_Branch_'+str(i),(x,y,z0+h*.55),(x+dx,y+dy,z0+h*.85),.05,'timber','04_FOCUS')
        if canopy:
            box(name+'_Crown_'+str(i),(x+dx,y+dy,z0+h*.86),(r*1.07,r*1.00,h*.20),'foliage','04_FOCUS')
    if canopy:
        box(name+'_Crown_Top',(x,y,z0+h*.99),(r*1.14,r*.98,h*.16),'foliage_light','04_FOCUS')

def standard(x,y,top=1.28):
    support('Standard',x,y,.077,top,.023,'timber','07_FACTION')
    box('Standard_Crossbar',(x-.081,y,top-.025),(.22,.032,.027),TRIM,'07_FACTION')
    profile=[(-.091,0),(.091,0),(.091,-.16),(-.091,-.16)]
    if CIV=='orc':
        profile=[(-.091,0),(.091,0),(.091,-.16),(.025,-.12),(0,-.16),(-.091,-.14)]
    vertical_prism('Standard_Cloth',profile,(x-.078,y,top-.025),.012,'faction','07_FACTION')
    for sx in (-1,1):
        box('Standard_Tie_'+str(sx),(x-.078+sx*.051,y,top-.032),(.013,.042,.036),TRIM,'07_FACTION')
    box('Standard_Badge',(x-.078,y-.011,top-.095),(.030,.015,.056),'iron_light','07_FACTION')

def weapon_relief(name,x,y,z,length,angle,kind):
    up=Vector((math.sin(angle),0,math.cos(angle)))
    across=Vector((math.cos(angle),0,-math.sin(angle)))
    center=Vector((x,y,z))
    beam(name+'_Haft',center-up*length*.46,center+up*length*.38,.023,'timber','07_FACTION')
    beam(name+'_Grip',center-up*length*.45,center-up*length*.22,.031,TRIM,'07_FACTION')
    head=center+up*length*.25
    profile=[(-.20,-.13),(.20,-.13),(.20,.13),(-.20,.13)] if kind=='hammer' else [(-.04,-.08),(.10,-.08),(.10,-.18),(.27,-.18),(.27,.17),(.10,.17),(.10,.075),(-.04,.075)]
    points=[(length*(a*math.cos(angle)+b*math.sin(angle)),length*(-a*math.sin(angle)+b*math.cos(angle))) for a,b in profile]
    vertical_prism(name+'_Head',points,tuple(head),.026,'iron_light' if kind=='axe' else 'bronze','07_FACTION')
    box(name+'_Hub',tuple(head),(.043,.038,.043),'iron','07_FACTION')

def ranged_relief(name,x,front,z,scale):
    y=front-.044
    if CIV=='dwarf':
        box(name+'_Stock',(x,y,z),(.026,.028,.23*scale),'door','07_FACTION')
        for sx in (-1,1):
            beam(name+'_Crossbow_Limb_'+str(sx),(x,y,z+.035*scale),(x+sx*.12*scale,y,z+.005*scale),.018,'iron_light','07_FACTION')
            beam(name+'_Crossbow_String_'+str(sx),(x+sx*.12*scale,y-.006,z+.005*scale),(x,y-.006,z-.035*scale),.005,'bone','07_FACTION')
        box(name+'_Bolt',(x,y-.019,z+.025*scale),(.009,.014,.19*scale),'bone','07_FACTION')
    else:
        points=[(0,-.11),(.065,-.064),(.093,0),(.065,.064),(0,.11)]
        for i,(a,b) in enumerate(zip(points,points[1:])):
            beam(name+'_Bow_Limb_'+str(i),(x+a[0]*scale,y,z+a[1]*scale),(x+b[0]*scale,y,z+b[1]*scale),.017,'door' if CIV=='elf' else 'bone','07_FACTION')
        beam(name+'_Bow_String',(x,y,z-.11*scale),(x,y,z+.11*scale),.005,'bone','07_FACTION')
        beam(name+'_Arrow',(x-.10*scale,y-.007,z),(x+.125*scale,y-.007,z),.012,'iron_light','07_FACTION')
        vertical_prism(name+'_Arrowhead',[(0,-.022*scale),(.044*scale,0),(0,.022*scale)],(x+.105*scale,y-.007,z),.017,'iron_light','07_FACTION')

def crest(name,x,front,z,kind=ROLE,scale=1):
    w=.29*scale; h=.30*scale
    box(name+'_Backing',(x,front,z),(w+.044,.042,h+.026),POST,'07_FACTION')
    box(name+'_Cloth',(x,front-.027,z),(w,.020,h),'faction','07_FACTION')
    y=front-.047
    if kind=='guardian':
        shape=[(-.5,.45),(.5,.45),(.5,-.18),(0,-.53),(-.5,-.18)]
        if CIV=='dwarf':
            shape=[(-.33,.5),(.33,.5),(.5,.33),(.5,-.30),(.3,-.5),(-.3,-.5),(-.5,-.3),(-.5,.33)]
        vertical_prism(name+'_Shield_Rim',[(a*w*.8,b*h*.8) for a,b in shape],(x,y,z),.022,TRIM,'07_FACTION')
        vertical_prism(name+'_Shield',[(a*w*.65,b*h*.65) for a,b in shape],(x,y-.016,z),.015,'door','07_FACTION')
        box(name+'_Shield_Boss',(x,y-.033,z),(.047*scale,.025,.05*scale),'iron_light','07_FACTION')
        if CIV=='elf':
            leaf(name+'_Leaf',(x,y-.043,z),.064*scale,.106*scale,.014,'gold','07_FACTION')
    elif kind in ('warrior','rogue'):
        length=.30*scale if kind=='warrior' else .21*scale
        for sx in (-1,1):
            if kind=='warrior' and CIV in ('orc','dwarf'):
                weapon_relief(name+'_Clan_Weapon_'+str(sx),x,front-.040,z,length,sx*.66,
                              'axe' if CIV=='orc' or sx==-1 else 'hammer')
            else:
                sword(name+'_Blade_'+str(sx),(x,front-.040,z),length,sx*.66,'07_FACTION')
        if kind=='rogue':
            vertical_prism(name+'_Hood',[(-w*.22,-h*.02),(w*.22,-h*.02),(w*.19,h*.17),(0,h*.38),(-w*.19,h*.17)],(x,front-.043,z),.018,'iron_light','07_FACTION')
            box(name+'_Eyes',(x,front-.053,z+h*.08),(w*.21,.018,h*.028),'shadow','07_FACTION')
    elif kind=='ranger':
        ranged_relief(name+'_Ranged',x,front,z,scale)
    elif kind=='cavalry':
        profile=[(-.11,.12),(-.065,.12),(-.065,-.03),(-.03,-.068),(.03,-.068),(.065,-.03),(.065,.12),(.11,.12),(.11,-.05),(.06,-.105),(-.06,-.105),(-.11,-.05)]
        vertical_prism(name+'_Shoe',[(a*scale,b*scale) for a,b in profile],(x,y,z),.024,'iron_light','07_FACTION')
    else:
        ring(name+'_Cog',(x,y,z),.079*scale,.030*scale,'iron_light','XZ','07_FACTION',8)
        for i in range(8):
            a=i*math.pi/4
            beam(name+'_Tooth_'+str(i),(x+.070*scale*math.cos(a),y,z+.070*scale*math.sin(a)),(x+.11*scale*math.cos(a),y,z+.11*scale*math.sin(a)),.033*scale,'iron_light','07_FACTION')
        box(name+'_Cog_Hub',(x,y,z),(.043,.028,.046),TRIM,'07_FACTION')

def dummy(name,x,y,shield=False):
    support(name,x,y,.077,.43,.035,'timber','06_TRAINING')
    box(name+'_Straw',(x,y,.37),(.10,.082,.133),'straw','06_TRAINING')
    box(name+'_Head',(x,y,.463),(.071,.071,.063),'straw','06_TRAINING')
    box(name+'_Arms',(x,y,.359),(.173,.027,.026),'timber','06_TRAINING')
    if shield:
        vertical_prism(name+'_Shield',[(-.068,.07),(.068,.07),(.068,-.04),(0,-.10),(-.068,-.04)],(x,y-.051,.345),.025,'faction','06_TRAINING')
    else:
        box(name+'_Hit',(x,y-.046,.376),(.045,.014,.037),'iron','06_TRAINING')

def target(name,x,y,z=.37,r=.125):
    support(name+'_Stand',x,y,.077,z+.02,.039,'timber','06_TRAINING')
    for i,(ratio,reg) in enumerate(((1,'timber'),(.84,'bone'),(.56,'faction'),(.25,'bone'))):
        vertical_prism(name+'_Ring_'+str(i),[(r*ratio*math.cos(j*math.pi/4),r*ratio*math.sin(j*math.pi/4)) for j in range(8)],(x,y-.015-i*.018,z),.023,reg,'06_TRAINING')
    beam(name+'_Arrow',(x+.036,y-.04,z-.013),(x+.052,y-.22,z+.008),.009,'door','06_TRAINING')

def bench(name,x,y,z=.077):
    for sx in (-1,1):
        support(name+'_Leg_'+str(sx),x+sx*.096,y,z,z+.19,.037,'timber','06_TRAINING')
    box(name+'_Top',(x,y,z+.188),(.27,.12,.032),'door','06_TRAINING')
    box(name+'_Tools',(x,y,z+.214),(.135,.035,.018),'iron_light','06_TRAINING')

def horse(name,x,y,angle=0,scale=.82,z0=.077):
    sources=[o for o in reference_scene.objects if o.type=='MESH' and o.get('part','').startswith('Horse_In_Stall_')]
    assert sources
    points=[v.co for o in sources for v in o.data.vertices]
    mid=Vector(((min(v.x for v in points)+max(v.x for v in points))/2,
                (min(v.y for v in points)+max(v.y for v in points))/2,min(v.z for v in points)))
    atlas=str(ref_out/(ref_folder+'_albedo.png'))
    for src in sources:
        vertices=[]
        for v in src.data.vertices:
            co=(v.co-mid)*scale
            vertices.append((x+co.x*math.cos(angle)-co.y*math.sin(angle),y+co.x*math.sin(angle)+co.y*math.cos(angle),z0+co.z))
        obj=mesh(name+'_'+src['part'].removeprefix('Horse_In_Stall_'),vertices,[tuple(p.vertices) for p in src.data.polygons],'horse_source','04_FOCUS')
        obj['source_paint_atlas']=atlas
        obj['source_paint_uvs']=[float(c) for p in src.data.polygons for li in p.loop_indices for c in src.data.uv_layers.active.data[li].uv]
        obj['prop_source']=ref_folder+' approved static horse geometry and coat, no rider'

def wheel(name,x,y,z,r=.095):
    # Axle runs along X; octagonal rim and two connected spokes.
    ring(name+'_Rim',(x,y,z),r,.034,'iron','YZ','04_FOCUS',8)
    box(name+'_Hub',(x,y,z),(.063,.049,.049),TRIM,'04_FOCUS')
    box(name+'_Spoke_Y',(x,y,z),(.039,r*2,.024),'door','04_FOCUS')
    box(name+'_Spoke_Z',(x,y,z),(.039,.024,r*2),'door','04_FOCUS')

def chassis(name,x,y,w=.38,d=.47):
    for dy in (-d*.36,d*.36):
        box(name+'_Axle_'+str(dy),(x,y+dy,.18),(w+.11,.035,.035),'iron','04_FOCUS')
        for sx in (-1,1):
            wheel(name+'_Wheel_%s_%s'%(sx,dy),x+sx*(w/2+.03),y+dy,.18,.103)
    for sx in (-1,1):
        box(name+'_Rail_'+str(sx),(x+sx*w*.37,y,.228),(.057,d,.081),'timber','04_FOCUS')
    box(name+'_Deck',(x,y,.262),(w,d,.054),'door','04_FOCUS')

def ballista(name,x,y,wide=.43):
    chassis(name,x,y,wide*.66,.40)
    box(name+'_Pedestal',(x,y,.371),(.105,.137,.22),'timber','04_FOCUS')
    box(name+'_Rail',(x,y-.035,.502),(.067,.47,.067),'timber','04_FOCUS')
    box(name+'_Bolt',(x,y-.090,.541),(.018,.43,.016),'bone','04_FOCUS')
    box(name+'_Bolt_Point',(x,y-.303,.541),(.035,.054,.036),'iron_light','04_FOCUS')
    for sx in (-1,1):
        beam(name+'_Bow_'+str(sx),(x,y-.08,.49),(x+sx*wide/2,y+.005,.49),.033,POST,'04_FOCUS')
        beam(name+'_String_'+str(sx),(x+sx*wide/2,y+.005,.49),(x,y+.19,.49),.009,'rope','04_FOCUS')
        box(name+'_Bow_Seat_'+str(sx),(x+sx*.06,y-.08,.479),(.063,.073,.068),TRIM,'04_FOCUS')

def crane(name,x,y,h=1.33,span=.50):
    support(name+'_Mast',x,y,.077,h,.070,POST,'04_FOCUS')
    box(name+'_Boom',(x-span*.30,y,h), (span,.075,.071),POST,'04_FOCUS')
    beam(name+'_Brace',(x,y,h-.27),(x-span*.60,y,h-.025),.046,POST,'04_FOCUS')
    lx=x-span*.72
    box(name+'_Chain',(lx,y,h-.20),(.013,.014,.38),'iron_light','04_FOCUS')
    box(name+'_Load',(lx,y,h-.426),(.17,.09,.075),'iron','04_FOCUS')
    for sx in (-1,1):
        beam(name+'_Sling_'+str(sx),(lx,y,h-.38),(lx+sx*.06,y,h-.406),.012,'rope','04_FOCUS')

def roost(name,x,y,z,w=.30):
    support(name+'_Post',x,y,.077,z,.072,POST,'04_FOCUS')
    polygon_prism(name+'_Deck',hexagon(w*.56,(x,y)),z-.023,z+.023,'timber','04_FOCUS')
    for sx in (-1,1):
        beam(name+'_Bracket_'+str(sx),(x,y,z-.19),(x+sx*w*.32,y,z-.031),.033,POST,'04_FOCUS')
    polygon_prism(name+'_Nest',hexagon(w*.45,(x,y)),z+.023,z+.068,'straw','04_FOCUS')
    box(name+'_Perch',(x,y+.055,z+.115),(w*.72,.033,.034),POST,'04_FOCUS')
    for sx in (-1,1):
        box(name+'_Perch_End_'+str(sx),(x+sx*w*.32,y+.055,z+.071),(.029,.029,.088),POST,'04_FOCUS')
    box(name+'_Egg',(x,y-.021,z+.10),(.074,.059,.065),'bone','04_FOCUS')
