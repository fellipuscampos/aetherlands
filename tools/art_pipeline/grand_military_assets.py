"""Military landmarks and their own civilization's basic building references."""
CIVS = {'human': ('humans', 'Humanos'), 'orc': ('orcs', 'Orcs'),
        'dwarf': ('dwarves', 'Anões'), 'elf': ('elves', 'Elfos')}
RECIPES = {
    'guardian': ('guardian_mastery', 'Bastião de Maestria', 'guardian_champion', 'guardian_hall'),
    'warrior': ('warrior_mastery', 'Arena dos Campeões', 'blade_hero', 'warrior_hall'),
    'ranger': ('ranger_mastery', 'Torre dos Patrulheiros', 'legend_hunter', 'ranger_camp'),
    'cavalry': ('cavalry_mastery', 'Ordem da Cavalaria', 'griffon_rider', 'war_stable'),
    'rogue': ('rogue_mastery', 'Refúgio das Sombras', 'shadow_master', 'rogue_guild'),
    'siege': ('grand_arsenal', 'Grande Arsenal', 'siege_colossus', 'siege_arsenal'),
}
QUEUE = [(civ, role) for civ in CIVS for role in RECIPES]
ROOFS = {'human': [49, 79, 127], 'orc': [130, 58, 39],
         'dwarf': [67, 82, 89], 'elf': [48, 122, 88]}

def folder_name(civ, role):
    return ('' if civ == 'human' else civ + '_') + RECIPES[role][0] + '_hex_v1'

def reference_folder(civ, role):
    if civ == 'human' and role == 'guardian':
        return 'guardian_hall_hex_v2'
    return ('' if civ == 'human' else civ + '_') + RECIPES[role][3] + '_hex_v1'
