"""Single choreography per dwarf class; no tier-specific animation branches."""
import math
from mathutils import Matrix, Vector, Quaternion

LEGS = ('L_front', 'R_front', 'L_hind', 'R_hind')
FPS = 48
REVISION = 3
AUTHOR_LENGTHS = {family: dict(idle=73, walk=29, attack=41)
           for family in ('guardian', 'warrior', 'ranger', 'rogue')}
AUTHOR_LENGTHS['cavalry'] = dict(idle=73, walk=25, attack=45)
AUTHOR_LENGTHS['siege'] = dict(idle=73, walk=49, attack=61)
AUTHOR_IMPACT = dict(guardian=18, warrior=19, ranger=15, rogue=19, cavalry=20, siege=24)
# Choreography uses seconds expressed at 24 fps; bake twice as densely while
# preserving its duration. This improves the actual assets AND video previews.
LENGTHS = {f: {c: (n-1)*2+1 for c, n in clips.items()} for f, clips in AUTHOR_LENGTHS.items()}
IMPACT = {f: (n-1)*2+1 for f, n in AUTHOR_IMPACT.items()}
TRANSLATED = {f: {'pelvis'} for f in ('guardian', 'warrior', 'ranger', 'rogue')}
TRANSLATED['cavalry'] = {'mount_body', 'pelvis'}
TRANSLATED['siege'] = {'chassis', 'recoil', 'piston_L', 'piston_R'}
DESCRIPTIONS = {
    'guardian': dict(idle='Respiração discreta, guarda firme com o escudo.',
        walk='Passos curtos e pesados; escudo estável e braço livre em contrapeso.',
        attack='Preparação, avanço do tronco e golpe frontal de escudo; recuperação.'),
    'warrior': dict(idle='Respiração e pequeno ajuste do martelo, mantendo uma mão livre.',
        walk='Passada pesada com contrapeso do braço livre e martelo seguro.',
        attack='Martelo erguido acima do ombro, arco frontal forte e recuperação.'),
    'ranger': dict(idle='Vigia atento com besta apontada à frente.',
        walk='Passos controlados, besta à frente, braço livre em balanço e tronco em contrapeso.',
        attack='Ergue ligeiramente a mira, dispara com recuo curto e retorna à guarda.'),
    'rogue': dict(idle='Respiração contida e olhar atento.',
        walk='Passos baixos e leves; lâmina firme em uma mão.',
        attack='Prepara a lâmina e executa um corte/estocada rápida à frente.'),
    'cavalry': dict(idle='Carneiro respira e move a cabeça; cavaleiro acompanha a sela.',
        walk='Trote articulado: coxas, canelas e cascos das quatro pernas; cavaleiro acompanha a sela.',
        attack='Carneiro firma a postura e cavaleiro executa um golpe frontal de machado com uma mão.'),
    'siege': dict(idle='Completamente imóvel.',
        walk='Rodas giram, chassi oscila discretamente e pistões acompanham o deslocamento.',
        attack='Ciclo comum de preparar, liberar/disparar e recuperar; braço ou recuo conforme o mecanismo.')
}


def T(v): return Matrix.Translation(Vector(v))
def qx(d): return Quaternion((1, 0, 0), math.radians(d))
def qy(d): return Quaternion((0, 1, 0), math.radians(d))
def qz(d): return Quaternion((0, 0, 1), math.radians(d))
def around(p, q): return T(p) @ q.to_matrix().to_4x4() @ T(-Vector(p))
def smooth(t):
    t = max(0., min(1., t)); return t*t*(3-2*t)


def smoother(t):
    t = max(0., min(1., t)); return t*t*t*(10+t*(-15+6*t))


def key_sample(frame, keys):
    """Monotone cubic curves: continuous velocity through intermediate poses.

    Endpoints/true reversals stop; passing poses retain velocity. Limiting
    tangents avoids overshooting contacts, recoil limits or short-arm reach.
    """
    times = sorted(keys)
    if frame <= times[0]: return list(keys[times[0]])
    if frame >= times[-1]: return list(keys[times[-1]])
    i = max(i for i, f in enumerate(times[:-1]) if f <= frame)
    a, b = times[i], times[i+1]; h = b-a; t = (frame-a)/h
    def slope(index, dimension):
        if index in (0, len(times)-1): return 0.
        p, f, n = times[index-1:index+2]
        left = (keys[f][dimension]-keys[p][dimension])/(f-p)
        right = (keys[n][dimension]-keys[f][dimension])/(n-f)
        if left*right <= 0: return 0.
        w1, w2 = 2*(n-f)+(f-p), (n-f)+2*(f-p)
        return (w1+w2)/(w1/left+w2/right)
    return [(2*t**3-3*t*t+1)*v+(t**3-2*t*t+t)*h*slope(i,d)
            +(-2*t**3+3*t*t)*w+(t**3-t*t)*h*slope(i+1,d)
            for d, (v,w) in enumerate(zip(keys[a], keys[b]))]


