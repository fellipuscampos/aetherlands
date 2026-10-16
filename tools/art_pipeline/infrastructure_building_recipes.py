"""Twenty distinct layouts for one infrastructure building per branch and race."""

def human_market():
    hall('Stone_Trading_Hall',-.10,.32,.74,.43,.48,True)
    for i,x in enumerate((-.33,.14)):
        table('Trading_Counter_'+str(i),x,.067,.28,.15,.315)
        trade_goods('Market_Stock_'+str(i),x,.059,.341,'produce' if i else 'grain')
    # A separate stone-supported stall makes the market a trading square.
    for x in (.36,.63): support('Side_Stall_'+str(x),x,-.22,.076,.43,inward=-1)
    beam('Blue_Side_Stall_Cross_Lintel',(.34,-.22,.437),(.65,-.22,.437),.034,'cutstone','06_STRUCTURE')
    roof('Blue_Side_Stall',.49,-.22,.40,.30,.45,4)
    table('Side_Counter',.49,-.24,.31,.17,.27)
    trade_goods('Side_Produce',.49,-.24,.30)
    barrel('Wine',-.44,-.20); crate('Grain_Crate',-.24,-.30)
    table('Weighing_Table',.02,-.41,.24,.16,.255)
    beam('Scale_Stem',(.02,-.41,.271),(.02,-.41,.43),.016,'iron_light','08_DETAILS')
    beam('Scale_Arms',(-.068,-.41,.418),(.108,-.41,.418),.012,'iron_light','08_DETAILS')
    for x in (-.065,.105):
        beam('Scale_Hanger_'+str(x),(x,-.41,.418),(x,-.41,.347),.007,'iron_light','08_DETAILS')
        box('Scale_Pan_'+str(x),(x,-.41,.339),(.068,.048,.012),'gold','08_DETAILS')

def elf_market():
    hall('Leaf_Trading_Pavilion',.12,.30,.67,.39,.49,True,True)
    tree('Market_Orchard',-.46,.23,.86,.13)
    table('Fruit_Counter',.12,.047,.47,.16,.31)
    trade_goods('Fresh_Fruit',-.015,.047,.34)
    trade_goods('Fresh_Herbs',.245,.047,.34,'grain')
    # Small side kiosks with slender supports and raised leaf roofs.
    for i,(x,y) in enumerate(((-.36,-.32),(.35,-.35))):
        for sx in (-1,1): support('Leaf_Kiosk_%s_%s'%(i,sx),x+sx*.12,y,.076,.34,inward=-sx)
        beam('Leaf_Kiosk_'+str(i)+'_Cross_Lintel',(x-.14,y,.347),(x+.14,y,.347),.030,'timber','06_STRUCTURE')
        roof('Leaf_Kiosk_'+str(i),x,y,.31,.24,.36,4,True)
        table('Kiosk_Counter_'+str(i),x,y-.04,.25,.12,.23)
        trade_goods('Kiosk_Goods_'+str(i),x,y-.04,.26)
    crate('Leaf_Supply',-.07,-.48,size=.10)
    for i,(x,y) in enumerate(((-.58,-.12),(.57,.14))):
        box('Market_Planter_'+str(i),(x,y,.13),(.12,.13,.10),'cutstone','05_COURTYARD')
        box('Market_Shrub_'+str(i),(x,y,.20),(.11,.12,.05),'foliage','08_DETAILS')

def dwarf_market():
    hall('Granite_Exchange',0,.30,.94,.40,.42,True)
    table('Exchange_Counter',0,.055,.76,.18,.31)
    for i,x in enumerate((-.25,0,.25)):
        trade_goods('Trade_Bin_'+str(i),x,.050,.34,'grain' if i%2==0 else 'produce')
    for i,x in enumerate((-.43,.43)):
        box('Stone_Storage_'+str(i),(x,-.23,.19),(.21,.19,.22),'stone','05_COURTYARD')
        box('Copper_Storage_Lid_'+str(i),(x,-.23,.31),(.22,.20,.024),'bronze','08_DETAILS')
        barrel('Ale_'+str(i),x,-.48,r=.067,h=.17)
    box('Exchange_Scale_Base',(0,-.38,.12),(.18,.15,.085),'cutstone','04_FOCUS')
    support('Exchange_Scale_Post',0,-.38,.16,.43,.045)
    beam('Exchange_Scale_Arm',(-.12,-.38,.44),(.12,-.38,.44),.019,'bronze','04_FOCUS')
    for sign in (-1,1):
        beam('Scale_Link_'+str(sign),(sign*.11,-.38,.44),(sign*.11,-.38,.33),.010,'iron','04_FOCUS')
        box('Heavy_Scale_Pan_'+str(sign),(sign*.11,-.38,.32),(.10,.085,.018),'bronze','04_FOCUS')

