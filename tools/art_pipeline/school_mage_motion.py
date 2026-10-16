"""Shared school-independent choreography for four approved mage anatomies.

World-space rigid deltas, baked at 48 fps; planted feet and in-place roots.
"""
import math
from mathutils import Matrix,Vector,Quaternion
from dwarf_animation_motion import foot_track,solve_chain,key_sample,smoother

FPS=48
LENGTHS={'idle':145,'walk':73,'spell':145}
STARTS={'idle':1,'walk':161,'spell':241}
REVISION=3
STYLE={
 'human':dict(stride=.27,lift=.046,drop=.034,sway=.003,swing=11,release=.56,name='Invocação cerimonial',description='Concentra com a mão livre, ergue o cetro, projeta a magia e recupera com calma.'),
 'elf':dict(stride=.29,lift=.050,drop=.032,sway=.0025,swing=12,release=.58,name='Arco de canalização',description='Desenha um arco suave com a mão livre, conduz o cetro e libera a magia com precisão.'),
 'dwarf':dict(stride=.14,lift=.029,drop=.023,sway=.002,swing=8,release=.54,name='Selo da forja',description='Firma os pés, concentra junto ao peito e libera um pulso firme do cetro com contrapeso do corpo.'),
 'orc':dict(stride=.32,lift=.047,drop=.041,sway=.004,swing=10,walk_staff_pitch=-4,release=.60,name='Chamado xamânico',description='Abre o gesto ritual, ergue o cajado, reúne a força do corpo e projeta a magia.'),
}

def T(v): return Matrix.Translation(Vector(v))
def Q(axis,degrees): return Quaternion(Vector(axis),math.radians(degrees))
def around(point,q): return T(point)@q.to_matrix().to_4x4()@T(-Vector(point))
def keys(t,points): return key_sample(t,points)

def spell_curves(race,t):
    # body: lowering, sagittal shift, pitch, yaw.
    # staff: outward offset, forward offset, lift, pitch, outward roll.
    # palm: outward offset, forward offset, lift, pitch, roll.
    rest=(0,)*14
    if race=='human':
        points={0:rest,.18:(.005,.008,-1,-1, .015,-.012,.080,-10,0, .05,-.08,.17,-8,4),
          .39:(.014,.013,-3,-3, .035,-.025,.345,-38,3, -.12,-.23,.51,-26,12),
          .56:(.008,-.025,3,2, .014,-.065,.285,-37,2, .03,-.36,.57,-32,16),
          .68:(.008,-.025,2.5,2, .014,-.060,.280,-35,2, .03,-.35,.55,-30,16),
          .84:(.004,-.004,.5,.4, .005,-.021,.105,-13,.7, -.01,-.12,.21,-12,5),1:rest}
    elif race=='elf':
        points={0:rest,.18:(.004,.002,-.6,-2, .03,-.015,.100,-11,4, .09,-.06,.19,-9,9),
          .38:(.010,.009,-1.8,-6, .065,-.040,.345,-33,7, .15,-.20,.56,-23,20),
          .58:(.006,-.017,1.5,4, .025,-.080,.335,-34,2, -.07,-.36,.60,-32,24),
          .69:(.005,-.019,1.3,3, .020,-.075,.320,-33,2, -.05,-.34,.57,-29,20),
          .86:(.002,-.004,.2,.5, .005,-.028,.110,-12,1, .01,-.10,.22,-10,7),1:rest}
    elif race=='dwarf':
        points={0:rest,.19:(.009,.007,-2,-3, .012,-.010,.066,-9,2, -.03,-.055,.13,-10,4),
          .39:(.021,.017,-5,-8, .030,-.018,.217,-33,4, -.11,-.19,.50,-30,16),
          .54:(.014,-.034,6,7, .012,-.072,.151,-22,2, -.05,-.27,.53,-25,10),
          .66:(.011,-.028,4,5, .010,-.060,.147,-20,2, -.04,-.25,.49,-23,9),
          .83:(.004,-.005,1,1, .005,-.020,.075,-10,1, -.01,-.09,.17,-8,3),1:rest}
    else:
        points={0:rest,.17:(.008,.012,-2,-2, .025,-.015,.13,-10,2, .08,-.07,.20,-12,10),
          .38:(.026,.024,-5,-7, .050,-.035,.480,-20,5, .13,-.17,.74,-30,24),
          .48:(.030,.022,-5,-7, .055,-.035,.495,-26,5, .14,-.17,.75,-30,24),
          .60:(.018,-.043,7,8, .023,-.104,.410,-40,2, .05,-.35,.72,-37,18),
          .71:(.014,-.037,5,6, .020,-.090,.375,-38,2, .04,-.31,.66,-32,15),
          .86:(.005,-.008,1.5,1, .008,-.028,.125,-16,1, .02,-.10,.22,-10,5),1:rest}
    return keys(t,points)

