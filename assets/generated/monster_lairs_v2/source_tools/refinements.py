"""Art direction corrections, evaluated inside build_lairs.py before BUILDERS is collected."""
ORIGINAL_BUILDERS={r[0]:globals()[r[0]] for r in ROWS}

def discard(b,*names):
    for ob in list(b.parts):
        if ob['piece'] in names:
            b.parts.remove(ob); data=ob.data
            bpy.data.objects.remove(ob,do_unlink=True)
            if data.users==0: bpy.data.meshes.remove(data)

def lift(ob,delta):
    for v in ob.data.vertices: v.co.z+=delta
    ob.data.update()

def ground_at(b,x,y):
    heights=[.0]
    for ob in b.parts:
        if ob['piece'].startswith('Terrain_') or ob['piece']=='Sun_warmed_bedrock':
            hit,location,normal,index=ob.ray_cast(Vector((x,y,10)),Vector((0,0,-1)))
            if hit: heights.append(location.z)
    return max(heights)

def taper_root(b,name,a,c,start_width,end_width):
    a,c=Vector(a),Vector(c); direction=c-a
    rotation=direction.to_track_quat('Z','Y').to_matrix()
    verts=[]
    for center,width in ((a,start_width),(c,end_width)):
        for x,y in ((-.5,-.325),(.5,-.325),(.5,.325),(-.5,.325)):
            verts.append(tuple(center+rotation@Vector((x*width,y*width,0))))
    return b.mesh(name,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'root')

def surface_ribbon(b,name,a,c,normal,width,paint):
    a,c,normal=Vector(a),Vector(c),Vector(normal)
    side=normal.cross((c-a).normalized()).normalized()*width/2
    verts=[tuple(point+normal*offset) for offset in (-.005,-.001) for point in (a-side,c-side,c+side,a+side)]
    return b.mesh(name,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],paint)

def goblin(b):
    ORIGINAL_BUILDERS['goblin'](b)
    discard(b,'Crooked_palisade','Stake_point','Palisade_lashing','Canvas_patch','Guy_rope')
    posts=[]
    for i in range(8):
        x=-1.65+i*.46; y=1.8+math.sin(i)*.1; h=.66+.15*(i%3)
        lean=.045*(i%3-1); end=(x+lean,y,h)
        b.beam('Crooked_palisade',(x,y,.07),end,.22,'wood')
        b.taper('Stake_point',(end[0],y,h-.025),.22,.22,'wood_light',tip=(lean,0))
        posts.append((x,y,h,lean))
    for height in (.32,.60):
        for a,c in zip(posts,posts[1:]):
            points=[(p[0]+p[3]*(height-.07)/(p[2]-.07),p[1]-.105,height) for p in (a,c)]
            b.beam('Attached_fence_rail',points[0],points[1],.075,'root')
    for s in (-1,1):
        b.box('Sewn_canvas_patch',(s*.752,.55,.97),(.016,.48,.44),'cloth_patch',rot=(0,-s*.57,0))
        b.beam('Tensioned_guy_rope',(s*1.01,-.63,.53),(s*1.52,-1.04,.26),.032,'straw')

def skeleton(b):
    ORIGINAL_BUILDERS['skeleton'](b)
    discard(b,'Grave_shadow','Dislodged_tomb_lid')
    b.box('Visible_grave_shadow',(0,-.12,.215),(1.13,1.9,.045),'black')
    b.box('Dislodged_fitting_tomb_lid',(-1.28,.08,1.01),(.16,2.20,1.70),'pale_stone',rot=(0,-.34,.075))
    for ob in b.parts:
        if ob['piece'] in ('Prey_bone','Bone_knuckle'):
            lift(ob,.08)
        elif ob['piece'] in ('Skull','Skull_jaw','Eye_socket','Nose_socket') and max(v.co.z for v in ob.data.vertices)<1:
            lift(ob,.08)

def fallen_log(b,center,length,width,height):
    outline=[(-.3,-.5),(.3,-.5),(.5,-.3),(.5,.3),(.3,.5),(-.3,.5),(-.5,.3),(-.5,-.3)]
    e=Euler((0,.04,.1)).to_matrix(); center=Vector(center)
    verts=[tuple(e@Vector((x,y*width,z*height))+center) for x in (-length/2,length/2) for y,z in outline]
    faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(j,(j+1)%8,(j+1)%8+8,j+8) for j in range(8)]
    return b.mesh('Angular_fallen_trunk',verts,faces,['endgrain','endgrain']+['wood']*8)

