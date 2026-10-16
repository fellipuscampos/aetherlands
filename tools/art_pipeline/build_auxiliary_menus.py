"""Build the two pixel fantasy menu scenes and small code-native control textures."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/ui/menu_controls'


class Scene:
    def __init__(self, name, script):
        self.name, self.script, self.nodes = name, script, []
        self.node(name, 'Control', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0,
                  grow_horizontal=2, grow_vertical=2, visible='false', texture_filter=1, script='ExtResource("Script")')
        self.node('Landscape', 'TextureRect', '.', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0,
                  grow_horizontal=2, grow_vertical=2, mouse_filter=2, texture='ExtResource("Landscape")', expand_mode=1, stretch_mode=6)
        self.node('Backdrop', 'ColorRect', '.', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0,
                  grow_horizontal=2, grow_vertical=2, mouse_filter=2, color='Color(0.025, 0.065, 0.08, 0.9)')

    def node(self, name, kind, parent=None, **values):
        header = f'[node name="{name}" type="{kind}"' + (f' parent="{parent}"' if parent is not None else '') + ']'
        self.nodes.append(header + '\n' + '\n'.join(f'{k.replace("__", "/")} = {v}' for k, v in values.items()))

    def label(self, name, parent, text='', variation='SetupBody', **values):
        self.node(name, 'Label', parent, layout_mode=2, mouse_filter=2, text=f'"{text}"',
                  theme_type_variation=f'&"{variation}"', **values)

    def header(self, path, title, kicker):
        self.node('Header', 'HBoxContainer', path, layout_mode=2, theme_override_constants__separation=20)
        path += '/Header'
        self.node('Crest', 'TextureRect', path, layout_mode=2, custom_minimum_size='Vector2(56,56)',
                  texture='ExtResource("Crest")', mouse_filter=2, expand_mode=1, stretch_mode=5)
        self.node('Titles', 'VBoxContainer', path, layout_mode=2, size_flags_horizontal=3, theme_override_constants__separation=4)
        self.label('Kicker', path+'/Titles', kicker, 'SetupKicker')
        self.label('Title', path+'/Titles', title, 'SetupTitle')

    def save(self):
        header = f'''[gd_scene load_steps=4 format=3]
[ext_resource type="Script" path="res://scripts/ui/{self.script}.gd" id="Script"]
[ext_resource type="Texture2D" path="res://assets/ui/title_menu/kingdom_landscape_painted.png" id="Landscape"]
[ext_resource type="Texture2D" path="res://assets/ui/title_menu/crest.svg" id="Crest"]

'''
        (ROOT / f'scenes/ui/{self.name}.tscn').write_text(header+'\n\n'.join(self.nodes)+'\n', encoding='utf-8')


def textures():
    ART.mkdir(parents=True, exist_ok=True)
    icons = {
        'audio': 'M1 6H4L8 2H10V14H8L4 10H1ZM12 4H14V6H15V10H14V12H12V10H13V6H12Z',
        'video': 'M1 1H15V12H10V14H13V16H3V14H6V12H1ZM3 3V10H13V3Z',
        'interface': 'M6 0H10V4H6ZM1 5H15V7H10V10H12V16H10V12H6V16H4V10H6V7H1Z',
        'controls': 'M1 3H15V13H1ZM3 5V7H5V5ZM7 5V7H9V5ZM11 5V7H13V5ZM3 9V11H13V9Z',
        'help': 'M6 1H11V2H13V3H14V7H12V9H10V11H7V8H9V6H11V4H6V6H3V3H4V2H6ZM7 13H10V16H7Z',
    }
    for name, path in icons.items():
        (ART / f'icon_{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 16 16"><path fill="#e6ce9e" d="{path}"/></svg>', encoding='utf-8')
    (ART/'arrow.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="16"><path fill="#ead6ae" d="M0 0H24V4H20V8H16V12H12V16H8V12H4V8H0Z"/></svg>', encoding='utf-8')
    (ART/'slider_grabber.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="32"><path fill="#30281e" d="M4 0H20V4H24V28H20V32H4V28H0V4H4Z"/><path fill="#dfbe81" d="M4 4H20V28H4Z"/><path fill="#fff0b7" d="M4 4H20V8H4Z"/><path fill="#88663f" d="M8 12H12V24H8ZM16 12H20V24H16Z"/></svg>', encoding='utf-8')
    (ART/'slider_grabber_focus.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40"><path fill="#fff0ad" d="M4 0H28V4H32V36H28V40H4V36H0V4H4Z"/><path fill="#30281e" d="M4 4H28V36H4Z"/><path fill="#dfbe81" d="M8 8H24V32H8Z"/><path fill="#fff0b7" d="M8 8H24V12H8Z"/><path fill="#88663f" d="M12 16H16V28H12ZM20 16H24V28H20Z"/></svg>', encoding='utf-8')
    for checked in [False, True]:
        body = '#716044' if checked else '#253d42'
        thumb = '#f0ce88' if checked else '#85998c'
        x = 36 if checked else 4
        mark = 'M10 16H14V20H18V16H22V12H26V16H22V20H18V24H14V20H10Z' if checked else 'M38 14H54V18H38Z'
        (ART / ('switch_on.svg' if checked else 'switch_off.svg')).write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32"><path fill="#5c7166" d="M4 0H60V4H64V28H60V32H4V28H0V4H4Z"/><path fill="{body}" d="M4 4H60V28H4Z"/><rect x="{x}" y="4" width="24" height="24" fill="{thumb}"/><path fill="#e4c99b" d="{mark}"/></svg>', encoding='utf-8')


def load_scene():
    s = Scene('LoadGameScreen', 'LoadGameScreen')
    s.node('Margin', 'MarginContainer', '.', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2)
    s.node('VBox', 'VBoxContainer', 'Margin', layout_mode=2, theme_override_constants__separation=20)
    s.header('Margin/VBox', 'Carregar jogo', 'AETHERLANDS  /  CRÔNICAS DO REINO')
    s.node('ListHeading', 'HBoxContainer', 'Margin/VBox', layout_mode=2)
    s.label('Description', 'Margin/VBox/ListHeading', 'Retome a história de um reino salvo.', 'SetupMuted', size_flags_horizontal=3)
    s.label('CountLabel', 'Margin/VBox/ListHeading', '', 'SetupKicker')
    s.node('ScrollContainer', 'ScrollContainer', 'Margin/VBox', layout_mode=2, size_flags_vertical=3, horizontal_scroll_mode=0, follow_focus='true')
    s.node('SlotList', 'VBoxContainer', 'Margin/VBox/ScrollContainer', layout_mode=2, size_flags_horizontal=3, theme_override_constants__separation=16)
    s.node('EmptyState', 'CenterContainer', 'Margin/VBox', layout_mode=2, size_flags_vertical=3, mouse_filter=2)
    s.node('EmptyBox', 'VBoxContainer', 'Margin/VBox/EmptyState', layout_mode=2, theme_override_constants__separation=16)
    s.node('Icon', 'TextureRect', 'Margin/VBox/EmptyState/EmptyBox', layout_mode=2, custom_minimum_size='Vector2(80,80)',
           texture='ExtResource("Crest")', expand_mode=1, stretch_mode=5, mouse_filter=2)
    s.label('EmptyStateLabel', 'Margin/VBox/EmptyState/EmptyBox', 'Nenhuma partida salva ainda.', 'SetupHeading', horizontal_alignment=1)
    s.label('Hint', 'Margin/VBox/EmptyState/EmptyBox', 'Comece um novo reino e salve sua jornada\npara continuar daqui na próxima vez.', 'SetupMuted', horizontal_alignment=1)
    s.node('Divider', 'HSeparator', 'Margin/VBox', layout_mode=2)
    s.node('Footer', 'HBoxContainer', 'Margin/VBox', layout_mode=2, theme_override_constants__separation=24)
    s.node('BackButton', 'Button', 'Margin/VBox/Footer', layout_mode=2, custom_minimum_size='Vector2(160,52)',
           text='"Voltar"', theme_type_variation='&"SetupSmallButton"', mouse_default_cursor_shape=2)
    s.label('Hint', 'Margin/VBox/Footer', 'Esc  Voltar  ·  Tab / setas  Navegar', 'SetupMuted', size_flags_horizontal=3, vertical_alignment=1)
    s.node('ConfirmDeleteDialog', 'ConfirmationDialog', '.', title='"Excluir partida"', initial_position=1, size='Vector2i(480,180)',
           dialog_text='"Excluir esta partida salva? Isso não pode ser desfeito."')
    s.save()


def settings_scene():
    s = Scene('SettingsScreen', 'SettingsScreen')
    s.node('Margin', 'MarginContainer', '.', layout_mode=1, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2)
    s.node('Layout', 'VBoxContainer', 'Margin', layout_mode=2, theme_override_constants__separation=20)
    s.header('Margin/Layout', 'Configurações', 'AETHERLANDS  /  SUA EXPERIÊNCIA')
    body = 'Margin/Layout/Body'
    s.node('Body', 'HBoxContainer', 'Margin/Layout', layout_mode=2, size_flags_vertical=3, theme_override_constants__separation=24)
    s.node('CategoryScroll', 'ScrollContainer', body, layout_mode=2, custom_minimum_size='Vector2(220,0)', horizontal_scroll_mode=0, follow_focus='true')
    categories = body+'/CategoryScroll/Categories'
    s.node('Categories', 'VBoxContainer', body+'/CategoryScroll', layout_mode=2, size_flags_horizontal=3, theme_override_constants__separation=12)
    s.label('CategoryLabel', categories, 'PREFERÊNCIAS', 'SetupKicker')
    for name, title in [('Audio','Áudio'),('Video','Vídeo'),('Accessibility','Interface'),('Controls','Controles'),('Help','Ajuda')]:
        s.node(name+'Category', 'Button', categories, unique_name_in_owner='true', layout_mode=2, toggle_mode='true',
               custom_minimum_size='Vector2(0,56)', text=f'"{title}"', alignment=0, theme_type_variation='&"SetupSmallButton"', mouse_default_cursor_shape=2)
    s.node('DebugButton', 'Button', categories, unique_name_in_owner='true', layout_mode=2, visible='false', text='"Developer Tools"')
    s.label('Hint', categories, 'Ajustes aplicados na hora e salvos automaticamente.', 'SetupMuted', autowrap_mode=3)
    s.node('PagePanel', 'PanelContainer', body, layout_mode=2, size_flags_horizontal=3, size_flags_vertical=3,
           custom_minimum_size='Vector2(680,440)', theme_type_variation='&"SetupPanel"')
    s.node('PageScroll', 'ScrollContainer', body+'/PagePanel', layout_mode=2, horizontal_scroll_mode=0, follow_focus='true')
    pages = body+'/PagePanel/PageScroll/Pages'
    s.node('Pages', 'VBoxContainer', body+'/PagePanel/PageScroll', layout_mode=2, size_flags_horizontal=3)
    for name in ['Audio','Video','Accessibility','Controls','Help']:
        s.node(name+'Page', 'VBoxContainer', pages, unique_name_in_owner='true', layout_mode=2,
               visible='true' if name=='Audio' else 'false', size_flags_horizontal=3, theme_override_constants__separation=14)
    audio = pages+'/AudioPage'
    s.label('Title', audio, 'Áudio', 'SetupHeading')
    s.label('Introduction', audio, 'A trilha do seu reino e os sons da sua jornada.', 'SetupMuted', autowrap_mode=3)
    for name, title in [('Music','Volume da música'),('Sfx','Volume dos efeitos')]:
        s.node(name+'Row', 'HBoxContainer', audio, layout_mode=2)
        s.label(name+'Label', audio+'/'+name+'Row', title, size_flags_horizontal=3)
        s.label(name+'Value', audio+'/'+name+'Row', '100%', 'SetupKicker', unique_name_in_owner='true')
        s.node(name+'Slider', 'HSlider', audio, unique_name_in_owner='true', layout_mode=2,
               custom_minimum_size='Vector2(480,44)', min_value=0.0, max_value=1.0, step=0.05)
    s.label('Tip', audio, 'Use as setas para ajustar os volumes com precisão.', 'SetupMuted', autowrap_mode=3)
    video = pages+'/VideoPage'
    s.label('Title', video, 'Vídeo', 'SetupHeading')
    s.label('DisplayHeading', video, 'TELA', 'SetupKicker')
    for name, label in [('WindowMode','Modo de janela'),('Resolution','Resolução'),('AntiAliasing','Suavização de bordas'),('ShadowQuality','Qualidade das sombras')]:
        if name == 'AntiAliasing':
            s.node('VSyncCheckButton', 'CheckButton', video, unique_name_in_owner='true', layout_mode=2, custom_minimum_size='Vector2(0,44)',
                   text='"Sincronização vertical (V-Sync)"', tooltip_text='"Sincroniza a imagem com a atualização do monitor."', mouse_default_cursor_shape=2)
            s.label('QualityHeading', video, 'QUALIDADE VISUAL', 'SetupKicker')
        s.node(name+'Row', 'HBoxContainer', video, layout_mode=2, theme_override_constants__separation=16)
        s.label(name+'Label', video+'/'+name+'Row', label, custom_minimum_size='Vector2(220,0)', vertical_alignment=1)
        s.node(name+'Option', 'OptionButton', video+'/'+name+'Row', unique_name_in_owner='true', layout_mode=2,
               size_flags_horizontal=3, custom_minimum_size='Vector2(0,44)', mouse_default_cursor_shape=2)
    s.label('EffectsHeading', video, 'AMBIENTE E ILUMINAÇÃO', 'SetupKicker')
    checks = [('DayNightCheck','Ciclo de dia e noite'),
              ('WeatherCheck','Clima: chuva e neve'),('MapLightingCheck','Iluminação dos recursos'),('CreatureLightingCheck','Iluminação das manifestações')]
    hints = {'VSyncCheckButton':'Sincroniza a imagem com a atualização do monitor.', 'DayNightCheck':'Alterna dia e noite em tempo real. Desligado, permanece meio-dia.',
             'WeatherCheck':'Ativa os efeitos visuais e sonoros de chuva e neve.', 'MapLightingCheck':'Cristais e nódulos iluminam o terreno ao redor. O brilho dos modelos é preservado.',
             'CreatureLightingCheck':'Os núcleos das Grandes Manifestações iluminam o terreno e as tropas próximas.'}
    for name, title in checks:
        s.node(name, 'CheckButton', video, unique_name_in_owner='true', layout_mode=2, custom_minimum_size='Vector2(0,44)',
               text=f'"{title}"', tooltip_text=f'"{hints[name]}"', mouse_default_cursor_shape=2)
    s.label('GraphicsHint', video, 'As mudanças são aplicadas imediatamente.', 'SetupMuted', unique_name_in_owner='true', autowrap_mode=3)
    s.node('ResetGraphicsButton', 'Button', video, unique_name_in_owner='true', layout_mode=2, size_flags_horizontal=0,
           custom_minimum_size='Vector2(0,44)', text='"Restaurar padrões gráficos"', theme_type_variation='&"SetupSmallButton"', mouse_default_cursor_shape=2)
    accessibility = pages+'/AccessibilityPage'
    s.label('Title', accessibility, 'Interface e acessibilidade', 'SetupHeading', autowrap_mode=3)
    s.label('ScaleLabel', accessibility, 'Escala da interface')
    s.node('UIScaleOption', 'OptionButton', accessibility, unique_name_in_owner='true', layout_mode=2, custom_minimum_size='Vector2(0,44)')
    s.label('ScaleHint', accessibility, 'Aumente fontes e controles para uma leitura mais confortável.', 'SetupMuted', autowrap_mode=3)
    s.node('ReducedMotionCheck', 'CheckButton', accessibility, unique_name_in_owner='true', layout_mode=2,
           custom_minimum_size='Vector2(0,44)', text='"Movimento reduzido"')
    s.label('MotionHint', accessibility, 'Remove transições e pulsos cosméticos, mantendo as indicações de texto e estado.', 'SetupMuted', autowrap_mode=3)
    for page, title, richname in [('Controls','Controles','ControlsText'),('Help','Guia do reino','GlossaryText')]:
        path = pages+'/'+page+'Page'
        s.label('Title', path, title, 'SetupHeading')
        s.node(richname, 'RichTextLabel', path, unique_name_in_owner='true', layout_mode=2, bbcode_enabled='true',
               fit_content='true', scroll_active='false', focus_mode=2)
    s.node('Divider', 'HSeparator', 'Margin/Layout', layout_mode=2)
    s.node('Footer', 'HBoxContainer', 'Margin/Layout', layout_mode=2, theme_override_constants__separation=24)
    s.node('BackButton', 'Button', 'Margin/Layout/Footer', unique_name_in_owner='true', layout_mode=2,
           custom_minimum_size='Vector2(160,52)', text='"Voltar"', theme_type_variation='&"SetupSmallButton"', mouse_default_cursor_shape=2)
    s.label('NavigationHint', 'Margin/Layout/Footer', 'Esc  Voltar  ·  Tab / setas  Navegar', 'SetupMuted', size_flags_horizontal=3, vertical_alignment=1)
    s.label('Status', 'Margin/Layout/Footer', 'ALTERAÇÕES SALVAS AUTOMATICAMENTE', 'SetupKicker', vertical_alignment=1)
    s.save()


if __name__ == '__main__':
    textures()
    load_scene()
    settings_scene()