def orc_market():
    # A split market, rather than the single hall used by the other civilizations.
    for i,(x,y,w,d) in enumerate(((-.33,.22,.39,.42),(.33,.12,.39,.52))):
        hall('Clan_Trading_Stall_'+str(i),x,y,w,d,.47,True)
        table('Clan_Counter_'+str(i),x,y-d/2-.005,.32,.16,.30)
        trade_goods('Clan_Stock_'+str(i),x,y-d/2-.005,.33,'grain' if i else 'produce')
    barrel('Clan_Ale',-.41,-.37,r=.075,h=.18)
    crate('Trade_Chest',.33,-.41,size=.18)
    box('Trade_Marker_Foot',(0,.19,.13),(.16,.15,.10),'stone','04_FOCUS')
    support('Trade_Totem',0,.19,.16,.74,.09)
    box('Trade_Price_Tablet',(0,.13,.57),(.16,.029,.16),'iron','08_DETAILS')
    for i in range(3): box('Trade_Mark_'+str(i),(0,.110,.53+i*.036),(.088,.011,.009),'bone','08_DETAILS')
    table('Barter_Table',-.03,-.41,.26,.16,.24)
    box('Barter_Metal',(-.03,-.41,.28),(.16,.08,.04),'iron_light','08_DETAILS')

def human_farm():
    hall('Stone_Farmhouse',-.30,.31,.43,.36,.40,False)
    portal('Farm_Door',-.30,.13,.13,.16,.26)
    window('Farm_Window',-.44,.13,.37,.07,.12)
    polygon_prism('Grain_Silo_Base',hexagon(.17,(.36,.34)),.076,.15,'cutstone','02_HALL')
    polygon_prism('Stone_Grain_Silo',hexagon(.145,(.36,.34)),.15,.66,'stone','02_HALL')
    for i in range(4): polygon_prism('Silo_Blue_Cap_'+str(i),hexagon(.18-i*.041,(.36,.34)),.66+i*.042,.702+i*.042,'roof','03_ROOFS')
    box('Silo_Delivery_Hatch',(.36,.208,.30),(.10,.026,.15),'door','08_DETAILS')
    crop_bed('Wheat_Field',-.18,-.32,.71,.36,4,True)
    crop_bed('Vegetable_Field',.46,-.27,.21,.25,3,False)
    box('Water_Trough',(.37,.03,.13),(.26,.10,.10),'cutstone','05_COURTYARD')
    box('Trough_Water',(.37,.03,.186),(.22,.067,.014),'water','08_DETAILS')
    crate('Harvest_Box',-.53,.01,size=.13); barrel('Farm_Barrel',.15,.14,r=.06,h=.15)

def elf_farm():
    tree('Fruit_Tree_A',-.43,.30,.89,.14)
    tree('Fruit_Tree_B',-.48,-.07,.67,.12)
    for i,(x,y,z) in enumerate(((-.50,.19,.73),(-.33,.30,.84),(-.56,-.14,.55),(-.43,-.10,.64))):
        box('Orchard_Fruit_'+str(i),(x,y,z),(.045,.043,.046),'fruit','08_DETAILS')
    hall('Leaf_Garden_Pavilion',.28,.29,.43,.36,.40,True,True)
    table('Seed_Workbench',.28,.09,.30,.13,.255)
    trade_goods('Seed_Trays',.28,.09,.284,'grain')
    crop_bed('Raised_Garden_A',-.14,-.32,.35,.23,3,False,True)
    crop_bed('Raised_Garden_B',.34,-.32,.28,.23,3,False,True)
    basin('Irrigation_Well',-.08,.18,.10,.10,water='water')
    beam('Garden_Irrigation',(-.08,.08,.12),(-.08,-.15,.12),.026,'cutstone','05_COURTYARD')
    crate('Harvest_Basket',.56,.03,size=.10)

