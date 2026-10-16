    # Follow the supplied claw: one long massive propodus, an elongated opening at the
    # lower end, and a smaller tapered dactyl tucked into the same shell.
    # This replaces the entire old forearm/cuff/hand assembly, rather than appending fingers.
    centers.pop(hand);parents.pop(hand)
    center=wrist.copy()
    fixed=[(-.16,.87),(.40,1.00),(.68,.92),(.70,.63),(.58,.10),(.38,-.30),
           (.14,-.43),(-.06,-.37),(-.17,-.20),(-.12,-.04),(-.04,-.10),(.01,-.22),
           (.13,-.29),(.22,-.24),(.31,.09),(.19,.32),(-.16,.39)]
    mobile=[(-.16,.42),(.05,.42),(.12,.29),(.12,.08),(.16,-.08),(.10,-.18),
            (.03,-.12),(-.04,.08),(-.13,.24),(-.21,.28)]
    claw='pincer_'+label
    centers[claw]=center+Vector((side*-.05,0,.38));parents[claw]=fore
    for part,profile,depth,bone,kind in [
      ('Fixed_Crab_Pincer',fixed,.50,fore,'stone'),
      ('Mobile_Crab_Pincer',mobile,.40,claw,'dark')]:
        o=prism(part+'_'+label,profile,depth,center,bone,kind)
        if side<0:
            for v in o.data.vertices:v.co.x=2*center.x-v.co.x
            bm=bmesh.new();bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
        o['arthropod_part']='large continuous propodus with hooked tip' if bone==fore else 'tapered hinged dactyl'
        o['reference']='User supplied close-up of massive claws with an elongated opening'

