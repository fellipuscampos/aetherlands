"""Shared construction techniques; each civilization has separate building recipes."""

def octagon(x,y,w,d,cut=.14):
    a,b=w/2,d/2
    c=min(w,d)*cut
    return [(x-a+c,y-b),(x+a-c,y-b),(x+a,y-b+c),(x+a,y+b-c),
            (x+a-c,y+b),(x-a+c,y+b),(x-a,y+b-c),(x-a,y-b+c)]

def roof(name,x,y,w,d,z,courses=6,hip=False):
    pitch={'human':.045,'elf':.062,'dwarf':.030,'orc':.042}[CIV]
    for i in range(courses):
        fraction=i/courses
        rw=w*(1-.85*fraction)
        rd=d*(1-.75*fraction) if hip else d
        # Match the straight eaves of the existing civilian/training halls.
        # Hex clipping trims only a real tile boundary, never all four corners.
        outline=[(x-rw/2,y-rd/2),(x+rw/2,y-rd/2),
                 (x+rw/2,y+rd/2),(x-rw/2,y+rd/2)]
        polygon_prism(name+'_Tile_Course_'+str(i),clip_to_hex(outline,.90),z+i*pitch,z+(i+1)*pitch,'roof','03_ROOFS')
    top=z+courses*pitch
    ridge=TRIM if CIV in ('elf','dwarf') else 'roof_dark'
    box(name+'_Ridge',(x,y,top+.014),(w*.13,.13 if hip else d*.95,.028),ridge,'03_ROOFS')
    if CIV=='elf':
        leaf(name+'_Leaf_Finial',(x,y,top+.10),.086,.146,.020,'gold','08_DETAILS')
    elif CIV=='orc':
        for sign in (-1,1):
            tusk(name+'_Tusk_'+str(sign),(x,y+sign*(.04 if hip else d*.36),top+.018),.11,.024,'08_DETAILS')
    return top+.028

def support(name,x,y,z0,z1,width=None,inward=1,foot_height=.064):
    width=width or {'human':.074,'elf':.043,'dwarf':.108,'orc':.092}[CIV]
    box(name+'_Foot',(x,y,z0+foot_height/2),(width+.045,width+.045,foot_height),'cutstone','06_STRUCTURE')
    shaft_top=z1-.010  # Terminate inside the capital, below its top surface.
    box(name+'_Shaft',(x,y,(z0+shaft_top)/2),(width,width,shaft_top-z0),POST,'06_STRUCTURE')
    box(name+'_Capital',(x,y,z1-.020),(width+.037,width+.037,.040),TRIM if CIV!='human' else 'cutstone','06_STRUCTURE')
    if CIV in ('orc','dwarf'):
        for factor in (.23,.76):
            box(name+'_Collar_'+str(factor),(x,y,z0+(z1-z0)*factor),(width+.016,width+.016,.028),TRIM,'08_DETAILS')
    if CIV in ('elf','orc'):
        reach=.105 if CIV=='elf' else .125
        beam(name+'_Diagonal_Brace',(x,y,z1-.16),(x+inward*reach,y,z1-.024),.027 if CIV=='elf' else .035,POST,'06_STRUCTURE')

def hall(name,x,y,w,d,h,open_front=False,hip=False):
    z0=.076
    box(name+'_Plinth',(x,y,z0+.035),(w+.035,d+.030,.070),'cutstone','02_HALL')
    if open_front:
        box(name+'_Rear_Wall',(x,y+d/2-.021,z0+h/2),(w,.042,h),BODY,'02_HALL')
        if CIV in ('human','dwarf'):
            for side in (-1,1):
                box(name+'_Side_Sill_'+str(side),(x+side*(w/2-.018),y,z0+.090),(.042,d,.180),'stone','02_HALL')
    else:
        box(name+'_Body',(x,y,z0+h/2),(w,d,h),BODY,'02_HALL')
        box(name+'_Stone_Base',(x,y,z0+.100),(w+.014,d+.014,.170),'cutstone','02_HALL')
    for sx in (-1,1):
        for sy in (-1,1):
            support(name+'_Pier_%s_%s'%(sx,sy),x+sx*(w/2-.018),y+sy*(d/2-.018),z0+.040,z0+h,inward=-sx)
    for sy in (-1,1):
        box(name+'_Lintel_'+str(sy),(x,y+sy*d/2,z0+h-.010),(w+.036,.065,.060),POST,'06_STRUCTURE')
    return roof(name,x,y,w+.12,d+.11,z0+h+.02,6,hip)