def dwarf_farm():
    hall('Granite_Granary',-.22,.35,.66,.30,.34,False)
    portal('Granary_Door',-.22,.20,.12,.18,.24)
    # Stone terraces, copper cistern and mechanical irrigation.
    for i,(x,y,w) in enumerate(((-.30,-.40,.40),(-.25,-.16,.50),(.25,-.35,.33))):
        crop_bed('Stone_Terrace_'+str(i),x,y,w,.15,2,i!=2,True)
    polygon_prism('Cistern_Granite',hexagon(.13,(.43,.29)),.076,.40,'stone','04_FOCUS')
    polygon_prism('Cistern_Copper_Lid',hexagon(.145,(.43,.29)),.40,.432,'bronze','04_FOCUS')
    support('Pump_Post',.48,.01,.076,.36,.065)
    gear('Pump_Wheel',.48,-.049,.31,.10)
    beam('Pump_Axle',(.48,-.082,.31),(.48,.046,.31),.023,'iron','04_FOCUS')
    beam('Copper_Water_Line',(.43,.29,.25),(.43,.01,.25),.031,'bronze','04_FOCUS')
    beam('Copper_Outlet',(.43,.01,.25),(.26,-.07,.17),.031,'bronze','04_FOCUS')
    for i in range(4):
        box('Mushroom_Stem_'+str(i),(.19+i*.058,-.29,.17),(.024,.025,.10),'paper','08_DETAILS')
        box('Mushroom_Cap_'+str(i),(.19+i*.058,-.29,.231),(.053,.046,.030),'grain','08_DETAILS')
    barrel('Granary_Barrel',-.55,.08,r=.06,h=.15)

def orc_farm():
    hall('Clan_Granary',.24,.32,.61,.36,.38,False)
    portal('Granary_Hatch',.24,.14,.13,.19,.25,recess_setback=.010)
    for z in (.30,.46): box('Granary_Iron_Strapping_'+str(z),(.24,.127,z),(.58,.025,.027),'iron','08_DETAILS')
    crop_bed('Clan_Grain_Field',-.15,-.30,.69,.39,4,True)
    crop_bed('Clan_Root_Patch',.47,-.29,.22,.26,3)
    polygon_prism('Stone_Well',hexagon(.12,(-.48,.26)),.076,.23,'stone','04_FOCUS')
    polygon_prism('Well_Water',hexagon(.088,(-.48,.26)),.231,.243,'water','04_FOCUS')
    for x in (-.62,-.34): support('Well_Post_'+str(x),x,.26,.076,.48,.055,inward=1 if x<-.48 else -1)
    beam('Well_Winch',(-.64,.26,.48),(-.32,.26,.48),.039,'timber','04_FOCUS')
    beam('Well_Rope',(-.48,.26,.47),(-.48,.26,.25),.009,'straw','08_DETAILS')
    barrel('Clan_Harvest',-.52,-.04,r=.07,h=.18)
    crate('Seed_Chest',.05,.08,size=.12)

def human_workshop():
    hall('Stone_Workshop',-.10,.29,.76,.42,.48,True)
    forge('Masonry_Forge',-.26,.26,.31,.23,.42)
    box('Forge_Chimney',(-.26,.34,.73),(.14,.14,.58),'stone','04_FOCUS')
    box('Chimney_Crown',(-.26,.34,1.025),(.18,.18,.05),'cutstone','04_FOCUS')
    anvil('Village_Anvil',-.17,-.24)
    table('Carpenters_Bench',.38,-.19,.31,.17,.32)
    beam('Bench_Saw',(.25,-.19,.36),(.47,-.19,.36),.022,'iron_light','08_DETAILS')
    box('Saw_Handle',(.48,-.19,.36),(.057,.035,.045),'door','08_DETAILS')
    for i in range(3): box('Lumber_Stock_'+str(i),(.27,-.44,.107+i*.036),(.43,.083,.033),'timber','08_DETAILS')
    barrel('Workshop_Quench',-.45,-.44,r=.065,h=.16)
    gear('Finished_Wheel',.47,.20,.28,.11)
    box('Finished_Wheel_Rack_Foot',(.47,.235,.091),(.17,.12,.030),'timber','08_DETAILS')
    box('Finished_Wheel_Rack_Post',(.47,.235,.173),(.043,.065,.194),'timber','08_DETAILS')
    beam('Finished_Wheel_Axle',(.47,.18,.28),(.47,.28,.28),.026,'iron','08_DETAILS')

