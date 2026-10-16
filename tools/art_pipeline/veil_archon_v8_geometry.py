# Nonhumanoid fractured runic polyhedron, from the user's latest image.
C=Vector((0,0,1.70))
centers={'shell':C.copy(),'lattice':C.copy(),'core':C.copy(),'orbit':C.copy()}
parents={n:'root' for n in centers}

def orientation(normal,twist=0):
    n=Vector(normal).normalized();up=Vector((0,0,1))
    if abs(up.dot(n))>.95:up=Vector((0,1,0))
    up=(up-n*up.dot(n)).normalized();right=up.cross(n).normalized()
    R=Matrix((right,-n,up)).transposed()
    return R@Matrix.Rotation(math.radians(twist),3,'Y')

def tile(label,normal,radius,width,height,seed,offset=(0,0),twist=0,corner=False):
    n=Vector(normal).normalized();R=orientation(n,twist)
    c=C+n*radius+R@Vector((offset[0],0,offset[1]))
    bone='panel_'+str(seed).zfill(2);centers[bone]=c.copy();parents[bone]='shell'
    w=width/2;h=height/2;q=min(width,height)*.14
    if corner:
        # Triangular overall silhouette translated into right-angle steps.
        profile=[(-w,-h),(w,-h),(w,-h+q),(w-q,-h+q),(w-q,-h+2*q),
          (w-2*q,-h+2*q),(w-2*q,h-q),(q/2,h-q),(q/2,h),(-q/2,h),
          (-q/2,h-q),(-w+2*q,h-q),(-w+2*q,-h+2*q),(-w+q,-h+2*q),(-w+q,-h+q),(-w,-h+q)]
    else:
        # The square stone has two stepped clipped corners, never a rounded bevel.
        profile=[(-w,-h),(w-q,-h),(w-q,-h+q),(w,-h+q),
          (w,h),(-w+q,h),(-w+q,h-q),(-w,h-q)]
    o=prism(label,profile,.14 if not corner else .12,c,bone,'plate',R)
    o['rune_seed']=seed;o['rune_count']=2 if width>.80 else 1
    o['layer']='corner' if corner else 'edge' if len([x for x in normal if x])==2 else 'main'
    return o

seed=0
# The front has four individual plates around a broad cross-shaped aperture.
for x,z in [(-.370,.370),(.370,.370),(-.370,-.370),(.370,-.370)]:
    tile('Front_Runestone_'+str(seed),(0,-1,0),1.16,.60,.63,seed,(x,z),[3,-4,-2,4][seed]);seed+=1
# Other principal faces are split asymmetrically, rather than a repeating Rubik cube grid.
for normal in [(1,0,0),(-1,0,0),(0,1,0),(0,0,1),(0,0,-1)]:
    tile('Main_Upper_Runestone_'+str(seed),normal,1.16,1.12,.56,seed,(-.035,.340),3 if seed%2 else -3);seed+=1
    tile('Main_Lower_Runestone_'+str(seed),normal,1.19,1.04,.56,seed,(.035,-.340),-2 if seed%2 else 2);seed+=1
# Twelve oblique edge plates fill the next layer with a clear luminous gap between pieces.
for zero in range(3):
    active=[i for i in range(3) if i!=zero]
    for a in (-1,1):
        for b in (-1,1):
            n=[0,0,0];n[active[0]]=a;n[active[1]]=b
            tile('Oblique_Edge_Runestone_'+str(seed),n,1.525,.82,.80,seed,twist=(-3 if seed%2 else 3));seed+=1
# Eight stepped vertex shards complete a faceted orb, with a different plane orientation each.
for x in (-1,1):
    for y in (-1,1):
        for z in (-1,1):
            tile('Vertex_Runestone_'+str(seed),(x,y,z),1.57,.80,.76,seed,twist=(5 if seed%2 else -5),corner=True);seed+=1

# A luminous, open inner cage lets the cube remain visible through the actual openings.
Rinner=Euler((math.radians(8),math.radians(5),math.radians(12))).to_matrix()
r=.87
for axis in range(3):
    other=[i for i in range(3) if i!=axis]
    for a in (-1,1):
        for b in (-1,1):
            p=Vector((0,0,0));q=p.copy();p[axis]=-r;q[axis]=r
            p[other[0]]=q[other[0]]=a*r;p[other[1]]=q[other[1]]=b*r
            beam('Inner_Mana_Edge_'+str(axis)+'_'+str(a)+'_'+str(b),C+Rinner@p,C+Rinner@q,.075,.075,'lattice','lattice')
box('White_Violet_Mana_Core',C,(.96,.96,.96),'core','core',
    Euler((math.radians(18),math.radians(12),math.radians(22))).to_matrix())

# One thin broken angular orbit echoes the image's energy trail without a smooth torus.
Rorbit=Euler((math.radians(8),math.radians(-23),math.radians(13))).to_matrix()
loop=[(-1.47,0,-.65),(-1.08,0,-1.28),(.33,0,-1.50),(1.38,0,-.82),
      (1.50,0,.55),(.88,0,1.34),(-.40,0,1.49),(-1.40,0,.73)]
for i in [0,1,2,4,5,6]:
    a=C+Rorbit@Vector(loop[i]);b=C+Rorbit@Vector(loop[(i+1)%8])
    beam('Broken_Angular_Mana_Orbit_'+str(i),a,b,.027,.035,'orbit','orbit')