def portal(name,x,front,bottom=.13,width=.20,height=.32,recess_setback=.013):
    box(name+'_Recess',(x,front-recess_setback,bottom+height/2),(width,.025,height),'shadow','08_DETAILS')
    box(name+'_Door',(x,front-.030,bottom+height*.46),(width*.83,.018,height*.86),'door','08_DETAILS')
    for sign in (-1,1):
        box(name+'_Jamb_'+str(sign),(x+sign*(width/2+.017),front-.038,bottom+height/2),(.035,.063,height+.025),POST,'06_STRUCTURE')
        box(name+'_Hinge_'+str(sign),(x+sign*width*.32,front-.048,bottom+height*.43),(.013,.014,height*.60),TRIM,'08_DETAILS')
    box(name+'_Header',(x,front-.041,bottom+height+.018),(width+.082,.067,.047),'cutstone' if CIV in ('human','dwarf') else POST,'06_STRUCTURE')
    box(name+'_Handle',(x+.028,front-.052,bottom+height*.45),(.014,.014,.024),TRIM,'08_DETAILS')
    if CIV=='elf':
        for sign in (-1,1):
            beam(name+'_Point_'+str(sign),(x+sign*width*.55,front-.060,bottom+height+.039),(x,front-.060,bottom+height+.122),.025,'cutstone','06_STRUCTURE')
        leaf(name+'_Leaf',(x,front-.083,bottom+height+.14),.057,.072,.012,'gold','08_DETAILS')
    elif CIV=='dwarf':
        box(name+'_Copper_Keystone',(x,front-.080,bottom+height+.035),(.055,.017,.080),'bronze','08_DETAILS')

def window(name,x,front,z,w=.09,h=.16):
    box(name+'_Glass',(x,front-.012,z),(w,.022,h),'glass','08_DETAILS')
    for sign in (-1,1):
        box(name+'_Jamb_'+str(sign),(x+sign*(w/2+.012),front-.027,z),(.021,.023,h+.034),TRIM,'08_DETAILS')
        box(name+'_Edge_'+str(sign),(x,front-.027,z+sign*(h/2+.012)),(w+.003,.023,.021),POST,'08_DETAILS')
    box(name+'_Mullion',(x,front-.029,z),(.013,.025,h),TRIM,'08_DETAILS')

def barrel(name,x,y,z=.078,r=.065,h=.15):
    polygon_prism(name+'_Wood',hexagon(r,(x,y)),z,z+h,'door','08_DETAILS')
    for height in (.035,h-.035):
        polygon_prism(name+'_Hoop_'+str(height),hexagon(r+.006,(x,y)),z+height-.009,z+height+.009,'iron','08_DETAILS')
    polygon_prism(name+'_Lid',hexagon(r*.87,(x,y)),z+h,z+h+.008,'timber','08_DETAILS')

def crate(name,x,y,z=.078,size=.13):
    box(name,(x,y,z+size/2),(size,size*.85,size),'crate','08_DETAILS')

def table(name,x,y,w=.30,d=.16,z=.30):
    for sx in (-1,1):
        for sy in (-1,1):
            box(name+'_Leg_%s_%s'%(sx,sy),(x+sx*(w/2-.024),y+sy*(d/2-.021),(.078+z)/2),(.027,.027,z-.078),'timber','08_DETAILS')
    box(name+'_Top',(x,y,z),(w,d,.033),'door','08_DETAILS')

def bench(name,x,y,w=.27):
    table(name,x,y,w,.09,.175)
    box(name+'_Back',(x,y+.036,.225),(w-.008,.022,.10),'timber','08_DETAILS')