def elf_workshop():
    hall('Artisans_Leaf_Pavilion',.11,.30,.76,.40,.45,True,False)
    tree('Workshop_Living_Post',-.48,.26,.84,.12)
    table('Woodworker_Bench',-.12,.03,.37,.17,.31)
    box('Lathe_Stock',(-.12,.03,.40),(.26,.049,.058),'timber','08_DETAILS')
    for x in (-.26,.02): support('Lathe_Bearing_'+str(x),x,.03,.326,.421,.026)
    beam('Lathe_Axle',(-.27,.03,.40),(.03,.03,.40),.017,'iron','08_DETAILS')
    table('Jewellers_Bench',.37,-.32,.32,.18,.29)
    for i in range(3): box('Craft_Gold_Piece_'+str(i),(.27+i*.10,-.32,.323),(.057,.049,.025),'gold','08_DETAILS')
    beam('Jewellers_Hammer',(.28,-.38,.333),(.43,-.38,.333),.018,'timber','08_DETAILS')
    box('Jewellers_Hammer_Head',(.43,-.38,.341),(.025,.069,.026),'iron_light','08_DETAILS')
    for i in range(3): box('Pale_Lumber_'+str(i),(-.25,-.42,.103+i*.032),(.36,.072,.029),'door','08_DETAILS')
    crate('Craft_Supplies',.47,.02,size=.11)

def dwarf_workshop():
    hall('Granite_Foundry',-.10,.30,.90,.40,.46,True)
    forge('Great_Forge',-.22,.26,.43,.27,.47)
    for i,x in enumerate((-.34,-.10)):
        box('Forge_Flue_'+str(i),(x,.36,.71),(.14,.14,.59),'stone','04_FOCUS')
        box('Copper_Flue_Collar_'+str(i),(x,.36,.94),(.17,.17,.041),'bronze','08_DETAILS')
        box('Flue_Cap_'+str(i),(x,.36,1.03),(.18,.18,.045),'bronze','08_DETAILS')
    anvil('Foundry_Anvil',-.26,-.26)
    for x in (.28,.49): support('Press_Pier_'+str(x),x,-.22,.076,.52,.075)
    box('Press_Header',(.385,-.22,.52),(.31,.15,.066),'stone','04_FOCUS')
    box('Press_Ram',(.385,-.22,.36),(.07,.073,.28),'bronze','04_FOCUS')
    box('Press_Anvil',(.385,-.22,.20),(.24,.16,.07),'iron_light','04_FOCUS')
    gear('Press_Gear',.53,-.255,.42,.102)
    support('Press_Gear_Bearing',.53,-.185,.076,.46,.055,foot_height=.061)
    beam('Press_Gear_Axle',(.53,-.29,.42),(.53,-.16,.42),.030,'iron','04_FOCUS')
    box('Press_Foot',(.385,-.22,.112),(.32,.21,.072),'cutstone','04_FOCUS')
    for i in range(4): box('Iron_Ingot_'+str(i),(-.10+i*.075,-.49,.12),(.068,.10,.075),'iron_light','08_DETAILS')
    barrel('Quench_Cask',-.52,-.04,r=.07,h=.17)

