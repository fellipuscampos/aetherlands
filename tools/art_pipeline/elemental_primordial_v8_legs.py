    # The new reference's walking leg has a distinct down-up-down zigzag, then a hooked tip.
    hip=Vector((side*.80,.36,1.44));low=Vector((side*1.07,.48,.86))
    knee=Vector((side*1.38,.44,1.15));hock=Vector((side*1.55,.21,.36));tip=Vector((side*1.48,.055,0))
    coxa='leg_'+label;merus='shin_'+label;tibia='tibia_'+label;tarsus='tarsus_'+label
    centers.update({coxa:hip,merus:low,tibia:knee,tarsus:hock})
    parents.update({coxa:'body',merus:coxa,tibia:merus,tarsus:tibia})
    for part,a,b,widths,bone,kind in [
      ('Crab_Root',hip,low,((.25,.27),(.34,.36)),coxa,'stone'),
      ('Raised_Crab_Fold',low,knee,((.19,.22),(.23,.26)),merus,'dark'),
      ('Long_Bent_Crab_Tibia',hock,knee,((.11,.14),(.24,.28)),tibia,'dark')]:
        R=(b-a).to_track_quat('Z','Y').to_matrix();mid=(a+b)/2
        o=hexa(part+'_'+label,(0,0,0),widths[0],widths[1],(b-a).length+.035,bone,kind)
        for v in o.data.vertices:v.co=mid+R@v.co
        o['local_rotation']=list(R.to_euler('XYZ'));o.data.update()
        o['arthropod_part']='square-section hinged walking leg'
    # The final blade bends back toward the body and forward in depth, instead of a straight spike.
    R=(hock-tip).to_track_quat('Z','Y').to_matrix()
    vertices=[tip]+[hock+R@Vector((x*.066,y*.083,0)) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    o=mesh_part('Pointed_Crab_Tarsus_'+label,vertices,[(1,2,3,4),(0,2,1),(0,3,2),(0,4,3),(0,1,4)],tarsus,'dark',R)
    o['arthropod_part']='hooked pointed terminal blade'

