# Every new limb piece is an actual eight-vertex cuboid: no silhouette extrusion,
# curved outline, tapered loft, pyramid, bevel or rounded surface.
def block(label,center,size,bone,kind='stone',R=None):
    o=box(label,center,size,bone,kind,R);o['construction']='cuboid';return o

def block_link(label,a,b,width,depth,bone,kind='stone'):
    o=beam(label,a,b,width,depth,bone,kind);o['construction']='cuboid';return o

# Long lateral roots support three independently articulated walking legs on each side.
for side,label in [(-1,'L'),(1,'R')]:
    block('Crab_Leg_Socket_Rail_'+label,(side*.76,.49,1.22),(.32,1.66,.36),'body','dark')

for side,label in [(-1,'L'),(1,'R')]:
    shoulder=Vector((side*.94,-.14,2.23));elbow=Vector((side*.91,-.51,1.38))
    upper='arm_'+label;fore='forearm_'+label;claw='pincer_'+label
    centers.update({upper:shoulder,fore:elbow});parents.update({upper:'body',fore:upper})
    # Retain the approved upper-arm attachment; all lower anatomy is rebuilt from blocks.
    beam('Upper_Arm_'+label,shoulder,elbow,.44,.52,upper,'dark')
    slab('Upper_Arm_Rock_'+label,(shoulder+elbow)/2,(.54,.59,.88),upper,'stone',(-21,side*-2,0))

    palm=Vector((side*.95,-.78,1.05))
    block('Massive_Cuboid_Chela_'+label,palm,(.78,.74,.70),fore,'stone')
    # The fixed jaw descends from the outside of the palm, with an angular inward bite.
    fixed_root=Vector((side*1.21,-.80,.78));fixed_bend=Vector((side*1.16,-.86,.43))
    fixed_tip=Vector((side*1.08,-.89,.27))
    block_link('Fixed_Pincer_Main_Block_'+label,fixed_root,fixed_bend,.29,.55,fore,'stone')
    block_link('Fixed_Pincer_Bite_Block_'+label,fixed_bend,fixed_tip,.20,.43,fore,'dark')
    # A separate bulky moving jaw opposes it. The open space is between these two real volumes.
    moving_root=Vector((side*.66,-.78,.76));moving_bend=Vector((side*.71,-.85,.42))
    moving_tip=Vector((side*.80,-.89,.27))
    centers[claw]=moving_root;parents[claw]=fore
    block_link('Moving_Pincer_Main_Block_'+label,moving_root,moving_bend,.26,.51,claw,'stone')
    block_link('Moving_Pincer_Bite_Block_'+label,moving_bend,moving_tip,.18,.40,claw,'dark')

    # Six walking legs form a front/middle/rear support footprint, not a pair of human thighs.
    for row,root_y,hinge_y,knee_y,tip_y,hinge_x,knee_x,tip_x in [
      ('front',-.12,-.30,-.58,-.86,1.13,1.40,1.63),
      ('middle',.49,.60,.67,.74,1.24,1.63,1.99),
      ('rear',1.04,1.31,1.56,1.80,1.14,1.43,1.72)]:
        tag=row+'_'+label
        hip=Vector((side*.79,root_y,1.39));hinge=Vector((side*hinge_x,hinge_y,1.48))
        knee=Vector((side*knee_x,knee_y,.73));contact=Vector((side*tip_x,tip_y,.08))
        terminal_root=contact+Vector((0,0,.07));mid=(knee+terminal_root)/2
        coxa='coxa_'+tag;merus='merus_'+tag;tibia='tibia_'+tag
        centers.update({coxa:hip,merus:hinge,tibia:knee})
        parents.update({coxa:'body',merus:coxa,tibia:merus})
        block_link('Crab_Coxa_Block_'+tag,hip,hinge,.34,.38,coxa,'dark')
        block('Crab_High_Joint_Block_'+tag,hinge,(.42,.43,.39),merus,'stone')
        block_link('Crab_Merus_Block_'+tag,hinge,knee,.36,.40,merus,'stone')
        block_link('Crab_Tibia_Upper_Block_'+tag,knee,mid,.29,.32,tibia,'dark')
        block_link('Crab_Tibia_Lower_Block_'+tag,mid,terminal_root,.19,.22,tibia,'dark')
        # Narrow squared end. No broad sole, toes or custom needle-shaped mesh.
        o=block('Crab_Contact_Tip_Block_'+tag,contact,(.12,.15,.16),tibia,'dark')
        o['walking_leg']=tag;o['ground_contact_source']=list(contact-Vector((0,0,.08)))

