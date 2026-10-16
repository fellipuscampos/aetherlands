# A single suspended trunk tapers into a cluster of unequal roots, with no hips, knees or feet.
prism('Suspended_Trunk_Taper',[(-.38,1.20),(.36,1.20),(.36,1.04),(.27,1.04),(.27,.89),
 (.16,.89),(.16,.74),(-.13,.74),(-.13,.86),(-.25,.86),(-.25,1.01),(-.38,1.01)],.44,(0,.06,0),'body','bark')
root_specs=[
 ('center',[(.025,-.055,1.03),(-.015,-.055,.77),(.045,-.02,.48)],.155,.165,'wood'),
 ('left',[(-.27,.025,1.16),(-.39,.02,.90),(-.27,-.035,.67)],.14,.145,'bark'),
 ('right',[(.28,.10,1.17),(.39,.115,.97),(.30,.055,.77)],.15,.15,'wood'),
 ('rear',[(-.10,.285,1.14),(-.16,.30,.88),(-.07,.26,.61)],.115,.13,'bark_dark'),
 ('inner',[(.13,.225,1.01),(.16,.22,.78),(.115,.19,.54)],.082,.095,'vine')]
for label,points,width,depth,kind in root_specs:
    bone='floating_root_'+label
    centers[bone]=Vector(points[0]); parents[bone]='body'
    # Broad at the trunk, stepped and narrower at each hanging end. No boot-like blocks.
    for i in range(len(points)-1):
        a,b=Vector(points[i]),Vector(points[i+1]); length=(b-a).length
        R=(b-a).to_track_quat('Z','Y').to_matrix(); w=width*(1-.27*i)
        profile=[(-w/2,0),(w/2,0),(w/2,length*.43),(w*.31,length*.43),
          (w*.31,length*.78),(w*.14,length*.78),(w*.14,length),
          (-w*.14,length),(-w*.14,length*.78),(-w*.31,length*.78),(-w*.31,length*.43),(-w/2,length*.43)]
        prism('Suspended_'+label+'_Root_'+str(i),profile,depth*(1-.20*i),a,bone,kind,R)
root_path('Lower_Living_Root_L',[(-.11,-.12,1.24),(-.16,-.16,1.03),(-.12,-.16,.75)],.075,.09,'hanging_root_L','vine')
root_path('Lower_Living_Root_R',[(.13,.04,1.23),(.11,-.02,.97),(.16,-.02,.66)],.065,.08,'hanging_root_R','vine')