def orc_workshop():
    hall('Braced_Smithy',-.26,.28,.50,.43,.49,True)
    forge('Stone_Firebox',.36,.29,.33,.27,.47)
    box('Iron_Flue',(.36,.35,.78),(.115,.12,.65),'iron','04_FOCUS')
    for z in (.56,.82,1.07): box('Flue_Band_'+str(z),(.36,.35,z),(.14,.154,.029),'iron_light','08_DETAILS')
    anvil('Clan_Anvil',-.17,-.28)
    table('Ironworker_Bench',.35,-.21,.32,.18,.31)
    beam('Heavy_Hammer_Handle',(.23,-.23,.35),(.42,-.23,.35),.027,'timber','08_DETAILS')
    box('Heavy_Hammer_Head',(.43,-.23,.375),(.051,.085,.057),'iron_light','08_DETAILS')
    box('Bellows_Body',(.36,.04,.23),(.20,.18,.17),'leather','04_FOCUS')
    for sign in (-1,1): box('Bellows_Board_'+str(sign),(.36,.04,.23+sign*.095),(.23,.21,.027),'timber','04_FOCUS')
    beam('Bellows_Nozzle',(.36,.11,.25),(.36,.175,.25),.045,'iron','04_FOCUS')
    for i in range(3): box('Timber_Supply_'+str(i),(.24,-.46,.106+i*.040),(.36,.085,.035),'timber','08_DETAILS')
    barrel('Oil_Cask',-.49,-.41,r=.068,h=.16)

def human_university():
    hall('Stone_Library',-.22,.28,.56,.40,.59,False)
    portal('Library_Portal',-.22,.08,.13,.20,.34)
    for x in (-.41,-.03): window('Library_Window_'+str(x),x,.08,.47,.07,.17)
    # A separate hexagonal scholar's tower, joined at the base.
    polygon_prism('College_Tower_Base',hexagon(.185,(.36,.29)),.076,.18,'cutstone','02_HALL')
    polygon_prism('College_Tower',hexagon(.165,(.36,.29)),.18,1.02,'stone','02_HALL')
    for i in range(5): polygon_prism('Tower_Blue_Roof_'+str(i),hexagon(.21-i*.038,(.36,.29)),1.02+i*.044,1.064+i*.044,'roof','03_ROOFS')
    window('Tower_Window',.36,.135,.68,.08,.22)
    table('Study_Desk',.04,-.28,.32,.19,.29)
    book('Open_Scholars_Book',.04,-.28,.318,.21,.14,True)
    bench('College_Bench',-.32,-.38,.29)
    shelf('College_Bookcase',.40,-.27,.23,.30)
    box('College_Entry_Step',(-.22,-.001,.102),(.31,.13,.054),'cutstone','05_COURTYARD')

def elf_university():
    tree('Learning_Tree',-.40,.25,1.10,.17)
    hall('Leaf_Library',.25,.31,.48,.39,.63,True,False)
    shelf('Library_Shelves',.25,.34,.34,.39,.12)
    for i,(x,y,w) in enumerate(((0,-.09,.37),(-.04,-.26,.44),(-.04,-.43,.48))):
        box('Lecture_Terrace_'+str(i),(x,y,.089+i*.015),(w,.13,.028+i*.030),'cutstone','05_COURTYARD')
    table('Teachers_Lectern',-.10,.05,.24,.17,.35)
    book('Open_Teachers_Book',-.10,.05,.378,.18,.13,True)
    bench('Students_Bench_A',-.34,-.42,.24)
    bench('Students_Bench_B',.36,-.36,.24)
    shelf('Scroll_Archive',.49,-.10,.17,.28,.10,True)
    box('Learning_Garden',(-.48,-.10,.12),(.18,.18,.06),'cutstone','05_COURTYARD')
    box('Garden_Shrub',(-.48,-.10,.175),(.16,.15,.05),'foliage','08_DETAILS')

def dwarf_university():
    hall('Granite_Archive',0,.30,.94,.41,.65,False)
    portal('Archive_Portal',0,.095,.13,.24,.37)
    for x in (-.32,.32):
        window('Archive_Window_'+str(x),x,.095,.49,.11,.17)
        box('Archive_Pier_Belt_'+str(x),(x,.060,.31),(.14,.029,.034),'bronze','08_DETAILS')
    shelf('Copper_Bound_Library',-.35,-.30,.23,.36)
    table('Engineering_Desk',.19,-.32,.35,.20,.30)
    book('Engineering_Manual',.15,-.32,.33,.20,.14,True)
    gear('Teaching_Gear',.39,-.32,.38,.065)
    box('Survey_Tablet_Foot',(-.05,-.53,.105),(.14,.12,.056),'cutstone','04_FOCUS')
    box('Survey_Tablet',(-.05,-.53,.25),(.17,.04,.25),'iron','04_FOCUS')
    for i in range(4): box('Survey_Inscription_'+str(i),(-.05,-.557,.18+i*.04),(.115,.012,.012),'bronze','08_DETAILS')