def book(name,x,y,z=.31,w=.13,d=.11,open_book=False):
    box(name+'_Cover',(x,y,z),(w,d,.017),'book_cover','08_DETAILS')
    box(name+'_Pages',(x,y,z+.020),(w*.88,d*.91,.025),'paper','08_DETAILS')
    if open_book:
        for sign in (-1,1):
            box(name+'_Open_Page_'+str(sign),(x+sign*w*.24,y,z+.039),(w*.45,d*.91,.010),'paper','08_DETAILS',sign*.035)
        box(name+'_Spine',(x,y,z+.041),(.008,d*.94,.014),TRIM,'08_DETAILS')
        for line in range(3):
            for sign in (-1,1):
                box(name+'_Ink_%s_%s'%(line,sign),(x+sign*w*.24,y-d*.22+line*d*.21,z+.046),(w*.32,.005,.007),'ink','08_DETAILS')
    else:
        box(name+'_Top_Cover',(x,y,z+.040),(w,d,.011),'book_cover','08_DETAILS')

def shelf(name,x,y,w=.25,h=.30,z=.10,scrolls=False):
    for sx in (-1,1):
        box(name+'_Side_'+str(sx),(x+sx*w/2,y,z+h/2),(.025,.085,h),POST,'08_DETAILS')
    for row in range(3):
        top=z+row*h/2
        box(name+'_Shelf_'+str(row),(x,y,top),(w+.03,.087,.022),'door','08_DETAILS')
        if row<2:
            for i in range(4):
                bx=x-w*.36+i*w*.24
                box(name+'_Volume_%s_%s'%(row,i),(bx,y-.006,top+.067),(.035,.060,.107),'paper' if scrolls else ('book_cover' if i%2 else 'timber'),'08_DETAILS')
                box(name+'_Volume_Band_%s_%s'%(row,i),(bx,y-.041,top+.065),(.031,.010,.014),TRIM,'08_DETAILS')

def crystal(name,x,y,z,h=.27,r=.07):
    outline=[(x+r*math.cos(i*math.pi/3),y+r*math.sin(i*math.pi/3)) for i in range(6)]
    vertices=[(px,py,z) for px,py in outline]+[(px,py,z+h*.65) for px,py in outline]+[(x,y,z+h)]
    faces=[tuple(range(5,-1,-1))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]+[(6+i,6+(i+1)%6,12) for i in range(6)]
    return mesh(name,vertices,faces,'mana','04_FOCUS')

def basin(name,x,y,r=.20,z=.10,water='mana_water'):
    polygon_prism(name+'_Foot',hexagon(r+.035,(x,y)),.076,z+.02,'cutstone','04_FOCUS')
    polygon_prism(name+'_Vessel',hexagon(r,(x,y)),z,z+.080,'stone','04_FOCUS')
    polygon_prism(name+'_Liquid_Surface',hexagon(r*.80,(x,y)),z+.080,z+.094,water,'04_FOCUS')
    for i,(px,py) in enumerate(hexagon(r,(x,y))):
        box(name+'_Rim_'+str(i),(px,py,z+.083),(.054,.057,.042),TRIM,'04_FOCUS')

def anvil(name,x,y,z=.076):
    box(name+'_Stump',(x,y,z+.065),(.14,.13,.13),'timber','04_FOCUS')
    profile=[(-.12,0),(.10,0),(.10,.025),(.05,.025),(.05,.060),(.12,.060),(.17,.10),(.11,.125),(-.13,.125),(-.13,.081),(-.05,.060),(-.05,.025),(-.12,.025)]
    vertical_prism(name+'_Iron',profile,(x,y,z+.13),.085,'iron_light','04_FOCUS')

def forge(name,x,y,w=.30,d=.23,h=.42):
    box(name+'_Body',(x,y,.076+h/2),(w,d,h),'stone','04_FOCUS')
    box(name+'_Mouth',(x,y-d/2-.009,.215),(w*.59,.023,.17),'shadow','04_FOCUS')
    box(name+'_Hot_Core',(x,y-d/2-.024,.19),(w*.47,.018,.08),'fire','04_FOCUS')
    for i in range(3):
        box(name+'_Coal_'+str(i),(x-w*.15+i*w*.15,y-d/2-.038,.181),(.041,.037,.023),'iron','08_DETAILS')
    for sx in (-1,1):
        box(name+'_Firebrick_'+str(sx),(x+sx*w*.35,y-d/2-.03,.21),(.065,.067,.22),'cutstone','06_STRUCTURE')
    box(name+'_Lintel',(x,y-d/2-.027,.327),(w*.85,.068,.05),'cutstone','06_STRUCTURE')

