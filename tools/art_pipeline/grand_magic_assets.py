"""Asset identifiers match the six existing grand ritual buildings in the game."""
CIVS={'human':('humans','Humanos'),'orc':('orcs','Orcs'),'dwarf':('dwarves','Anões'),'elf':('elves','Elfos')}
RECIPES={
    'sacred':('sacred_ritual','Grande Catedral','seraph','sacred_temple'),
    'infernal':('infernal_ritual','Círculo Profano','archdemon','infernal_sanctum'),
    'necromancy':('necromancy_ritual','Mausoléu Negro','lich_sovereign','necromancy_ossuary'),
    'druidism':('druidic_ritual','Bosque Ancestral','nature_avatar','druidic_circle'),
    'arcanism':('arcane_ritual','Torre do Véu','veil_archon','arcane_conclave'),
    'elementalism':('elemental_ritual','Nexus dos Elementos','elemental_primordial','elemental_observatory'),
}
QUEUE=[(c,s) for c in CIVS for s in RECIPES]
ROOFS={'human':[49,79,127],'orc':[130,58,39],'dwarf':[67,82,89],'elf':[48,122,88]}

def folder_name(civ,school):
    return ('' if civ=='human' else civ+'_')+RECIPES[school][0]+'_hex_v1'