def orc_university():
    # A six-sided teaching lodge with an open forecourt and scroll archive.
    polygon_prism('Teaching_Lodge_Foot',hexagon(.37,(0,.27),angle=0),.076,.15,'stone','02_HALL')
    polygon_prism('Teaching_Lodge_Walls',hexagon(.34,(0,.27),angle=0),.15,.72,'timber','02_HALL')
    for i,(x,y) in enumerate(hexagon(.34,(0,.27),angle=0)): support('Lodge_Post_'+str(i),x,y,.13,.73,.073,inward=-1 if x>0 else 1)
    for i in range(6): polygon_prism('Lodge_Rust_Roof_'+str(i),hexagon(.41-i*.057,(0,.27),angle=0),.74+i*.042,.782+i*.042,'roof','03_ROOFS')
    portal('Lodge_Entrance',0,-.024,.13,.21,.36)
    for x in (-.32,.32): tusk('Lodge_Tusk_'+str(x),(x,.20,.75),.18,.042,'08_DETAILS')
    table('Lore_Lectern',0,-.29,.28,.18,.34)
    book('Lore_Book',0,-.29,.372,.22,.14,True)
    for x in (-.38,.38):
        bench('Teaching_Bench_'+str(x),x,-.38,.25)
        shelf('Scrolls_'+str(x),x,-.08,.22,.30,.10,True)
    barrel('Manuscript_Cask',-.21,-.58,r=.05,h=.13)

def human_arcane_shrine():
    hall('Mana_Chapel',0,.31,.58,.38,.53,True,True)
    box('Mana_Pedestal',(0,.25,.23),(.22,.21,.30),'cutstone','04_FOCUS')
    crystal('Chapel_Crystal',0,.25,.39,.20,.079)
    for x in (-.11,.11): beam('Crystal_Cradle_'+str(x),(x,.25,.32),(x*.6,.25,.59),.022,'gold','04_FOCUS')
    basin('Mana_Reservoir',0,-.34,.22,.11)
    beam('Stone_Channel',(0,.075,.10),(0,-.12,.10),.046,'cutstone','05_COURTYARD')
    beam('Mana_Flow',(0,.08,.128),(0,-.12,.128),.022,'mana_water','04_FOCUS')
    for x in (-.43,.43):
        support('Channel_Marker_'+str(x),x,-.21,.076,.34,.055)
        crystal('Marker_Crystal_'+str(x),x,-.21,.35,.13,.035)

def elf_arcane_shrine():
    tree('Mana_Root_Tree',-.43,.27,1.07,.15)
    # Narrow high canopy sheltering a root-and-leaf crystal cradle.
    for i,(x,y) in enumerate(((.03,.19),(.47,.19),(.25,.48))):
        support('Living_Canopy_Post_'+str(i),x,y,.076,.74,.039,inward=1 if x<.25 else -1)
    for i,(a,b) in enumerate((((.03,.19),(.47,.19)),((.47,.19),(.25,.48)),((.25,.48),(.03,.19)))):
        beam('Canopy_Triangular_Rafter_'+str(i),(a[0],a[1],.757),(b[0],b[1],.757),.040,'timber','06_STRUCTURE')
    roof('Mana_Leaf_Canopy',.25,.30,.62,.49,.77,7,True)
    polygon_prism('Crystal_Ivory_Dais',hexagon(.15,(.25,.28)),.076,.20,'cutstone','04_FOCUS')
    crystal('Root_Mana_Crystal',.25,.28,.23,.36,.084)
    for sign in (-1,1):
        beam('Root_Cradle_'+str(sign),(.25+sign*.13,.28,.13),(.25+sign*.075,.28,.41),.040,'timber','04_FOCUS')
        leaf('Cradle_Leaf_'+str(sign),(.25+sign*.13,.28,.35),.064,.13,.017,'gold','08_DETAILS')
    basin('Moon_Mana_Pool',-.07,-.32,.23,.10)
    beam('Root_Channel',(.25,.05,.10),(-.07,-.13,.10),.047,'timber','05_COURTYARD')
    flow_start,flow_end=Vector((.25,.05,.128)),Vector((-.07,-.13,.128))
    flow_axis=(flow_end-flow_start).normalized()
    beam('Mana_Root_Flow',flow_start+flow_axis*.008,flow_end-flow_axis*.008,.020,'mana_water','04_FOCUS')
    for x,y in ((-.45,-.26),(.42,-.30)):
        box('Mana_Garden_'+str(x),(x,y,.125),(.15,.15,.075),'cutstone','05_COURTYARD')
        box('Mana_Shrub_'+str(x),(x,y,.19),(.14,.14,.054),'foliage','08_DETAILS')