def crop_bed(name,x,y,w=.32,d=.18,rows=3,golden=False,stone_rim=False):
    box(name+'_Earth',(x,y,.092),(w,d,.03),'soil','05_COURTYARD')
    if stone_rim:
        for sx in (-1,1):
            box(name+'_Side_'+str(sx),(x+sx*(w/2+.014),y,.114),(.030,d-.002,.075),'cutstone','05_COURTYARD')
        for sy in (-1,1):
            box(name+'_End_'+str(sy),(x,y+sy*(d/2+.014),.114),(w+.055,.030,.075),'cutstone','05_COURTYARD')
    for row in range(rows):
        cy=y-d*.33+row*d*.66/max(1,rows-1)
        box(name+'_Furrow_'+str(row),(x,cy,.112),(w*.93,.016,.018),'soil_dark','05_COURTYARD')
        for col in range(5):
            cx=x-w*.37+col*w*.185
            box(name+'_Stem_%s_%s'%(row,col),(cx,cy,.15),(.012,.013,.086),'straw' if golden else 'foliage','05_COURTYARD')
            box(name+'_Crop_%s_%s'%(row,col),(cx,cy,.198),(min(.039,w*.16),.034,.040),'grain' if golden else 'foliage_light','05_COURTYARD')

def tree(name,x,y,h=.95,r=.17):
    box(name+'_Trunk',(x,y,.076+h*.38),(.064,.070,h*.76),'timber','06_STRUCTURE')
    for sx in (-1,1):
        beam(name+'_Root_'+str(sx),(x,y,.18),(x+sx*.12,y-.04,.084),.045,'timber','06_STRUCTURE')
        beam(name+'_Branch_'+str(sx),(x,y,.076+h*.55),(x+sx*r*.60,y,.076+h*.78),.037,'timber','06_STRUCTURE')
    for i,(offset,width,height) in enumerate(((.72,2,.18),(.86,1.65,.15),(1.0,.9,.10))):
        box(name+'_Canopy_'+str(i),(x,y,.076+h*offset),(r*width,r*width*.9,height),'foliage' if i==0 else 'foliage_light','08_DETAILS')

def gear(name,x,y,z,r=.11):
    profile=[]
    for i in range(32):
        angle=i*math.pi/16
        radius=r*(1 if i%4 in (0,1) else .80)
        profile.append((radius*math.cos(angle),radius*math.sin(angle)))
    vertical_prism(name+'_Wheel',profile,(x,y,z),.028,TRIM,'04_FOCUS')
    vertical_prism(name+'_Hub',[(r*.27*math.cos(i*math.pi/4),r*.27*math.sin(i*math.pi/4)) for i in range(8)],(x,y-.026,z),.028,'iron','04_FOCUS')

def trade_goods(name,x,y,z,kind='produce'):
    box(name+'_Tray',(x,y,z),(.23,.12,.024),'crate','08_DETAILS')
    for i in range(5):
        box(name+'_Goods_'+str(i),(x-.08+i*.04,y,z+.030),(.031,.055,.035),'fruit' if kind=='produce' else 'grain','08_DETAILS')

def pennant(x,y,h=.62):
    box('Owner_Pole_Foot',(x,y,.10),(.07,.07,.046),'cutstone','08_DETAILS')
    box('Owner_Pole',(x,y,.078+h/2),(.019,.020,h),'timber','08_DETAILS')
    box('Owner_Pennant',(x-.048,y,.078+h-.08),(.11,.014,.135),'faction','07_FACTION')
    box('Owner_Pole_Cap',(x,y,.078+h+.008),(.029,.030,.021),TRIM,'08_DETAILS')
