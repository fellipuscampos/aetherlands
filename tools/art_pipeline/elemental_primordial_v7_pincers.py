    # True crab chelae: a broad fixed palm/outer hook and an opposing articulated dactyl.
    # Both have square cross sections and a real opening visible through the geometry.
    fixed=[(-.22,.10),(.26,.10),(.26,-.03),(.38,-.03),(.38,-.27),(.27,-.27),
           (.27,-.41),(.08,-.41),(.08,-.34),(.03,-.34),(.03,-.23),(.17,-.23),
           (.17,-.12),(-.22,-.12)]
    mobile=[(-.36,.09),(-.16,.09),(-.16,-.03),(-.27,-.03),(-.27,-.10),(-.34,-.10),
            (-.34,-.22),(-.22,-.22),(-.22,-.29),(-.32,-.29),(-.32,-.35),(-.44,-.35),
            (-.44,-.18),(-.49,-.18),(-.49,-.03),(-.36,-.03)]
    center=wrist+Vector((0,-.035,0))
    claw='pincer_'+label
    centers[claw]=center+Vector((side*-.20,0,.025));parents[claw]=hand
    for part,profile,depth,bone in [('Fixed_Crab_Pincer',fixed,.45,hand),('Mobile_Crab_Pincer',mobile,.41,claw)]:
        o=prism(part+'_'+label,profile,depth,center,bone,'dark')
        if side<0:
            for v in o.data.vertices:v.co.x=2*center.x-v.co.x
            bm=bmesh.new();bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
        o['arthropod_part']='fixed propodus' if bone==hand else 'articulated opposing dactyl'
        o['pincer_open_gap_source_m']=.25