def dwarf_arcane_shrine():
    hall('Granite_Mana_Engine',0,.32,.77,.37,.56,True,True)
    box('Engine_Plinth',(0,.29,.17),(.31,.25,.18),'stone','04_FOCUS')
    crystal('Engine_Crystal',0,.29,.26,.33,.087)
    for x in (-.15,.15):
        support('Copper_Crystal_Clamp_'+str(x),x,.29,.19,.56,.049)
        beam('Clamp_Arm_'+str(x),(x,.29,.55),(x*.22,.29,.55),.024,'bronze','04_FOCUS')
    basin('Mana_Copper_Cistern',0,-.34,.20,.13)
    for side in (-1,1):
        beam('Copper_Conduit_Back_'+str(side),(side*.23,.27,.30),(side*.23,-.21,.30),.037,'bronze','04_FOCUS')
        beam('Copper_Conduit_Drop_'+str(side),(side*.23,-.21,.30),(side*.16,-.29,.23),.037,'bronze','04_FOCUS')
        support('Pipe_Bearing_'+str(side),side*.23,-.08,.076,.284,.055)
    gear('Mana_Regulator',.37,-.16,.31,.095)
    box('Regulator_Base',(.37,-.11,.18),(.17,.14,.20),'stone','04_FOCUS')
    box('Regulator_Bearing',(.37,-.095,.265),(.070,.070,.13),'iron','04_FOCUS')
    beam('Mana_Regulator_Axle',(.37,-.20,.31),(.37,-.06,.31),.022,'iron','04_FOCUS')

def orc_arcane_shrine():
    hall('Shamans_Mana_Hut',-.04,.30,.64,.37,.50,True,True)
    box('Crystal_Stone_Dais',(-.04,.27,.19),(.21,.22,.23),'stone','04_FOCUS')
    crystal('Shamans_Crystal',-.04,.27,.31,.26,.068)
    for x in (-.18,.10):
        support('Crystal_Iron_Clamp_'+str(x),x,.27,.12,.55,.055)
        beam('Crystal_Clamp_Arm_'+str(x),(x,.27,.53),(-.04,.27,.53),.023,'iron','04_FOCUS')
    basin('Bound_Mana_Vat',-.04,-.34,.22,.14)
    for i,(x,y) in enumerate(((-.26,-.34),(.18,-.34))):
        support('Vat_Wood_Post_'+str(i),x,y,.076,.37,.063,inward=1 if x<0 else -1)
    beam('Iron_Mana_Channel',(-.04,.075,.16),(-.04,-.12,.16),.049,'iron','04_FOCUS')
    beam('Mana_Channel_Lining',(-.04,.075,.186),(-.04,-.12,.186),.023,'mana_water','04_FOCUS')
    box('Mana_Channel_Stone_Bed',(-.04,-.021,.106),(.08,.23,.06),'stone','05_COURTYARD')
    for x in (-.47,.43): tusk('Mana_Guard_Tusk_'+str(x),(x,-.20,.076),.30,.047,'08_DETAILS')

globals()[CIV+'_'+ROLE]()
