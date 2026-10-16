"""Reproducible Godot lobby scene and pixel-grid ornaments, scoped to GameSetupScreen."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/ui/game_setup'
nodes = []


def node(name, kind, parent=None, **values):
    header = f'[node name="{name}" type="{kind}"'
    if parent is not None:
        header += f' parent="{parent}"'
    nodes.append(header + ']\n' + '\n'.join(f'{k.replace("__", "/")} = {v}' for k, v in values.items()))


def label(name, parent, text, variation='SetupBody', **values):
    node(name, 'Label', parent, layout_mode=2, mouse_filter=2,
         theme_type_variation=f'&"{variation}"', text=f'"{text}"', **values)


def main():
    ART.mkdir(parents=True, exist_ok=True)
    # Large, quiet panel; four-pixel stepped corners and a double engraved rim.
    (ART / 'panel.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192">
<path fill="#07171e" d="M8 0H184V4H188V8H192V184H188V188H184V192H8V188H4V184H0V8H4V4H8Z"/>
<path fill="#59665c" d="M8 4H184V8H188V184H184V188H8V184H4V8H8Z"/>
<path fill="#132a30" d="M12 8H180V12H184V180H180V184H12V180H8V12H12Z"/>
<path fill="#a39b75" d="M12 8H180V12H12ZM8 12H12V180H8Z" opacity=".25"/>
<path fill="#899181" d="M24 24H40V28H24ZM148 20H168V24H148ZM24 168H44V172H24ZM152 164H168V168H152Z" opacity=".09"/>
</svg>''', encoding='utf-8')
    (ART / 'selected.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192">
<path fill="#1b3439" d="M8 0H184V4H188V8H192V184H188V188H184V192H8V188H4V184H0V8H4V4H8Z"/>
<path fill="#d8b877" fill-rule="evenodd" d="M8 0H184V4H188V8H192V184H188V188H184V192H8V188H4V184H0V8H4V4H8Z M12 4V8H8V12H4V180H8V184H12V188H180V184H184V180H188V12H184V8H180V4Z"/>
<path fill="#d8b877" d="M8 8H36V12H12V36H8ZM156 8H184V36H180V12H156ZM8 156H12V180H36V184H8ZM180 156H184V184H156V180H180Z"/>
</svg>''', encoding='utf-8')
    emblems = {
        'human': 'M2 4H4V7H6V3H10V7H12V4H14V12H2ZM3 13H13V15H3Z',
        'elf': 'M7 0H9V3H7ZM7 13H9V16H7ZM0 7H3V9H0ZM13 7H16V9H13ZM3 2H5V4H3ZM11 2H13V4H11ZM3 12H5V14H3ZM11 12H13V14H11ZM6 4H10V5H11V6H12V10H11V11H10V12H6V11H5V10H4V6H5V5H6Z',
        'dwarf': 'M2 2H11V3H13V7H11V8H2ZM6 8H9V15H6ZM1 1H4V9H1ZM4 13H11V16H4Z',
        'orc': 'M1 1H5V3H7V6H9V3H11V1H15V7H11V8H10V10H12V12H14V15H11V13H9V11H7V13H5V15H2V12H4V10H6V8H5V7H1Z',
    }
    for race, path in emblems.items():
        (ART / f'emblem_{race}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 16 16"><path fill="#e4c38d" d="{path}"/></svg>', encoding='utf-8')

    node('GameSetupScreen', 'Control', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0,
         grow_horizontal=2, grow_vertical=2, texture_filter=1, script='ExtResource("Script")')
    node('Backdrop', 'ColorRect', '.', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0,
         grow_horizontal=2, grow_vertical=2, mouse_filter=2, color='Color(0.025, 0.07, 0.087, 1)')
    node('Landscape', 'TextureRect', '.', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0,
         grow_horizontal=2, grow_vertical=2, mouse_filter=2, texture='ExtResource("Landscape")', expand_mode=1, stretch_mode=6)
    node('Veil', 'ColorRect', '.', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0,
         grow_horizontal=2, grow_vertical=2, mouse_filter=2, color='Color(0.025, 0.065, 0.08, 0.86)')
    node('Header', 'HBoxContainer', '.', layout_mode=0, theme_override_constants__separation=20)
    node('Crest', 'TextureRect', 'Header', custom_minimum_size='Vector2(56, 56)', layout_mode=2,
         mouse_filter=2, texture='ExtResource("Crest")', expand_mode=1, stretch_mode=5)
    node('Titles', 'VBoxContainer', 'Header', layout_mode=2, size_flags_horizontal=3, theme_override_constants__separation=4)
    label('Kicker', 'Header/Titles', 'AETHERLANDS  /  NOVA PARTIDA', 'SetupKicker')
    label('TitleLabel', 'Header/Titles', 'Forje seu reino', 'SetupTitle')
    label('Hint', 'Header', 'Escolha um povo.\nPrepare sua jornada.', 'SetupMuted', vertical_alignment=1, horizontal_alignment=2)
    node('CenterBox', 'ScrollContainer', '.', layout_mode=0, horizontal_scroll_mode=0,
         follow_focus='true', theme_override_constants__scroll_deadzone=12)
    node('Box', 'VBoxContainer', 'CenterBox', layout_mode=2, size_flags_horizontal=3,
         theme_override_constants__separation=16)
    node('RaceSection', 'VBoxContainer', 'CenterBox/Box', layout_mode=2, theme_override_constants__separation=16)
    label('RaceSectionLabel', 'CenterBox/Box/RaceSection', '01  ESCOLHA SEU POVO', 'SetupKicker')
    node('RaceListColumn', 'HBoxContainer', 'CenterBox/Box/RaceSection', layout_mode=2,
         theme_override_constants__separation=16)
    for race in ['Human', 'Elf', 'Dwarf', 'Orc']:
        node(race + 'RaceButton', 'Button', 'CenterBox/Box/RaceSection/RaceListColumn',
             custom_minimum_size='Vector2(0, 190)', layout_mode=2, size_flags_horizontal=3,
             toggle_mode='true', button_group='SubResource("RaceGroup")', button_pressed='true' if race == 'Human' else 'false',
             mouse_default_cursor_shape=2, theme_type_variation='&"SetupRaceCard"', alignment=1)
    node('Details', 'HBoxContainer', 'CenterBox/Box/RaceSection', layout_mode=2,
         theme_override_constants__separation=20)
    detail = 'CenterBox/Box/RaceSection/Details/RaceDetailPanel'
    node('RaceDetailPanel', 'PanelContainer', 'CenterBox/Box/RaceSection/Details', layout_mode=2,
         size_flags_horizontal=3, size_flags_stretch_ratio=1.2, theme_type_variation='&"SetupPanel"')
    node('RaceDetailBox', 'VBoxContainer', detail, layout_mode=2, theme_override_constants__separation=10)
    content = detail + '/RaceDetailBox'
    node('RaceAccent', 'ColorRect', content, custom_minimum_size='Vector2(0, 4)', layout_mode=2, mouse_filter=2)
    label('SelectionLabel', content, 'SEU POVO', 'SetupKicker')
    label('RaceNameLabel', content, '', 'SetupHeading', autowrap_mode=3)
    label('RaceTaglineLabel', content, '', 'SetupMuted', autowrap_mode=3)
    node('RaceSpecialtiesLabel', 'RichTextLabel', content, layout_mode=2, bbcode_enabled='true',
         fit_content='true', scroll_active='false', mouse_filter=2)
    node('LoreButton', 'Button', content, custom_minimum_size='Vector2(190, 44)', layout_mode=2,
         size_flags_horizontal=0, theme_type_variation='&"SetupSmallButton"', text='"Conhecer história"', mouse_default_cursor_shape=2)
    node('RaceLoreLabel', 'RichTextLabel', content, visible='false', custom_minimum_size='Vector2(0, 136)',
         layout_mode=2, bbcode_enabled='true', fit_content='true', scroll_active='false')
    config = 'CenterBox/Box/RaceSection/Details/ConfigurationPanel'
    node('ConfigurationPanel', 'PanelContainer', 'CenterBox/Box/RaceSection/Details', layout_mode=2,
         size_flags_horizontal=3, theme_type_variation='&"SetupPanel"')
    node('ConfigurationBox', 'VBoxContainer', config, layout_mode=2, theme_override_constants__separation=10)
    config += '/ConfigurationBox'
    label('ConfigTitle', config, '02  PREPARE SUA PARTIDA', 'SetupKicker')
    label('KingdomNameLabel', config, 'Nome do reino', 'SetupBody')
    node('KingdomNameEdit', 'LineEdit', config, custom_minimum_size='Vector2(0, 46)', layout_mode=2,
         max_length=40, placeholder_text='"Reino de Aldenmark"')
    label('NameHint', config, 'Deixe em branco para usar o nome do seu povo.', 'SetupMuted', autowrap_mode=3)
    label('MapSizeLabel', config, 'Tamanho do mapa', 'SetupBody')
    node('MapSizeButtons', 'HBoxContainer', config, layout_mode=2, theme_override_constants__separation=8)
    label('MapSizeHint', config, '', 'SetupMuted', autowrap_mode=3)
    node('ConfigurationRow', 'HBoxContainer', config, layout_mode=2, theme_override_constants__separation=16)
    label('RivalCountLabel', config + '/ConfigurationRow', 'Rivais de IA', 'SetupBody', size_flags_horizontal=3, vertical_alignment=1)
    node('RivalCountRow', 'HBoxContainer', config + '/ConfigurationRow', layout_mode=2, theme_override_constants__separation=8)
    stepper = config + '/ConfigurationRow/RivalCountRow'
    node('DecreaseRivalsButton', 'Button', stepper, custom_minimum_size='Vector2(44, 44)', layout_mode=2,
         theme_type_variation='&"SetupSmallButton"', text='"−"', tooltip_text='"Diminuir número de rivais"', mouse_default_cursor_shape=2)
    label('RivalCountValue', stepper, '1', 'SetupHeading', custom_minimum_size='Vector2(36, 44)', horizontal_alignment=1, vertical_alignment=1)
    node('IncreaseRivalsButton', 'Button', stepper, custom_minimum_size='Vector2(44, 44)', layout_mode=2,
         theme_type_variation='&"SetupSmallButton"', text='"+"', tooltip_text='"Aumentar número de rivais"', mouse_default_cursor_shape=2)
    label('StatusLabel', config, '', 'SetupMuted', autowrap_mode=3, visible='false')
    node('Footer', 'VBoxContainer', '.', layout_mode=0, theme_override_constants__separation=12)
    node('Divider', 'HSeparator', 'Footer', layout_mode=2)
    node('FooterRow', 'HBoxContainer', 'Footer', layout_mode=2, theme_override_constants__separation=24)
    node('BackButton', 'Button', 'Footer/FooterRow', custom_minimum_size='Vector2(160, 56)', layout_mode=2,
         theme_type_variation='&"SetupSmallButton"', text='"Voltar"', mouse_default_cursor_shape=2)
    node('Summary', 'VBoxContainer', 'Footer/FooterRow', layout_mode=2, size_flags_horizontal=3, alignment=1, theme_override_constants__separation=4)
    label('MapRuleLabel', 'Footer/FooterRow/Summary', '', 'SetupMuted')
    label('NavigationHint', 'Footer/FooterRow/Summary', 'Esc  Voltar  ·  Tab / setas  Navegar', 'SetupMuted')
    node('StartGameButton', 'Button', 'Footer/FooterRow', custom_minimum_size='Vector2(260, 56)', layout_mode=2,
         theme_type_variation='&"TitlePrimaryButton"', text='"Iniciar partida"', mouse_default_cursor_shape=2)
    header = '''[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/ui/GameSetupScreen.gd" id="Script"]
[ext_resource type="Texture2D" path="res://assets/ui/title_menu/kingdom_landscape_painted.png" id="Landscape"]
[ext_resource type="Texture2D" path="res://assets/ui/title_menu/crest.svg" id="Crest"]

[sub_resource type="ButtonGroup" id="RaceGroup"]
allow_unpress = false

'''
    (ROOT / 'scenes/ui/GameSetupScreen.tscn').write_text(header + '\n\n'.join(nodes) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