def worg(b):
    ORIGINAL_BUILDERS['worg'](b)
    discard(b,'Fallen_trunk','Trunk_cut_end','Broken_branch','Branch_broken_end',
        'Territorial_claw_mark','Skull','Skull_jaw','Eye_socket','Nose_socket','Great_root','Root_tip')
    fallen_log(b,(0,.72,1.12),3.35,.97,.80)
    b.rock('Closed_earthen_den_back',(0,1.02,.67),(1.57,.40,.97),'earth',0,'moss')
    for x,y,w in [(-.80,.77,.7),(.36,.75,.87),(1.02,.84,.39)]:
        b.rock('Trunk_moss_patch',(x,y,1.51),(w,.58,.08),'moss',x*.12,'moss')
    branch=b.beam('Broken_natural_branch',(-.8,.9,1.39),(-1.2,1.32,1.93),.25,'wood')
    branch['_paints'][1]='endgrain'
    b.animal_skull((-.92,-1.17,.18),.38)
    for s in (-1,1):
        a=(s*1.20,.35,1.02); mid=(s*1.32,-.20,.48)
        x,y=s*1.60,-.88+s*.07; end=(x,y,ground_at(b,x,y)+.042)
        xx,yy=s*1.83,-1.13+s*.06; tip=(xx,yy,ground_at(b,xx,yy)+.022)
        taper_root(b,'Curving_bank_root',a,mid,.31,.23)
        taper_root(b,'Curving_bank_root',mid,end,.23,.12)
        taper_root(b,'Tapered_root_tip',end,tip,.12,.055)
    for x in (-.24,0,.24):
        # A flush dark inlay reads as a scratch; a round raised beam reads as a discarded stick.
        outline=[(x,-.32),(x+.064,-.588),(x+.10,-.86),(x+.036,-.592)]
        verts=[(xx,yy,zz) for zz in (.1775,.1815) for xx,yy in outline]
        b.mesh('Flush_claw_groove',verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'black')

