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
def pose(name,shift=(0,0,0),rotation=None,scale=1.):
    b=rig.pose.bones[name]; q=restq[name]
    b.location=q.inverted()@Vector(shift)
    b.rotation_quaternion=q.inverted()@(rotation or identity)@q
    b.scale=(scale,)*3
def rot(x=0,y=0,z=0): return Euler(tuple(math.radians(a) for a in (x,y,z))).to_quaternion()
def frame_pose(clip,t,duration):
    for b in rig.pose.bones:
        b.location=(0,0,0); b.rotation_quaternion=identity; b.scale=(1,1,1)
    p=math.tau*t/duration; wave=math.sin(math.tau*t/4)
    wind=hit=charge=0.
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
        charge=pulse(t,0,.70,1.85,2.82)
        pose('body',(0,0,.15*charge),rot(-1.5*charge))
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
            sshift=(sign*.045*charge,0,.075*charge)
            fshift=(sign*.19*charge,-.12*charge,.24*charge)
            sr=rot(0,sign*3*charge); fr=rot(0,-sign*6*charge,0)
        pose('shoulder_'+side,sshift,sr); pose('fist_'+side,fshift,fr)
        for band in ('front','side'):
            for i in range(4):
                sway=.42*wave*(i/3)
                trail=(.65+.35*wave) if clip=='Walk' else .7*hit+1.1*charge
                # The attachment segment is rigid at the body; distal folds sway without twisting.
                angle=(sway+trail)*(i/3)
                pose('stole_'+band+'_'+side+'_'+str(i),rotation=rot(angle,0,0))
    for i,n in enumerate(('mantle_upper_l','mantle_upper_r','mantle_lower_l','mantle_lower_r')):
        sign=-1 if n.endswith('_l') else 1
        flutter=wave*.008 if clip in ('Idle','Walk') else 0
        pose(n,(sign*.012*charge,.012*charge,.022*charge+flutter),rot(0,0,sign*(.55*wave+1.5*charge)))
specs={'Idle':(24.,True,'Flutuação contida; ombros e mãos suspensos; giro lento do cubo vermelho.'),
       'Walk':(8.,True,'Deslizamento no lugar, inclinação suave e faixas acompanhando o movimento.'),
       'Attack':(1.5,False,'Preparação e golpe frontal com as duas mãos flutuantes.'),
       'Spell':(3.,False,'Mãos afastadas em conjuração; elevação da entidade e giro acelerado do núcleo.')}

