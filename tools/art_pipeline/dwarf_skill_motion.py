"""New choreography for native dwarf joints, short limbs and equipment.

Only dwarf IK/math helpers are used. No foreign actions, channel values,
skeletons or retargeting. Each variant is solved on its own rest joints.
"""
import math
from mathutils import Vector, Matrix
from dwarf_animation_motion import (T, qx, qy, qz, around, arm_ik,
                                    leg_ik, foot_track, key_sample, smooth)


def curve(t, keys):
    return key_sample(t, keys)


def pulse(t, start, rise=.035, decay=.13):
    if t <= start: return 0.0
    if t <= start + rise: return smooth((t-start)/rise)
    return 1 - smooth((t-start-rise)/decay)


def pose(row, role, t, bones):
    out = dict(rotation={}, location={}, scale={}, world={})
    rot, loc = out['rotation'], out['location']
    family, tier = row['family'], row['tier']
    envelope = math.sin(math.pi*t)**2
    if family == 'siege':
        fire = .42 if role == 'demolition_ammo' else .55
        release = smooth((t-fire)/.055)
        recovery = smooth((t-.72)/.25)
        cock = smooth(t/(fire-.05)) * (1-release)
        if tier < 2:
            # The two throwing engines have their own mechanical range.
            sweep = (68 if tier == 0 else 59) if role == 'demolition_ammo' else (78 if tier == 0 else 67)
            angle = -28*cock + sweep*release*(1-recovery)
            rot['throwing_arm'] = qx(angle)
            rot['counterweight'] = qx(-angle)
            rot['sling'] = qx(12*cock-23*release*(1-recovery))
            # Loaded square stone vanishes at release and reappears on reload;
            # actual flying projectiles remain gameplay-owned.
            size = .001 if fire+.055 <= t < .94 else 1.0
            out['scale']['payload'] = (size, size, size)
        else:
            strength = .165 if role == 'demolition_ammo' else .205
            kick = pulse(t, fire, .035, .27)
            loc['recoil'] = (0, strength*kick, 0)
            loc['piston_L'] = (0, strength*kick*.55, 0)
            loc['piston_R'] = (0, strength*kick*.55, 0)
            loc['chassis'] = (0, 0, .009*kick)
        return out

    mount = family == 'cavalry'
    base = Matrix.Identity(4)
    shift = Vector(); pitch = yaw = roll = 0.0
    hand_side = 'L' if family == 'guardian' else 'R'
    grip = bones['hand_'+hand_side]['grip']
    target = grip.copy(); angle = twist = 0.0; pole = None
    free_upper = free_fore = free_wrist = 0.0
    if family == 'guardian':
        hold = role == 'shield_wall_hold'
        weight = 1.0 if hold else smooth(t/.85)
        breath = .002*math.sin(math.tau*t)**2 if hold else 0.0
        shift = Vector((0, -.024*weight, -.050*weight+breath))
        pitch = 7*weight
        target += Vector((.115*weight, -.100*weight, .165*weight))
        angle = -7*weight
        free_upper, free_fore = -14*weight, -9*weight
    elif family == 'warrior':
        if role == 'power_strike':
            crouch, pitch, yaw, dx, dy, dz, angle = curve(t, {
                0:(0,0,0,0,0,0,0), .24:(-.043,-7,-15,.055,.025,.19,-45),
                .42:(-.060,-9,-20,.055,.050,.28,-70),
                .54:(-.076,15,20,.020,-.165,.020,85),
                .63:(-.067,13,22,.010,-.140,-.025,95),
                .83:(-.024,3,6,.025,-.020,.080,28), 1:(0,0,0,0,0,0,0)})
        else:
            crouch, pitch, yaw, dx, dy, dz, angle, twist = curve(t, {
                0:(0,0,0,0,0,0,0,0), .26:(-.044,2,-28,.045,.020,.12,-18,-55),
                .43:(-.056,5,-20,.060,-.060,.12,25,-40),
                .57:(-.065,10,27,-.150,-.190,.08,60,55),
                .70:(-.049,7,30,-.135,-.100,.05,48,65),
                .86:(-.015,2,8,0,-.020,.02,10,10), 1:(0,0,0,0,0,0,0,0)})
        shift = Vector((0, -.027*envelope, crouch))
        target += Vector((dx,dy,dz))
        free_upper, free_fore = -20*envelope, -12*envelope
        pole = smooth(t/.22)*(1-smooth((t-.80)/.20))
    elif family == 'ranger':
        if role == 'precise_shot':
            aim = smooth(t/.25)*(1-smooth((t-.69)/.31))
            shot = pulse(t,.52,.025,.12)
            pitch = 3.5*aim-3*shot
            shift = Vector((0,.015*shot,-.021*envelope))
            target += Vector((0,-.035*aim+.055*shot,.075*aim))
            angle = -2*aim-5*shot
        else:
            aim = smooth(t/.20)*(1-smooth((t-.76)/.24))
            shots = sum(pulse(t,fire,.022,.095) for fire in (.32,.48,.64))
            pitch = 4*aim-4*shots
            yaw = 4*aim*math.sin(math.pi*t)
            shift = Vector((0,.018*shots,-.025*envelope))
            target += Vector((0,-.03*aim+.062*shots,.090*aim))
            angle = -3*aim-6*shots
        free_upper, free_fore = -12*envelope, -28*envelope
        free_wrist = 6*envelope
    elif family == 'rogue':
        if role == 'sneak_attack':
            crouch, pitch, yaw, dx, dy, dz, angle = curve(t, {
                0:(0,0,0,0,0,0,0), .22:(-.080,9,-18,.025,.030,.035,25),
                .38:(-.094,12,-22,.035,.025,.085,40),
                .49:(-.087,16,17,-.010,-.180,.070,-85),
                .60:(-.070,13,20,-.025,-.165,.045,-95),
                .78:(-.045,5,8,.010,-.025,.030,-25), 1:(0,0,0,0,0,0,0)})
            target += Vector((dx,dy,dz)); shift = Vector((0,-.040*envelope,crouch))
            pole = smooth(t/.20)*(1-smooth((t-.80)/.20))
        else:
            first = pulse(t,.36,.04,.15); second = pulse(t,.63,.04,.17)
            prep = smooth(t/.18)*(1-smooth((t-.81)/.19))
            pitch = 6*prep+9*(first+second); yaw = -12*prep+20*first-10*second
            shift = Vector((0,-.028*prep,-.060*envelope))
            target += Vector((.025*prep,-.160*(first+second),.100*prep-.095*second))
            angle = 15*prep-85*first+72*second; twist = 18*second
            pole = prep
        free_upper, free_fore = -20*envelope, -14*envelope
        if tier == 3:
            # The long legendary coat needs more clearance than the lighter
            # rogues. Keep the forward stab while reducing the deep crouch.
            shift.z *= .62
    elif mount:
        if role == 'charge':
            weight = smooth(t/.22)*(1-smooth((t-.76)/.24))
            kick = pulse(t,.48,.045,.23)
            body_offset = Vector((0,0,-.040*weight))
            body_pitch = 4*weight
            rot['mount_neck'] = qx(9*weight)
            rot['mount_head'] = qx(12*weight)
            pitch, yaw = 8*weight+5*kick, -8*weight+20*kick
            target += Vector((.035*weight,-.150*kick,.220*weight-.225*kick))
            angle = -55*weight+135*kick
            pole = weight
            shift.z = -.018*weight
        else:
            weight = math.sin(math.pi*t)**2
            body_offset = Vector((0,0,-.075*weight))
            body_pitch = -2.5*weight
            rot['mount_neck'] = qx(-4*weight)@qz(10*weight)
            rot['mount_head'] = qz(-6*weight)
            pitch, yaw = -4*weight, -9*weight
            target += Vector((0,.025*weight,.100*weight)); angle = -12*weight
            shift.z = -.015*weight
        loc['mount_body'] = body_offset; rot['mount_body'] = qx(body_pitch)
        base = T(body_offset)@around(bones['mount_body']['head'],rot['mount_body'])
        for leg in ('L_front','R_front','L_hind','R_hind'):
            ankle = bones['mount_hoof_'+leg]['head']; destination = ankle.copy()
            if role == 'tactical_retreat':
                phase = t*2+(0 if leg in ('L_front','R_hind') else .5)
                destination = ankle.lerp(foot_track(phase,ankle,-.26,.070,.62),weight)
            leg_ik(out,bones,leg,base,destination,True)
        free_upper, free_fore = -9*envelope, 14*envelope

    loc['pelvis'] = shift
    rot['pelvis'] = qz(yaw*.20)@qy(roll)
    rot['chest'] = qx(pitch)@qz(yaw*.80)
    rot['head'] = qx(-pitch*.65)@qz(-yaw*.70)
    hips = base@T(shift)@around(bones['pelvis']['head'],rot['pelvis'])
    chest = hips@around(bones['chest']['head'],rot['chest'])
    if not mount:
        for side in ('L','R'):
            leg_ik(out,bones,side,hips,bones['foot_'+side]['head'].copy())
    free = 'R' if family == 'guardian' else 'L'
    rot['upper_arm_'+free] = qx(free_upper)
    rot['forearm_'+free] = qx(free_fore-(0 if mount else 18))
    rot['hand_'+free] = qx(free_wrist)
    arm_ik(out,bones,hand_side,chest,target,angle,twist,pole)
    return out