def arm(chest,side,target,rotation,bones,chains,activity):
    a,b,c,grip=chains['arm_'+side]
    desired=T(target)@rotation.to_matrix().to_4x4()@T(-grip)
    shoulder=chest@a; wrist=desired@c
    maximum=(b-a).length+(c-b).length
    # Ease near full extension: a hard reach clamp makes an elbow snap when
    # the hand begins returning. Fade the softness from the approved rest pose.
    width=(.032 if side=='l' else .020)*max(0.,min(1.,activity))
    distance=(wrist-shoulder).length
    if width>1e-8 and distance>maximum-width:
        reach=maximum-width*math.exp(-(distance-(maximum-width))/width)
        wrist=shoulder+(wrist-shoulder).normalized()*reach
        desired=T(wrist-(desired@c))@desired
    elif distance>maximum:
        wrist=shoulder+(wrist-shoulder).normalized()*(maximum-.00001)
        desired=T(wrist-(desired@c))@desired
    axis=(c-a).normalized(); pole=b-a-axis*(b-a).dot(axis)
    bent=pole.length>.00001
    sign=1 if grip.x>a.x else -1
    outward=Vector((sign,-.15,-.12)).normalized()
    # A straight resting arm has no bend plane. Keep its elbow outward
    # throughout the gesture, avoiding a pole singularity during recovery.
    if not bent: pole=Vector((sign,.20,-.4)).normalized()
    else: pole=pole.normalized().lerp(outward,min(.72,max(0.,activity))*.55).normalized()
    upper,fore,actual=solve_chain(a,b,c,shoulder,wrist,chest.to_3x3()@pole,stable_roll=bent)
    desired=T(actual-wrist)@desired
    return {'upper_arm_'+side:upper,'forearm_'+side:fore,'hand_'+side:desired}

def elbow_axis(chain):
    a,b,c=chain[:3]
    axis=(c-b).cross(b-a)
    if axis.length<1e-5:
        fore=(c-b).normalized()
        axis=Vector((1,0,0))-fore*fore.x
    if axis.x<0: axis=-axis
    return axis.normalized()

def articulated_arm(chest,side,bones,chains,pitch,spread,bend,sweep=0,wrist=0):
    """An anatomical hinge: the hand follows the forearm, never re-solves IK.

    Shoulder raises/opens the arm; elbow bends about one rest-space axis.
    The wide dwarf forearm therefore cannot roll independently of the elbow.
    """
    a,b,c,grip=chains['arm_'+side]; sign=1 if grip.x>0 else -1
    shoulder=Q((0,0,1),sign*sweep)@Q((0,1,0),-sign*spread)@Q((1,0,0),-pitch)
    upper=chest@around(a,shoulder)
    hinge=elbow_axis(chains['arm_'+side])
    fore=upper@around(b,Q(hinge,-bend))
    hand=fore@around(c,Q(hinge,wrist))
    return {'upper_arm_'+side:upper,'forearm_'+side:fore,'hand_'+side:hand}

def casting_arm_angles(race,t,side):
    # Values: shoulder elevation, spread, elbow flex, shoulder sweep, wrist.
    # Rest-relative joint angles with smooth passing velocities and recovery.
    rest=(0,)*5
    if side=='r':
        if race=='human': points={0:rest,.18:(5,1,3,0,0),.39:(22,3,14,1,0),.56:(18,2,8,0,0),.68:(17,2,8,0,0),.84:(6,.6,3,0,0),1:rest}
        elif race=='elf': points={0:rest,.18:(6,2,3,1,0),.38:(23,5,12,3,0),.58:(20,3,9,-1,0),.69:(19,3,9,-1,0),.86:(6,1,3,0,0),1:rest}
        elif race=='dwarf': points={0:rest,.19:(4,1,3,0,0),.39:(19,3,13,2,0),.54:(13,2,6,-2,0),.66:(12,2,6,-1,0),.83:(4,.5,3,0,0),1:rest}
        else: points={0:rest,.17:(7,2,4,1,0),.38:(28,8,15,4,0),.48:(30,8,15,4,0),.60:(23,4,9,-2,0),.71:(20,4,9,-1,0),.86:(7,1,4,0,0),1:rest}
    else:
        if race=='human': points={0:rest,.18:(5,3,25,0,0),.39:(24,4,88,4,4),.56:(51,7,47,0,-3),.68:(49,7,48,0,-2),.84:(15,3,28,0,0),1:rest}
        elif race=='elf': points={0:rest,.18:(6,7,28,5,1),.38:(27,12,82,15,5),.58:(53,6,48,-5,-4),.69:(49,7,49,-3,-3),.86:(14,5,27,2,0),1:rest}
        elif race=='dwarf': points={0:rest,.19:(4,3,24,1,0),.39:(22,6,84,3,3),.54:(44,5,44,-2,-2),.66:(42,5,45,-1,-1),.83:(12,2,24,0,0),1:rest}
        else: points={0:rest,.17:(6,8,25,4,0),.38:(28,18,86,9,4),.48:(30,20,84,9,4),.60:(54,22,44,-3,-3),.71:(48,20,47,-1,-2),.86:(15,6,27,2,0),1:rest}
    return keys(t,points)

