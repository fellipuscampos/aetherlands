"""Localized edits of existing military landmarks, executed in the live MCP."""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE=ROOT/'tools/art_pipeline'
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
exec((PIPELINE/'grand_military_draft_parts.py').read_text(encoding='utf-8'))
exec((PIPELINE/'grand_military_geometry_audit.py').read_text(encoding='utf-8'))
bpy.context.window.scene=scene
assert scene.get('grand_military')
changes=[]


def active():
    return [o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio' and not o.get('preview_only')]


def find(name):
    return next((o for o in active() if o['part']==name),None)


def archive(obj,reason):
    obj['preview_only']=True
    obj['finish_archive_reason']=reason
    obj.hide_render=True
    obj.hide_viewport=True
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    groups['09_STUDIO'].objects.link(obj)
    changes.append({'part':obj['part'],'action':'archive','reason':reason})


def shift(objs,delta,reason):
    delta=Vector(delta)
    for obj in objs:
        for v in obj.data.vertices:
            v.co+=delta
        obj.data.update()
    changes.append({'parts':[o['part'] for o in objs],'action':'move','delta':list(delta),'reason':reason})


def cut(obj,normal,plane,reason,record=True):
    """Clip a convex architectural piece and close the cut, keeping its ID."""
    n=Vector(normal).normalized()
    values=[n.dot(v.co) for v in obj.data.vertices]
    if min(values)>plane-1e-6:
        return False
    if max(values)<=plane+1e-6:
        return True
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
        dist=1e-7,plane_co=n*plane,plane_no=n,clear_outer=True,clear_inner=False)
    boundary=[e for e in bm.edges if e.is_boundary]
    if boundary:
        bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),(obj['part'],'cut is not closed')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    # A face count changed: the preserved miniature's face UV list no longer fits.
    for key in ('source_paint_atlas','source_paint_uvs'):
        if key in obj:
            del obj[key]
    if record:
        changes.append({'part':obj['part'],'action':'closed_clip','normal':list(n),'plane':plane,'reason':reason})
    return True


def portal_facade(wallname,prefix,piername):
    door=next(d for d in doors(active()) if d['prefix']==prefix)
    # The old door used the hexagon apothem, but its sharp vertex was forward.
    # Trim just that wedge into a real flat portal, preserving the whole tower.
    front=door['front']+.034
    cut(find(wallname),(0,-1,0),-(front+.002),'flat facade behind existing portal')
    for obj in list(active()):
        if obj['part'].startswith(piername+'_'):
            archive(obj,'front corner pillar blocked the portal; original jambs carry the lintel')