def solve_chain(a, b, c, a2, c2, pole, stable_roll=False):
    """Two rigid segments; preserve lengths and return world-space deltas."""
    l1, l2 = (b-a).length, (c-b).length
    u = c2-a2; distance = u.length
    if distance > l1+l2:
        distance = l1+l2; c2 = a2+u.normalized()*distance
    distance = max(abs(l1-l2)+1e-6, distance)
    u = (c2-a2).normalized()
    p = pole-u*pole.dot(u)
    if p.length < 1e-6: p = Vector((0, -1, 0))-u*Vector((0, -1, 0)).dot(u)
    p.normalize()
    x = (l1*l1-l2*l2+distance*distance)/(2*distance)
    height = math.sqrt(max(0., l1*l1-x*x))
    b2 = a2+u*x+p*height
    if stable_roll:
        # A shortest-arc quaternion flips its roll when a raised arm passes
        # opposite its rest direction. Carry the elbow plane with the limb.
        rest_normal = (c-a).cross(b-a).normalized()
        pose_normal = u.cross(p).normalized()
        def frame(axis, normal):
            axis = axis.normalized()
            return Matrix((axis, normal.cross(axis).normalized(), normal)).transposed()
        r1 = (frame(b2-a2, pose_normal)@frame(b-a, rest_normal).transposed()).to_4x4()
        r2 = (frame(c2-b2, pose_normal)@frame(c-b, rest_normal).transposed()).to_4x4()
    else:
        r1 = (b-a).normalized().rotation_difference((b2-a2).normalized()).to_matrix().to_4x4()
        r2 = (c-b).normalized().rotation_difference((c2-b2).normalized()).to_matrix().to_4x4()
    return T(a2)@r1@T(-a), T(b2)@r2@T(-b), c2


def foot_track(phase, base, stride, lift, duty=.62):
    phase %= 1.
    if phase < duty:
        return base+Vector((0, -stride/2+stride*phase/duty, 0))
    t = (phase-duty)/(1-duty)
    ease = smoother(t)
    # Match both velocity and acceleration with the planted foot at takeoff
    # and landing. The old sine lift/zero-tangent horizontal arc jerked there.
    tangent = stride*(1-duty)/duty
    y = stride/2-stride*ease+tangent*(t-ease)
    return base+Vector((0, y, lift*math.sin(math.pi*t)**4))


def leg_ik(out, bones, side, base, target, mount=False):
    prefix = 'mount_' if mount else ''
    names = (prefix+'thigh_'+side, prefix+'shin_'+side, prefix+('hoof_' if mount else 'foot_')+side)
    a, b, c = (bones[n]['head'] for n in names)
    a2 = base@a
    rest_axis = (c-a).normalized()
    pole = b-a-rest_axis*(b-a).dot(rest_axis)
    if pole.length < 1e-5: pole = Vector((0, -1, 0))
    thigh, shin, actual = solve_chain(a, b, c, a2, target, base.to_3x3()@pole)
    # Feet remain level during stance AND swing: the long toes never scoop
    # through the floor, and the shin/boot junction remains attached.
    out['world'][names[0]] = thigh
    out['world'][names[1]] = shin
    out['world'][names[2]] = T(actual)@T(-c)


def arm_ik(out, bones, side, chest, target, angle=0, twist=0, pole_weight=None):
    up, fore, hand = 'upper_arm_'+side, 'forearm_'+side, 'hand_'+side
    a, b, c = (bones[n]['head'] for n in (up, fore, hand))
    grip = bones[hand]['grip']; rotation = qx(angle)@qz(twist)
    desired = chest@T(target)@rotation.to_matrix().to_4x4()@T(-grip)
    a2, c2 = chest@a, desired@c
    length = (b-a).length+(c-b).length
    distance = (c2-a2).length
    width = .045
    if distance > length-width:
        softened = length-width*math.exp(-(distance-(length-width))/width)
        c2 = a2+(c2-a2).normalized()*softened
        desired = T(c2-(desired@c))@desired
    rest_axis = (c-a).normalized()
    pole = b-a-rest_axis*(b-a).dot(rest_axis)
    if pole.length < 1e-6: pole = Vector((1 if side == 'R' else -1, 0, -1))
    # As the wrist rises past the shoulder, guide the elbow outward rather
    # than allowing a fixed downward pole to become collinear with the arm.
    local_wrist = chest.inverted()@c2
    raise_weight = smoother((local_wrist.z-a.z+.10)/.32) if pole_weight is None else pole_weight
    pole = pole.normalized().lerp(Vector((1 if side == 'R' else -1, 0, 0)), raise_weight)
    upper, lower, actual = solve_chain(a, b, c, a2, c2, chest.to_3x3()@pole, stable_roll=True)
    desired = T(actual-c2)@desired
    out['world'].update({up: upper, fore: lower, hand: desired})