def giant_spider(b):
    b.base('earth')
    anchors=[(-1.22,.60,2.25),(1.25,.92,2.03),(.55,-.83,1.56)]
    for i,p in enumerate(anchors):
        x,y,z=p
        trunk=b.beam('Dead_broken_trunk',(x-.10*(i-1),y,.09),(x,y,z),.34,'deadwood')
        trunk['_paints'][1]='endgrain'
        b.beam('Snag_fork',(x,y,z*.73),(x+(-.39 if i%2==0 else .35),y+.15,z+.18),.12,'deadwood')
        for j in range(3):
            a=j*TAU/3+i*.3
            b.beam('Stump_root',(x,y,.20),(x+.47*math.cos(a),y+.47*math.sin(a),.12),.12,'root')
    # A planar orb web, its boundary is attached to the actual unrotated trunk coordinates.
    a=Vector(anchors[0]); c=Vector(anchors[1])
    low_a=Vector((a.x,a.y,.60)); low_c=Vector((c.x,c.y,.48))
    perimeter=[a,(a+c)/2,c,(c+low_c)/2,low_c,(low_c+low_a)/2,low_a,(low_a+a)/2]
    center=sum(perimeter,Vector())/8
    for p in perimeter: b.beam('Anchored_silk_spoke',center,p,.031,'silk')
    for t in (.27,.51,.74,1.0):
        points=[center+(p-center)*t for p in perimeter]
        for p,q in zip(points,points[1:]+points[:1]): b.beam('Orb_web_thread',p,q,.023,'silk')
    # Third snag now participates in the nest rather than standing disconnected in front.
    third=Vector(anchors[2]); lower=Vector((-.72,-.24,.30))
    for p,q in [(a,third),(c,third),(third,lower)]: b.beam('Draped_anchor_strand',p,q,.032,'silk')
    for t in (.40,.72):
        p=a.lerp(third,t); q=c.lerp(third,t)
        b.beam('Draped_cross_strand',p,q,.024,'silk')
    for x,y,z,s in [(-.55,.25,.19,.63),(.52,.23,.19,.5),(.9,1.1,.18,.35)]:
        b.egg((x,y,ground_at(b,x,y)-s*.02+.002),s,'silk')
    hang=(.73,.86,.78); size=.48
    b.egg(hang,size,'silk')
    attachment=a.lerp(c,(hang[0]-a.x)/(c.x-a.x))
    b.beam('Cocoon_suspension',(hang[0],hang[1],hang[2]+size*.91),attachment,.028,'silk')
    for i in range(5):
        x=-.48+(i%3)*.23; y=-.72+(i//3)*.24
        b.egg((x,y,ground_at(b,x,y)-.003),.25,'spider_egg')
    b.bone((-1.12,-.95,.19),.48,.75)

def troll(b):
    ORIGINAL_BUILDERS['troll'](b)
    discard(b,'Great_capstone','Roof_moss','Upper_pillar','Cave_side','Sleeping_bed',
        'Skull','Skull_jaw','Eye_socket','Nose_socket','Horn_root','Horn_tip')
    b.rock('Left_cave_mass',(-1.16,.48,.68),(.95,1.86,1.33),'slate',-.08,'stone')
    b.rock('Right_cave_mass',(1.18,.55,.59),(1.13,1.89,1.12),'slate',.12,'stone')
    b.rock('Left_upper_rock',(-1.05,.64,1.47),(.80,1.24,.52),'stone',.08)
    b.rock('Right_upper_rock',(1.03,.62,1.37),(.89,1.43,.54),'stone',-.07)
    b.rock('Heavy_broken_roof',(-.08,.70,1.90),(3.20,1.87,.54),'stone',-.06,'stone')
    b.rock('Closed_cave_back_mass',(0,1.29,1.05),(1.86,.54,1.62),'slate',0,'stone')
    b.rock('Broken_roof_shoulder',(.98,.91,2.14),(.91,.90,.31),'slate',.13,'stone')
    for x,y,w,d,z in [(-.8,.78,.78,.68,2.19),(.05,1.08,.63,.43,2.19),(1.02,.95,.56,.47,2.32)]:
        b.rock('Irregular_roof_moss',(x,y,z),(w,d,.07),'moss',x*.13,'moss')
    b.rock('Rough_sleeping_bedding',(0,.27,.225),(1.40,1.13,.085),'straw',.03)
    b.animal_skull((-.87,-1.10,.18),.47,True)

def wyvern(b):
    ORIGINAL_BUILDERS['wyvern'](b)
    discard(b,'Windworn_pinnacle','Faceted_egg','Skull','Skull_jaw','Eye_socket','Nose_socket','Scorched_ledge')
    b.rock('Tall_broken_spire_base',(-1.12,1.03,1.35),(.69,.72,1.95),'slate',-.17,'stone')
    b.rock('Tall_broken_spire_tip',(-1.18,1.06,2.39),(.42,.52,.42),'stone',.04,'stone')
    b.rock('Low_broken_spire',(1.08,1.14,1.40),(.70,.66,1.45),'slate',.17,'stone')
    b.egg((-.29,.10,1.64),.53,'wyvern_egg'); b.egg((.32,.38,1.64),.47,'wyvern_egg')
    b.animal_skull((.98,-.42,1.51),.34)
    for x,y,s in [(-.65,-.78,.2),(.04,-.90,.13),(.62,-.77,.17)]:
        b.rock('Soot_on_nesting_ledge',(x,y,1.514),(s*1.5,s,.017),'charcoal',x)

def minotaur(b):
    ORIGINAL_BUILDERS['minotaur'](b)
    discard(b,'Labyrinth_wall','Skull','Skull_jaw','Eye_socket','Nose_socket','Horn_root','Horn_tip')
    # Two offset interior walls force a visible left-right meander behind the gate.
    walls=[(-1.52,.15,.35,2.8),(-.02,1.43,2.64,.34),(1.48,.60,.35,1.75),
        (.43,-.12,1.68,.30),(-.53,.74,1.60,.30)]
    for i,(x,y,w,d) in enumerate(walls):
        for level in range(2):
            if i==2 and level==1: y-=.18; d-=.36
            b.box('Meander_wall',(x,y,.26+level*.38),(w,d,.35),'stone',top='stone_light')
    b.animal_skull((0,-1.45,1.92),.49,True)

def basilisk(b):
    ORIGINAL_BUILDERS['basilisk'](b)
    discard(b,'Shed_dark_feather','Petrified_prey_body','Petrified_prey_leg','Petrified_prey_head','Stone_prey_ear','Stone_tail')
    # A crouched petrified hare, with connected ears and short tail, instead of an ambiguous horned animal.
    x,y=-1.18,-.74; g=ground_at(b,x,y)
    b.box('Stone_hare_body',(x,y,g+.21),(.62,.35,.34),'pale_stone')
    for xx in (x-.20,x+.20):
        for yy in (y-.12,y+.12): b.box('Stone_hare_paw',(xx,yy,g+.065),(.17,.16,.13),'pale_stone')
    b.box('Stone_hare_head',(x-.37,y-.03,g+.42),(.28,.27,.31),'pale_stone')
    b.box('Stone_hare_muzzle',(x-.52,y-.03,g+.35),(.16,.23,.15),'pale_stone')
    for yy in (y-.11,y+.07): b.box('Stone_hare_ear',(x-.35,yy,g+.68),(.10,.08,.30),'pale_stone',rot=(0,-.12,0))
    b.box('Stone_hare_tail',(x+.36,y+.02,g+.25),(.16,.17,.17),'pale_stone')
    for i,(x,y,a) in enumerate([(-.18,-1.24,.18),(.28,-1.27,.7),(.82,-1.09,-.5)]):
        z=ground_at(b,x,y)+.016
        outline=[(-.09,-.25),(.09,-.25),(.13,.09),(0,.35),(-.13,.09)]
        verts=[]
        for zz in (z-.009,z+.009):
            for xx,yy in outline: verts.append((x+xx*math.cos(a)-yy*math.sin(a),y+xx*math.sin(a)+yy*math.cos(a),zz))
        b.mesh('Readable_shed_feather',verts,[(4,3,2,1,0),(5,6,7,8,9)]+[(j,(j+1)%5,(j+1)%5+5,j+5) for j in range(5)],'charcoal')
        b.beam('Feather_shaft',(x+.25*math.sin(a),y-.25*math.cos(a),z+.012),
            (x-.27*math.sin(a),y+.27*math.cos(a),z+.012),.018,'wood_light')

def colossal_worm(b):
    # Continuous fractured funnel; neighboring soil sections share boundaries, no gear-like rings or square shaft.
    n=11; rng=b.rng
    angles=[TAU*i/n+.055*math.sin(i*2.9) for i in range(n)]
    inner=[.57+rng.uniform(-.045,.045) for i in range(n)]
    mid=[.98+rng.uniform(-.10,.10) for i in range(n)]
    outer=[1.69+rng.uniform(-.16,.18) for i in range(n)]
    lip=[.46+rng.uniform(-.12,.21) for i in range(n)]
    for i in range(n):
        j=(i+1)%n; verts=[]
        for k in (i,j):
            a=angles[k]
            cross=[(inner[k],.025),(outer[k],.025),(outer[k],lip[k]*.61),
                   (mid[k],lip[k]),(inner[k],.145)]
            verts.extend((r*math.cos(a),r*math.sin(a),z) for r,z in cross)
        faces=[(4,3,2,1,0),(5,6,7,8,9)]+[(k,(k+1)%5,(k+1)%5+5,k+5) for k in range(5)]
        b.mesh('Fractured_funnel_section',verts,faces,['earth','earth','earth','sand','sand_light','sand','earth'])
    floor=[(inner[i]*1.02*math.cos(a),inner[i]*1.02*math.sin(a),z) for z in (.03,.105) for i,a in enumerate(angles)]
    b.mesh('Dark_tunnel_floor',floor,[tuple(reversed(range(n))),tuple(range(n,2*n))]+
        [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],'black')
    for x,y,w,h,a in [(-1.39,-.89,.55,.17,.3),(1.40,.78,.65,.23,-.4),(-.50,1.72,.50,.14,.7),(.83,-1.48,.49,.12,-.2)]:
        b.rock('Ejected_sand_slab',(x,y,h/2),(w,.42,h),'sand_light',a)
    # One discarded shell fragment with three connected segments, not glowing stepping stones.
    for i in range(3):
        x=.95+i*.28; y=-.98+i*.11
        surface=[]
        for dx,dy in [(0,0),(-.22,-.22),(.22,-.22),(-.22,.22),(.22,.22)]:
            for ob in b.parts:
                if ob['piece']=='Fractured_funnel_section':
                    hit,point,normal,face=ob.ray_cast(Vector((x+dx,y+dy,3)),Vector((0,0,-1)))
                    if hit: surface.append(point.z)
        z=max(surface or [.12])+.09
        b.box('Shed_chitin_segment',(x,y,z),(.40,.38,.13),'chitin_dark',rot=(0,.14,-.22))
        b.box('Amber_chitin_ridge',(x,y,z+.071),(.32,.20,.045),'chitin_amber',rot=(0,.14,-.22))

def embedded_front_patch(b,rock,name,size,paint,offset=.006):
    face=min(rock.data.polygons,key=lambda p:p.normal.y)
    normal=face.normal
    rotation=Vector((0,-1,0)).rotation_difference(normal)
    return b.box(name,face.center+normal*offset,size,paint,rot=rotation.to_euler())

def mineral_crack(b,rock,name,points,front=True):
    face=min(rock.data.polygons,key=lambda p:p.normal.y) if front else max(rock.data.polygons,key=lambda p:p.normal.z)
    normal=face.normal
    right=Vector((1,0,0)); right=(right-normal*right.dot(normal)).normalized()
    up=normal.cross(right).normalized()
    if front and up.z<0: up=-up
    for p,q in zip(points,points[1:]):
        a=face.center+right*p[0]+up*p[1]+normal*.003
        c=face.center+right*q[0]+up*q[1]+normal*.003
        surface_ribbon(b,name,a,c,normal,.040,'violet')

def arboreal_ancient(b):
    ORIGINAL_BUILDERS['arboreal_ancient'](b)
    discard(b,'Ancient_square_spiral','Moss_drape','Cradle_raised_edge','Green_heart_seam','Ancient_root','Root_fork')
    for i,a in enumerate((-.48,.41,1.40,2.57,3.50,4.57)):
        start=(math.cos(a)*.43,math.sin(a)*.43,.32)
        bend=a+.16*(-1)**i
        x,y=math.cos(bend)*1.10,math.sin(bend)*1.10
        middle=(x,y,ground_at(b,x,y)+.063)
        end_angle=bend+.16*(-1)**i
        x,y=math.cos(end_angle)*(1.75+i*.012),math.sin(end_angle)*(1.75+i*.012)
        end=(x,y,ground_at(b,x,y)+.021)
        taper_root(b,'Ancient_curving_root',start,middle,.29,.17)
        taper_root(b,'Ancient_tapered_root',middle,end,.17,.06)
    # Apply the markings to the actual sloped faces, not to an unrelated vertical plane in front.
    pts=[(-.44,.44),(.44,.44),(.44,-.44),(-.44,-.44),(-.44,.18),(.18,.18),(.18,-.18),(-.12,-.18)]
    birthstones=[ob for ob in b.parts if ob['piece']=='Birth_stone']
    for ob in birthstones:
        face=min(ob.data.polygons,key=lambda p:p.normal.y)
        center=face.center; normal=face.normal
        right=Vector((1,0,0)); right=(right-normal*right.dot(normal)).normalized()
        up=normal.cross(right).normalized()
        if up.z<0: up=-up
        for p,q in zip(pts,pts[1:]):
            a=center+right*(p[0]*.58)+up*(p[1]*.58)+normal*.003
            c=center+right*(q[0]*.58)+up*(q[1]*.58)+normal*.003
            b.beam('Surface_bound_spiral',a,c,.016,'slate')
    # Irregular stone plates frame the living seam, replacing the symmetrical bed-like rails.
    b.rock('Cracked_cradle_left',(-.39,-.15,.62),(.45,.91,.23),'stone_light',-.12,'moss')
    b.rock('Cracked_cradle_back',(.13,.10,.61),(.56,.47,.21),'stone_light',.16,'stone_light')
    for a,c in [((-.18,-.59,.563),(-.08,-.26,.563)),((-.08,-.26,.563),(.18,-.12,.563)),((.18,-.12,.563),(.24,.18,.563))]:
        surface_ribbon(b,'Living_green_crack',a,c,Vector((0,0,1)),.052,'green')

def mana_devourer(b):
    b.base('slate')
    # Faulted cubic bedrock, with grey stone outside and mana visible only in broken inner surfaces.
    rocks=[(-.83,-.45,.35,1.15,.93,.53,-.13),(.75,-.37,.38,1.10,1.02,.60,.15),
           (-.61,.82,.49,1.15,.92,.81,.08),(.69,.78,.45,.90,1.05,.73,-.14)]
    bedrocks=[]
    for x,y,z,w,d,h,a in rocks:
        bedrocks.append(b.rock('Ruptured_arcane_bedrock',(x,y,z),(w,d,h),'stone',a,'stone_light'))
    geode=b.rock('Unexcavated_geode',(-1.08,.97,1.01),(.64,.61,1.02),'stone_light',-.10,'stone_light')
    b.rock('Broken_geode_shoulder',(-.80,1.12,1.25),(.47,.47,.43),'stone',.12,'stone_light')
    mineral_crack(b,geode,'Exposed_geode_crack',[(0,-.27),(0,-.04),(.09,.05),(.09,.26)])
    for rock in (bedrocks[0],bedrocks[3]):
        mineral_crack(b,rock,'Top_arcane_fault',[(-.10,-.25),(-.10,-.03),(.05,.10),(.05,.27)],front=False)
    # A dark zigzag fissure and small bright remnants remain grounded in the source material.
    b.box('Fracture_shadow',(0,.05,.194),(.54,1.53,.03),'black',rot=(0,0,-.10))
    for a,c in [((-.04,-.63,.218),(.10,-.19,.218)),((.10,-.19,.218),(-.12,.18,.218)),((-.12,.18,.218),(.06,.72,.218))]:
        b.beam('Residual_mana_vein',a,c,.055,'violet')
    corner=b.rock('Drained_corner_block',(1.18,.99,.90),(.44,.48,.55),'stone_light',.11)
    mineral_crack(b,corner,'Corner_mana_trace',[(0,-.16),(0,.02),(.07,.12)])
    for x,y,s,a in [(-1.45,-.57,.38,.5),(1.31,-.87,.32,-.4),(.02,-1.27,.36,.2)]:
        b.rock('Fracture_debris',(x,y,.22),(s,s*.82,.16),'stone_light',a)

def corrupted_hero(b):
    ORIGINAL_BUILDERS['corrupted_hero'](b)
    discard(b,'Faded_standard','Torn_standard_left','Torn_standard_right','Erased_standard_crest',
        'Forgotten_tower_shield','Shield_blue_panel','Shield_vertical_crest','Seat_back',
        'Discarded_mace_handle','Discarded_mace_head','Square_grass')
    # One ragged closed cloth silhouette, without a clean rectangular body hiding the damage.
    outline=[(-.84,2.32),(-.02,2.32),(-.02,1.47),(-.14,1.57),(-.26,1.37),
             (-.36,1.56),(-.49,1.48),(-.60,1.30),(-.69,1.48),(-.84,1.41)]
    verts=[(x,y,z) for y in (.858,.902) for x,z in outline]; n=len(outline)
    b.mesh('Ragged_watch_standard',verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+
        [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],'bluecloth')
    b.box('Faded_standard_crest',(-.43,.855,1.99),(.20,.014,.19),'stone')
    b.box('Broken_seat_back_left',(-.24,.85,.93),(.48,.12,.63),'wood')
    b.box('Broken_seat_back_right',(.24,.85,.84),(.46,.12,.45),'wood')
    center=Vector((.86,-.55,.79)); rot=Euler((.20,0,-.1)); matrix=rot.to_matrix()
    for name,offset,size,paint in [('Discarded_tower_shield',(0,0,0),(.59,.13,1.13),'iron'),
            ('Attached_blue_shield_panel',(0,-.074,0),(.40,.024,.87),'bluecloth'),
            ('Attached_shield_crest',(0,-.089,0),(.058,.014,.66),'stone_light')]:
        b.box(name,center+matrix@Vector(offset),size,paint,rot=rot)
    b.beam('Visible_mace_handle',(-1.03,-1.15,.34),(-.25,-1.34,.34),.085,'wood')
    b.box('Visible_mace_head',(-1.06,-1.14,.35),(.34,.32,.29),'iron',rot=(0,0,-.24))
    for x,y in [(-.7,-1.42),(.14,-1.47),(.65,-1.25),(1.20,.55)]: b.grass((x,y,.18),'straw')