if not scene.get('military_finish_revision'):
    if CIV=='human' and ROLE=='guardian':
        portal_facade('Citadel_Keep_Walls','Keep_Gate','Citadel_Keep_Pier_5')
    if CIV=='dwarf' and ROLE=='ranger':
        portal_facade('Survey_Granite_Tower_Walls','Survey_Entry','Survey_Granite_Tower_Pier_5')
    if CIV=='elf' and ROLE=='guardian':
        portal_facade('Leaf_Shield_Pavilion_Walls','Shield_Pavilion_Gate','Leaf_Shield_Pavilion_Pier_5')
    if CIV=='elf' and ROLE=='rogue':
        portal_facade('Shadow_Left_Pod_Walls','Shadow_Pod_Gate','Shadow_Left_Pod_Pier_5')
        # Stair treads now stop outside the pod and meet its elevated threshold.
        door=next(d for d in doors(active()) if d['prefix']=='Shadow_Pod_Gate')
        target_y=door['front']-.056
        start_y=target_y-7*.058
        target_z=door['bottom']+.009
        for i in range(8):
            obj=find('Shadow_Pod_Stair_'+str(i))
            lo,hi=bb(obj)
            height=(target_z-.077)*(i+1)/8
            for v in obj.data.vertices:
                v.co.y+=start_y+i*.058-(lo.y+hi.y)/2
                v.co.z=.077+(v.co.z-lo.z)/(hi.z-lo.z)*height
            obj.data.update()
        for obj in list(active()):
            if obj['part'].startswith('Shadow_Pod_Gate_Stair_'):
                archive(obj,'ground-height decorative steps duplicated the elevated access')
        # Threshold slab makes the last tread continuous with the pod floor.
        box('Shadow_Entry_Threshold',(-.31,door['front']+.008,target_z-.015),
            (.20,.095,.030),'cutstone','05_COURTYARD')
        changes.append({'action':'fit_staircase','reason':'eight steps meet the elevated portal without entering its wall'})
    if CIV=='orc' and ROLE=='rogue':
        shift([o for o in active() if o['part'].startswith('Sneak_Prep_Awning')],(-.10,-.020,0),
              'move the neighboring awning out of the doorway walking envelope')
        shift([o for o in active() if o['part'].startswith('Poison_Bench')],(-.10,-.020,0),'bench follows its awning')
    if CIV=='dwarf' and ROLE=='rogue':
        shift([o for o in active() if o['part'].startswith('Understone_Hood')],(0,0,.255),
              'hang the crest above the lintel instead of across the opening')
        box('Understone_Sign_Mount',(-.15,-.045,.675),(.14,.240,.16),'cutstone','07_FACTION')
    if CIV=='human' and ROLE=='warrior':
        for obj in list(active()):
            if obj['part'].startswith('Arena_Seat_Support_'):
                seat=find(obj['part'].replace('Arena_Seat_Support_','Arena_Seat_'))
                bottom=bb(seat)[0].z
                if bottom<.078:
                    archive(obj,'first-tier seat already is its filled stone footing')
                else:
                    cut(obj,(0,0,1),bottom+.002,'footing stops inside the seat instead of duplicating its surface')
    if CIV=='human' and ROLE=='cavalry':
        shift([o for o in active() if o['part'] in ('Order_Trough','Order_Water')],(.19,.02,0),
              'move the trough beside the central approach to the officers doorway')
    if CIV=='orc' and ROLE=='cavalry':
        fence=[o for o in active() if o['part'].startswith('War_Mount_Front_Fence')]
        for obj in fence:
            for v in obj.data.vertices:
                x,y=v.co.x+.15,v.co.y+.41
                v.co.x,v.co.y=-.55-y,-.23+x
            obj.data.update()
        changes.append({'action':'rotate_paddock_rail','reason':'side rail leaves both stable approaches open'})
        shift([o for o in active() if o['part'].startswith('War_Lance_')],(.52,.04,0),
              'lances stored beside the handler court, clear of the stable gates')
    if CIV=='dwarf' and ROLE=='warrior':
        shift([o for o in active() if o['part'].startswith('Arena_Armorer')],(.29,.12,0),
              'armorer bench sits beside the arena entrance instead of across it')
    if CIV=='elf' and ROLE=='warrior':
        shift([o for o in active() if o['part'].startswith('Sword_Care_Bench')],(-.075,0,0),
              'clear the central path between the duel gate posts')
    if CIV=='orc' and ROLE=='warrior':
        shift([o for o in active() if o['part'].startswith('Pit_Axes')],(0,0,.18),
              'tribune crest is mounted above the entrance')
        box('Pit_Crest_Mount',(0,.33,.727),(.10,.075,.16),'timber','07_FACTION')
    if CIV=='elf' and ROLE=='warrior':
        shift([o for o in active() if o['part'].startswith('Leaf_Duel_Swords')],(0,0,.29),
              'judges pavilion has its crest above the lintel')
        box('Leaf_Duel_Crest_Mount',(0,.278,.68),(.09,.075,.13),'timber','07_FACTION')
    if CIV=='elf' and ROLE=='ranger':
        shift([o for o in active() if o['part'].startswith('Woodland_Bow')],(0,0,.30),
              'lookout emblem is mounted above its doorway')
        box('Woodland_Bow_Mount',(0,.012,1.815),(.075,.070,.13),'timber','07_FACTION')
        for obj in list(active()):
            if obj['part'].startswith('Tree_Deck_Rail_2_Bar_'):
                archive(obj,'keep the upper lookout entrance open between its rail posts')
        shift([o for o in active() if o['part'] in ('Great_Lookout_Tree_Crown_1','Great_Lookout_Tree_Crown_Top')],(0,0,.37),
              'lift obstructing foliage clear of the lookout entrance')
        branch=find('Great_Lookout_Tree_Branch_1')
        for v in list(branch.data.vertices)[4:]:
            v.co.z+=.37
        branch.data.update()
        beam('Lookout_Canopy_Branch',(-.02,.17,1.51),(-.02,.17,2.10),.054,'timber','04_FOCUS')
        for i,(x,y,z) in enumerate(((-.24,-.145,1.35),(-.24,-.207,1.43),(-.19,-.22,1.51)),12):
            box('Tree_Stair_'+str(i),(x,y,z),(.13,.085,.033),'door','05_COURTYARD')
        box('Tree_Upper_Stair_Landing',(-.10,-.18,1.5075),(.35,.16,.045),'door','05_COURTYARD')
        box('Tree_Pod_Entry_Bridge',(0,-.07,1.5075),(.17,.22,.045),'door','05_COURTYARD')
        beam('Tree_Upper_Stringer',(-.24,-.075,1.26),(-.24,-.22,1.51),.039,'timber','05_COURTYARD')
        beam('Tree_Upper_Landing_Branch',(-.02,.17,1.31),(-.10,-.18,1.50),.048,'timber','05_COURTYARD')
        changes.append({'action':'complete_upper_stair_access','reason':'three final treads and a supported landing join the upper pavilion floor'})
    if CIV=='elf' and ROLE=='siege':
        shift([o for o in active() if o['part'].startswith('Great_Leaf_Ballista')],(.13,-.035,0),
              'demonstration ballista is beside the left assembly entrance')
    # Aerial roosts get a roof socket, instead of a ground pole through the hall.
    if ROLE=='cavalry' and CIV in ('human','orc','dwarf'):
        prefix={'human':'Griffon_Training_Perch','orc':'Tusked_Aerial_Perch','dwarf':'Iron_Aerial_Dock'}[CIV]
        shaft=find(prefix+'_Post_Shaft')
        if shaft is None and CIV=='orc':
            prefix=next(o['part'].split('_Post_Shaft')[0] for o in active() if '_Post_Shaft' in o['part'] and 'Standard' not in o['part'] and 'Dock' in o['part'])
            shaft=find(prefix+'_Post_Shaft')
        assert shaft is not None,(CIV,'roost shaft')
        lo,hi=bb(shaft)
        x,y=(lo.x+hi.x)/2,(lo.y+hi.y)/2
        tops=[]
        for roofobj in active():
            if roofobj.get('region') in ('roof','roof_dark','canvas'):
                hit=obj_bvh(roofobj).ray_cast(Vector((x,y,3)),Vector((0,0,-1)))
                if hit[0] is not None:
                    tops.append(hit[0].z)
        base=max(tops)+.010
        cut(shaft,(0,0,-1),-base,'roost pole starts in a socket above the roof')
        for obj in list(active()):
            if obj['part'].startswith(prefix+'_Post_') and obj!=shaft:
                a,b=bb(obj)
                if b.z<base:
                    archive(obj,'replace ground roost footing by roof socket')
        box(prefix+'_Roof_Socket',(x,y,base+.012),(.105,.105,.038),TRIM,'04_FOCUS')
        box(prefix+'_Roof_Seat',(x,y,base-.007),(.13,.11,.024),'cutstone','04_FOCUS')
    if CIV=='elf' and ROLE=='cavalry':
        archive(find('Order_Leaf_Portal_Backwall'),'an approach portal needs an open passage through its rear')
        for obj in list(active()):
            if obj['part'].startswith('Leaf_Nest_Post_'):
                archive(obj,'living trunk already supports the nest; remove coincident second pole')
        # Split the front rail into two sides and retain a clear central gate.
        for obj in list(active()):
            if obj['part'].startswith(('Leaf_Paddock_1_','Leaf_Paddock_2_')):
                archive(obj,'replace continuous approach fence with an open gate')
        # Reuse existing first side; only the two adjacent railing segments change.
        for file,names in (('grand_military_primitives.py',('support','rail')),):
            import ast
            for node in ast.parse((PIPELINE/file).read_text(encoding='utf-8')).body:
                if isinstance(node,ast.FunctionDef) and node.name in names:
                    exec(compile(ast.Module(body=[node],type_ignores=[]),'<repair railing>','exec'))
        rail('Leaf_Gate_Left',(-.27,-.43),(-.15,-.46),.077,.13)
        rail('Leaf_Gate_Right',(.10,-.46),(.25,-.40),.077,.13)
    if CIV=='dwarf' and ROLE=='cavalry':
        for obj in list(active()):
            if obj['part'].startswith('Order_Court_Rail_Bar_'):
                archive(obj,'continuous rail blocked the left stable bay approach')
        beam('Order_Court_Rail_Short_Lower',(-.46,-.40,.1535),(-.35,-.40,.1535),.025,'cutstone','05_COURTYARD')
        beam('Order_Court_Rail_Short_Upper',(-.46,-.40,.227),(-.35,-.40,.227),.025,'cutstone','05_COURTYARD')
    # Move complete flag assemblies, never their cloth alone.
    if roof_hits(active()):
        flags=[o for o in active() if o['part'].startswith('Standard_')]
        shaft=find('Standard_Shaft')
        lo,hi=bb(shaft)
        old=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,0))
        candidates=[]
        for x in (.62,.66,.70,-.62,-.66,-.70):
            for y in (-.30,-.20,-.10,0,.10,.20,.30):
                delta=Vector((x,y,0))-old
                if any(v.co.dot(Vector((math.cos(i*math.pi/3),math.sin(i*math.pi/3),0)))+
                       delta.dot(Vector((math.cos(i*math.pi/3),math.sin(i*math.pi/3),0)))>math.sqrt(3)/2-.030
                       for o in flags for v in o.data.vertices for i in range(6)):
                    continue
                for o in flags:
                    for v in o.data.vertices:
                        v.co+=delta
                    o.data.update()
                valid=not roof_hits(active()) and not any('Standard_' in name for d in door_blockers(active()) for name in d['blockers'])
                for o in flags:
                    for v in o.data.vertices:
                        v.co-=delta
                    o.data.update()
                if valid:
                    candidates.append((delta.length,delta.copy()))
        assert candidates,'no clear flag position'
        shift(flags,min(candidates,key=lambda p:p[0])[1],'flag pole and cloth clear all roof courses and entrances')
    # Exact duplicate meshes, especially shared fence posts, need just one copy.
    seen={}
    for obj in list(active()):
        key=tuple(sorted(tuple(round(v.co[k],6) for k in range(3)) for v in obj.data.vertices))
        if key in seen:
            archive(obj,'duplicate mesh at the same coordinates as '+seen[key]['part'])
        else:
            seen[key]=obj
    # Recess the lower-priority surface 1.5 mm. This closes each architectural
    # part and keeps the contact volume, without offsetting complete buildings.
    count=0
    for iteration in range(12):
        conflicts=coplanar_conflicts(active())
        if not conflicts:
            break
        touched=set()
        for row in conflicts:
            a,b=find(row['a']),find(row['b'])
            if not a or not b:
                continue
            def priority(obj):
                n=obj['part']
                score=0
                if obj.get('source_paint_atlas'): score+=100
                if obj.get('region') in ('bronze','iron','iron_light','gold','faction'): score+=15
                if any(s in n for s in ('Seat','Capital','Ridge','Collar','Cap','Band','Shield','Blade','Wheel')): score+=10
                if any(s in n for s in ('Foot','Floor','Body','Core','Walls','Shaft','Support','Backwall')): score-=5
                return score
            choices=sorted((a,b),key=priority)
            normal=Vector(row['normal']).normalized()
            for obj in choices:
                key=(obj.name,tuple(round(v,4) for v in normal),round(row['plane'],4))
                if key in touched:
                    break
                vals=[normal.dot(v.co) for v in obj.data.vertices]
                depth=min(.0015,(max(vals)-min(vals))*.12)
                if cut(obj,normal,row['plane']-depth,'recess coincident exposed face',record=False):
                    touched.add(key)
                    count+=1
                    break
    else:
        raise AssertionError('coplanar cleanup failed to converge')
    changes.append({'action':'recess_overlapping_faces','closed_mesh_clips':count,'iterations':iteration+1})
    scene['military_finish_revision']=1
    scene['military_finish_changes_json']=json.dumps(changes,ensure_ascii=False)