def _pose_authored(family, clip, frame, bones):
    out = dict(rotation={}, location={}, scale={}, world={})
    rot, loc = out['rotation'], out['location']
    n = AUTHOR_LENGTHS[family][clip]; phase = (frame-1)/(n-1); p = math.tau*phase
    breathe = (1-math.cos(p))/2
    if family == 'siege':
        if clip == 'idle': return out
        if clip == 'walk':
            for side in ('L', 'R'):
                for end in ('front', 'hind'): rot['wheel_'+side+'_'+end] = qx(360*phase)
            loc['chassis'] = (0, 0, .004*(1-math.cos(4*p)))
            loc['piston_L'] = (0, .035*math.sin(2*p), 0)
            loc['piston_R'] = (0, -.035*math.sin(2*p), 0)
        else:
            angle, recoil, shake, sling = key_sample(frame, {
                1:(0,0,0,0), 15:(-34,0,0,12), 19:(-36,0,0,14),
                24:(76,.12,.012,-24), 27:(76,.105,.003,-18),
                35:(48,.055,0,-10), 52:(0,0,0,0), 61:(0,0,0,0)})
            rot['throwing_arm'] = qx(angle)
            rot['counterweight'] = qx(-angle)
            rot['sling'] = qx(sling)
            loc['recoil'] = (0, recoil, 0)
            loc['chassis'] = (0, 0, shake)
            # Projectile effects belong to gameplay. The carried stone leaves
            # the cup on release and is replaced at the end of reloading.
            out['scale']['payload'] = (1, 1, 1) if frame < 24 or frame >= 57 else (.001, .001, .001)
            loc['piston_L'] = (0, recoil*.4, 0); loc['piston_R'] = (0, recoil*.4, 0)
        return out
    mount = family == 'cavalry'
    base = Matrix.Identity(4)
    pelvis_off = Vector()
    chest_pitch = chest_twist = 0.
    hip_yaw = hip_roll = chest_roll = 0.
    step = 0.
    if mount:
        pitch = 0.; body_off = Vector()
        if clip == 'idle':
            body_off.z = -.006*breathe*breathe
            pitch = .8*breathe*math.sin(p)
            rot['mount_neck'] = qx(3*math.sin(p)); rot['mount_head'] = qx(2*math.sin(p-.25)+2*math.sin(.25))
            chest_pitch = 1.8*breathe-pitch*.65
            chest_twist = 2*breathe*math.sin(p)
            hip_yaw = .8*breathe*math.sin(p)
        elif clip == 'walk':
            body_off.z = -.075+.008*math.cos(2*p)
            pitch = 3.8*math.sin(p)
            rot['mount_neck'] = qx(-pitch*.8+1.4*math.sin(p-.35))
            rot['mount_head'] = qx(-pitch*.3)
            chest_pitch = 3-pitch*.8
            chest_twist = 3*math.sin(p-.3)
            hip_yaw = -1.2*math.sin(p)
            pelvis_off.z = .008*math.sin(2*p-.3)
        else:
            pitch, z, chest_pitch, chest_twist, hip_yaw = key_sample(frame, {
                1:(0,0,0,0,0), 8:(-2,-.010,-3,-5,-1), 13:(-3.5,-.018,-7,-12,-3),
                20:(3.8,-.025,13,16,3), 25:(3,-.024,11,18,4),
                34:(1,-.009,4,6,1), 45:(0,0,0,0,0)})
            body_off.z = z
            rot['mount_neck'] = qx(-pitch*.5); rot['mount_head'] = qx(-pitch*.25)
        loc['mount_body'] = body_off; rot['mount_body'] = qx(pitch)
        base = T(body_off)@around(bones['mount_body']['head'], qx(pitch))
        for leg in LEGS:
            ankle = bones['mount_hoof_'+leg]['head']
            if clip == 'walk':
                # Diagonal trot: LF/RH together, RF/LH half a cycle later.
                offset = 0 if leg in ('L_front', 'R_hind') else .5
                target = foot_track(phase+offset, ankle, .36, .11, .58)
            else: target = ankle.copy()
            leg_ik(out, bones, leg, base, target, True)
    elif clip == 'idle':
        pelvis_off = Vector((.014*breathe*math.sin(p), 0, -.012*breathe*breathe))
        hip_yaw = 1.5*breathe*math.sin(p)
        hip_roll = .8*breathe*breathe*math.sin(p)
        chest_pitch = 2*breathe
        chest_twist = 2.5*math.sin(p)
        chest_roll = -.6*breathe*math.sin(p)
    elif clip == 'walk':
        pelvis_off = Vector((.016*math.sin(p), 0, -.037-.006*math.cos(2*p)))
        hip_yaw = 3.5*math.sin(p)
        hip_roll = 1.2*math.sin(p)
        chest_pitch = 5.0 if family == 'rogue' else 3.0
        chest_twist = -6.5*math.sin(p)
        chest_roll = -.8*math.sin(p-.25)
    else:
        if family == 'guardian':
            y, z, hip_yaw, hip_roll, chest_pitch, chest_twist, step = key_sample(frame, {
                1:(0,0,0,0,0,0,0), 8:(.022,-.012,2,-.6,-5,7,0),
                12:(.03,-.021,3,-1,-7,11,.15), 18:(-.07,-.036,-3,1,15,-12,1),
                23:(-.073,-.034,-4,.8,13,-14,1), 30:(-.025,-.015,-1,.3,4,-5,.4),
                41:(0,0,0,0,0,0,0)})
        elif family == 'warrior':
            y, z, hip_yaw, hip_roll, chest_pitch, chest_twist, step = key_sample(frame, {
                1:(0,0,0,0,0,0,0), 8:(.022,-.018,-3,-.6,-4,-9,0),
                13:(.032,-.025,-5,-1,-8,-16,.2), 19:(-.055,-.038,4,1,16,18,1),
                24:(-.060,-.036,5,.8,14,20,1), 31:(-.020,-.016,2,.3,4,6,.3),
                41:(0,0,0,0,0,0,0)})
        elif family == 'rogue':
            y, z, hip_yaw, hip_roll, chest_pitch, chest_twist, step = key_sample(frame, {
                1:(0,0,0,0,0,0,0), 8:(.022,-.021,-3,-.5,-3,-12,0),
                12:(.025,-.028,-4,-.8,-4,-18,.2), 19:(-.058,-.042,4,1,17,20,1),
                24:(-.060,-.035,5,.6,12,22,1), 31:(-.020,-.019,2,.3,4,8,.4),
                41:(0,0,0,0,0,0,0)})
        else:
            y, z, hip_yaw, hip_roll, chest_pitch, chest_twist, step = key_sample(frame, {
                1:(0,0,0,0,0,0,0), 8:(-.012,-.014,-1,.3,3,-4,0),
                13:(-.019,-.017,-2,.5,4,-7,0), 15:(.018,-.023,-2,.5,-2,-7,0),
                19:(.010,-.020,-2,.4,-1,-6,0), 27:(-.008,-.012,-1,.2,2,-3,0),
                41:(0,0,0,0,0,0,0)})
        pelvis_off = Vector((0,y,z))
    loc['pelvis'] = pelvis_off
    rot['pelvis'] = qz(hip_yaw)@qy(hip_roll)
    rot['chest'] = qx(chest_pitch)@qz(chest_twist)@qy(chest_roll-hip_roll*.5)
    rot['head'] = qz(8*math.sin(p) if clip == 'idle' else -(hip_yaw+chest_twist)*.65)@qx(-chest_pitch*.6)
    hips = base@T(pelvis_off)@around(bones['pelvis']['head'], rot['pelvis'])
    chest = hips@around(bones['chest']['head'], rot['chest'])
    if not mount:
        for side in ('L', 'R'):
            ankle = bones['foot_'+side]['head']
            if clip == 'walk':
                target = foot_track(phase+(0 if side == 'L' else .5), ankle, .19, .066, .60)
            else:
                target = ankle.copy()
                if clip == 'attack' and side == 'L' and step:
                    target += Vector((0, -.095*step, .034*math.sin(math.pi*step)**4))
            leg_ik(out, bones, side, hips, target)
    free = 'R' if family == 'guardian' else 'L'
    # The support arm participates in every clip, including the rein hand.
    # All motion is sagittal/counterbalance, with restrained wrist rotation.
    if mount: free = 'L'
    if clip == 'idle':
        upper = -3*breathe+1.8*math.sin(p)
        fore = 4*breathe+1.5*(math.sin(p-.3)+math.sin(.3))
        wrist = -.8*breathe
    elif clip == 'walk':
        if mount:
            upper, fore, wrist = -6*math.sin(p), 4*math.sin(p-.35), -.5*math.sin(p)
        else:
            sign = 1 if free == 'R' else -1
            upper = sign*19*math.sin(p-.12)
            fore = 9+5*math.sin(p-.55)
            wrist = -2*math.sin(p-.2)
    else:
        hit = AUTHOR_IMPACT[family]
        strength = .65 if family == 'ranger' else .5 if mount else 1.
        upper, fore, wrist = key_sample(frame, {
            1:(0,0,0), 8:(-27*strength,12*strength,-1),
            12:(-42*strength,20*strength,-2), hit:(16*strength,10*strength,1),
            hit+6:(22*strength,14*strength,1.5), n-9:(-8*strength,10*strength,-1), n:(0,0,0)})
    if not mount:
        # The relaxed elbow bends toward the front of the body. Positive X
        # opens this almost straight rest arm backward, looking hyperextended.
        # Keep a modest flexion even at the idle/attack endpoints and vary it
        # with the existing counterbalance, instead of locking the elbow.
        fore = -(18 + max(0., fore)*.65)
    rot['upper_arm_'+free] = qx(upper)
    rot['forearm_'+free] = qx(fore)
    rot['hand_'+free] = qx(wrist)
    side = 'L' if family == 'guardian' else 'R'
    grip = bones['hand_'+side]['grip']
    target = grip.copy(); angle = twist = 0.
    if clip == 'idle':
        target += Vector((0, .009*math.sin(p), .011*breathe))
        angle = 1.8*math.sin(p)
    elif clip == 'walk':
        sign = -1 if side == 'R' else 1
        amplitude = .025 if mount else .035 if family == 'guardian' else .038 if family == 'ranger' else .060
        target += Vector((0, sign*amplitude*math.sin(p-.1), .010*math.sin(2*p-.3)))
        angle = (3 if mount or family == 'ranger' else 7)*math.sin(p-.15)
    elif family in ('warrior', 'cavalry'):
        lift = .71 if mount else 0.
        x, y, z, angle = key_sample(frame, {
            1:(grip.x, grip.y, grip.z,0),
            6:(.55,-.24,1.05+lift,-26),
            12:(.54,-.06,1.24+lift,-66),
            15:(.53,-.13,1.26+lift,-30),
            AUTHOR_IMPACT[family]:(.56,-.43,.81+lift,90),
            AUTHOR_IMPACT[family]+5:(.56,-.42,.77+lift,100),
            n-10:(.55,-.35,.96+lift,42),
            n:(grip.x,grip.y,grip.z,0)})
        target = Vector((x,y,z))
    elif family == 'guardian':
        dy, dz, angle = key_sample(frame, {
            1:(0,0,0), 8:(.04,.05,-7), 12:(.05,.06,-9), 18:(-.13,.085,12),
            23:(-.13,.080,14), 30:(-.045,.030,4), 41:(0,0,0)})
        target += Vector((0,dy,dz))
    elif family == 'ranger':
        dy, dz, angle = key_sample(frame, {
            1:(0,0,0), 8:(-.02,.055,-1), 13:(-.025,.068,-1.5),
            15:(.064,.076,-6), 18:(.052,.068,-4), 26:(-.012,.042,0), 41:(0,0,0)})
        target += Vector((0,dy,dz))
    else:
        dx, dy, dz, angle = key_sample(frame, {
            1:(0,0,0,0), 7:(.03,.045,.12,18), 10:(.025,.055,.18,28),
            19:(0,-.21,.18,-92), 24:(-.01,-.20,.13,-100),
            31:(.02,-.065,.10,-30), 41:(0,0,0,0)})
        target += Vector((dx,dy,dz))
    pole_weight = None
    if clip == 'attack' and family in ('warrior', 'cavalry', 'rogue'):
        # Keep the elbow plane through the strike. Switching it back according
        # to wrist height halfway through the downswing produces a fast roll.
        pole_weight = key_sample(frame, {1:(0,), 10:(1,), n-10:(1,), n:(0,)})[0]
    arm_ik(out, bones, side, chest, target, angle, twist, pole_weight)
    return out


def pose(family, clip, frame, bones):
    return _pose_authored(family, clip, 1+(frame-1)/2, bones)