def pose(race,clip,t,bones,chains):
    out={name:Matrix.Identity(4) for name in bones}; style=STYLE[race]
    if clip in ('idle','spell') and (t<1e-9 or t>1-1e-9): return out
    p=math.tau*t; wave=(1-math.cos(p))/2
    if clip=='idle':
        hips=T((.0008*wave*math.sin(p),0,-.002*wave))
        chest=hips@around(bones['chest'],Q((1,0,0),.55*math.sin(p)))@around(bones['chest'],Q((0,0,1),.40*wave*math.sin(p)))
        head=chest@around(bones['head'],Q((0,0,1),.7*wave*math.sin(p)))
    elif clip=='walk':
        hips=T((style['sway']*math.sin(p),0,-style['drop']+.004*(1-math.cos(2*p))/2))@around(bones['hips'],Q((0,0,1),.7*math.sin(p)))
        chest=hips@around(bones['chest'],Q((1,0,0),1.3+.4*math.sin(2*p)))@around(bones['chest'],Q((0,0,1),-1.4*math.sin(p)))
        head=chest@around(bones['head'],Q((1,0,0),-.6))@around(bones['head'],Q((0,0,1),.5*math.sin(p)))
    else:
        drop,shift,pitch,yaw,sx,sy,sz,sp,sr,fx,fy,fz,fp,fr=spell_curves(race,t)
        hips=T((0,shift,-drop))@around(bones['hips'],Q((0,0,1),yaw*.12))
        chest=hips@around(bones['chest'],Q((1,0,0),pitch))@around(bones['chest'],Q((0,0,1),yaw))
        head=chest@around(bones['head'],Q((1,0,0),-pitch*.55))@around(bones['head'],Q((0,0,1),-yaw*.65))
    out.update(hips=hips,chest=chest,head=head)
    for side in ('l','r'):
        a,b,c=chains['leg_'+side]
        target=foot_track(t+(0 if side=='l' else .5),c,style['stride'],style['lift'],.62) if clip=='walk' else c.copy()
        thigh,shin,actual=solve_chain(a,b,c,hips@a,target,Vector((0,-1,0)))
        out.update({'thigh_'+side:thigh,'shin_'+side:shin,'foot_'+side:T(actual-c)})
    a,b,c,grip=chains['arm_r']; sign=1 if grip.x>0 else -1
    if clip=='idle': target=grip+Vector((0,.002*wave*math.sin(p),.004*wave)); rot=Q((1,0,0),.4*wave*math.sin(p)); activity=.025*wave
    elif clip=='walk': target=grip+Vector((.003*math.sin(p),.012*math.sin(p),.034+.008*(1-math.cos(2*p))/2)); rot=Q((1,0,0),style.get('walk_staff_pitch',0)+1.6*math.sin(p)); activity=.04
    else: target=grip+Vector((sign*sx,sy,sz)); rot=Q((1,0,0),sp)@Q((0,1,0),sign*sr); activity=min(1,sz/.3)
    if clip=='spell': out.update(articulated_arm(chest,'r',bones,chains,*casting_arm_angles(race,t,'r')))
    else: out.update(arm(chest,'r',target,rot,bones,chains,activity))
    a,b,c,grip=chains['arm_l']; sign=1 if grip.x>0 else -1
    if clip=='spell':
        out.update(articulated_arm(chest,'l',bones,chains,*casting_arm_angles(race,t,'l')))
    else:
        swing=.6*wave*math.sin(p) if clip=='idle' else style['swing']*math.sin(p)
        upper=chest@around(a,Q((1,0,0),swing))
        flex=-.4*wave if clip=='idle' else -4-2*wave
        fore=upper@around(b,Q(elbow_axis(chains['arm_l']),flex))
        out.update({'upper_arm_l':upper,'forearm_l':fore,'hand_l':fore})
    return out
