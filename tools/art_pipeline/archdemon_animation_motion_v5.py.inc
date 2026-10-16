rig.animation_data_create()
restq={b.name:b.matrix_local.to_quaternion() for b in rig.data.bones}
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
identity=Quaternion((1,0,0,0)); axis=Vector((.18,.22,1)).normalized()
def ease(x):
    x=max(0,min(1,x)); return x*x*(3-2*x)
def pulse(t,start,rise,hold,end):
    if t<start or t>=end: return 0.
    if t<rise: return ease((t-start)/(rise-start))
    if t<=hold: return 1.
    return 1-ease((t-hold)/(end-hold))
def pose(name,shift=(0,0,0),rotation=None):
    b=rig.pose.bones[name]; q=restq[name]
    b.location=q.inverted()@Vector(shift)
    b.rotation_quaternion=q.inverted()@(rotation or identity)@q
    b.scale=(1,1,1)
def rot(x=0,y=0,z=0): return Euler(tuple(math.radians(a) for a in (x,y,z))).to_quaternion()
def centroid(o): return sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
# Derive the anatomical hand frame from the actual cuff, palm and front face, rather than arbitrary Euler twists.
offering={}; hand_directions={}
for side,sign in [('L',-1),('R',1)]:
    objs={o.name.rsplit('_Gauntlet_',1)[-1]:o for o in parts if o['rig_bone']=='fist_'+side}
    down=(centroid(objs['Palm'])-centroid(objs['Cuff'])).normalized()
    facing=centroid(objs['Front'])-centroid(objs['Shell']); facing-=down*down.dot(facing); facing.normalize()
    across=down.cross(facing).normalized()
    reach=Vector((-sign*.10,-1,.12)).normalized()
    palm=Vector((0,0,1)); palm-=reach*reach.dot(palm); palm.normalize()
    source=Matrix((down,facing,across)).transposed()
    target=Matrix((reach,palm,reach.cross(palm))).transposed()
    offering[side]=(target@source.inverted()).to_quaternion()
    hand_directions[side]=(down,facing)
def cloth_angle(clip,t,duration,band,side,i,hit,charge):
    if i==0: return (0,0,0)
    sign=-1 if side=='L' else 1
    lag=.73*i+(.42 if side=='R' else 0)+(.35 if band=='side' else 0)
    gain=(.48,.78,1.)[i-1]
    idle_wave=math.sin(math.tau*t/4-lag)
    base_wave=math.sin(-lag)
    if clip=='Idle': wave=idle_wave; amplitude=6.; trail=0.
    elif clip=='Walk': wave=math.sin(math.tau*t/2-lag); amplitude=7.; trail=3.8
    else:
        envelope=math.sin(math.pi*t/duration)**2
        wave=base_wave+envelope*(math.sin(math.tau*t/1.6-lag)-base_wave)
        amplitude=6.+(3.*charge if clip=='Spell' else 3.*hit)
        trail=3.0*charge+4.*hit
    if band=='front': return ((amplitude*wave+trail)*gain,0,0)
    # Side strips flutter normal to their side surface; the first fold remains fixed to the armor.
    outward=(amplitude*(1+wave)+trail)*gain
    return (trail*.30*gain,-sign*outward,0)
def frame_pose(clip,t,duration):
    for b in rig.pose.bones:
        b.location=(0,0,0); b.rotation_quaternion=identity; b.scale=(1,1,1)
    p=math.tau*t/duration; wave=math.sin(math.tau*t/4)
    wind=hit=charge=cast=0.
    if clip=='Idle':
        pose('body',(0,0,.022*(1-math.cos(math.tau*t/4))),rot(.55*math.sin(math.tau*t/8)))
    elif clip=='Walk':
        wave=math.sin(math.tau*t/2)
        pose('body',(0,0,.10+.012*(1-math.cos(math.tau*t/2))),rot(4.5+.6*wave))
    elif clip=='Attack':
        wind=pulse(t,0,.32,.40,.65); hit=pulse(t,.44,.625,.70,1.22)
        pose('body',(0,.028*wind-.07*hit,.04*wind+.12*hit),rot(-2*wind+4*hit))
        p=math.tau*ease(t/duration); wave=0.
    else:
        charge=pulse(t,0,.76,1.80,2.82); cast=pulse(t,1.03,1.375,1.50,2.15)
        pose('body',(0,0,.10*charge),rot(-.6*charge))
        p=2*math.tau*ease(t/duration); wave=0.
    pose('core',rotation=Quaternion(axis,p))
    for side,sign in [('L',-1),('R',1)]:
        if clip=='Idle':
            sshift=(sign*.005*(1-math.cos(math.tau*t/6)),0,.012*wave)
            fshift=(sign*.008*(1-math.cos(math.tau*t/6)),0,.010*wave)
            sr=rot(0,sign*.65*wave,0); fr=rot(.7*wave,0,sign*.8*wave)
        elif clip=='Walk':
            sshift=(sign*.018,.018,.012*wave); fshift=(sign*.025,.075,.010*wave)
            sr=rot(1,sign*1.1,0); fr=rot(-2+.7*wave,0,sign*1.0)
        elif clip=='Attack':
            sshift=(sign*(.026*wind+.022*hit),.035*wind-.035*hit,.045*hit)
            fshift=(sign*(.07*wind+.045*hit),.10*wind-.33*hit,.075*wind+.19*hit)
            sr=rot(-2*wind+3*hit,sign*2*wind,0); fr=rot(-5*wind+11*hit,0,-sign*2*wind)
        else:
            # Both hands move along the same forward lifting arc. Cuffs stay behind the palms.
            sshift=(sign*.025*charge,-.025*charge,.032*charge)
            forward=pulse(t,0,.42,1.80,2.94)
            fshift=(-sign*.035*charge,-.60*forward-.10*cast,.45*charge+.035*cast)
            sr=rot(0,sign*.8*charge,0); fr=identity.slerp(offering[side],charge)
        pose('shoulder_'+side,sshift,sr); pose('fist_'+side,fshift,fr)
        for band in ('front','side'):
            for i in range(4): pose('stole_'+band+'_'+side+'_'+str(i),rotation=rot(*cloth_angle(clip,t,duration,band,side,i,hit,charge)))
    for n in ('mantle_upper_l','mantle_upper_r','mantle_lower_l','mantle_lower_r'):
        sign=-1 if n.endswith('_l') else 1
        flutter=wave*.008 if clip in ('Idle','Walk') else 0
        pose(n,(sign*.012*charge,.012*charge,.022*charge+flutter),rot(0,0,sign*(.55*wave+1.5*charge)))
specs={'Idle':(24.,True,'Flutuação e ondulação das faixas, com atraso entre as dobras.'),
       'Walk':(8.,True,'Deslizamento no lugar; faixas seguindo o fluxo e ondulando.'),
       'Attack':(1.5,False,'Golpe frontal e balanço das faixas na preparação e recuperação.'),
       'Spell':(3.,False,'Mãos à frente, palmas para cima, liberação e retorno; faixas em movimento.')}