else:
    changes=json.loads(scene['military_finish_changes_json'])

if CIV=='human' and ROLE in ('warrior','cavalry') and not scene.get('open_approach_finish_revision'):
    if ROLE=='warrior':
        shift([o for o in active() if o['part'].startswith('Champion_Blades')],(0,0,.33),
              'royal gallery entrance stays open below its heraldry')
        box('Royal_Gallery_Crest_Mount',(0,.375,.805),(.10,.075,.16),'timber','07_FACTION')
    if ROLE=='cavalry':
        for side in (-1,1):
            shift([o for o in active() if o['part'].startswith('Paddock_'+str(side)+'_')],(side*.04,0,0),
                  'fence end posts are beside the stable entrances')
    scene['open_approach_finish_revision']=1
    scene['military_finish_changes_json']=json.dumps(changes,ensure_ascii=False)

if CIV=='dwarf' and ROLE=='ranger' and not scene.get('target_approach_finish_revision'):
    shift([o for o in active() if o['part'].startswith('Crossbow_Target_1_')],(-.19,0,0),
          'central training target is beside the approach to the tower doorway')
    scene['target_approach_finish_revision']=1
    scene['military_finish_changes_json']=json.dumps(changes,ensure_ascii=False)

if CIV=='elf' and ROLE=='cavalry' and not scene.get('gate_brace_finish_revision'):
    branch=find('Leaf_Gate_Left_Post_1_Branch')
    if branch:
        for v in branch.data.vertices:
            v.co.x=-.30-v.co.x
        bm=bmesh.new()
        bm.from_mesh(branch.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(branch.data)
        bm.free()
        branch.data.update()
        changes.append({'part':branch['part'],'action':'reverse_gate_brace','reason':'brace points away from the walking opening'})
    scene['gate_brace_finish_revision']=1
    scene['military_finish_changes_json']=json.dumps(changes,ensure_ascii=False)

# State is reconstructed because clipping/archiving changes the active parts.
for obj in active():
    obj.parent=st['root']
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
parts=st['parts']
audit=geometry_audit(parts,scene)
assert not audit['coplanar_faces'],audit['coplanar_faces'][:4]
assert not audit['mast_roof_intersections'],audit['mast_roof_intersections']
assert not any(d['blockers'] for d in audit['entrances']),audit['entrances']
assert not any(d['blockers'] for d in audit['open_passages']),audit['open_passages']
AUDIT_RUN=False
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
floating=[o['part'] for o in detached(parts)]
assert not floating,floating
scene['physical_attachment_remaining']=[]
scene['military_finish_audit_json']=json.dumps(audit)
st['report']['finish_review']={'revision':1,'method':'live Blender MCP; localized closed-mesh repairs',
    'changes':changes,'geometry_checks':audit,'backup':'art_source/grand_military_before_finish_pass'}
out=Path(st['out'])
(out/(out.name+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
result={'scene':scene.name,'changed_operations':len(changes),'entrances':len(audit['entrances']),
        'coplanar_remaining':0,'masts_remaining':0,'door_blockers_remaining':0,'detached_remaining':0}
