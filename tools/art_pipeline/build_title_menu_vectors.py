"""Build code-native, pixel-grid menu frames and glyphs (no external artwork)."""
from pathlib import Path

DEST = Path(__file__).resolve().parents[2] / "assets/ui/title_menu"


def frame(name, fill, edge, light, shadow):
    # A 4px grid, stepped corners, engraved brass and deliberately sparse grain.
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="192" height="64" viewBox="0 0 192 64">',
             f'<path fill="{shadow}" d="M8 0H184V4H188V8H192V56H188V60H184V64H8V60H4V56H0V8H4V4H8Z"/>',
             f'<path fill="{edge}" d="M8 4H184V8H188V56H184V60H8V56H4V8H8Z"/>',
             f'<path fill="{fill}" d="M12 8H180V12H184V52H180V56H12V52H8V12H12Z"/>',
             f'<path fill="{light}" d="M12 8H180V12H12ZM8 12H12V48H8Z" opacity=".55"/>',
             f'<path fill="{shadow}" d="M12 52H180V56H12ZM180 16H184V52H180Z" opacity=".75"/>']
    for x, y, w in [(24, 16, 12), (64, 20, 8), (120, 16, 16), (152, 28, 12),
                    (36, 40, 16), (88, 44, 12), (140, 44, 8), (64, 32, 4)]:
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="4" fill="{light}" opacity=".09"/>')
    parts.append('</svg>')
    (DEST / f'{name}.svg').write_text(''.join(parts), encoding='utf-8')


def glyph(name, path, color='#f4e9d3'):
    (DEST / f'{name}.svg').write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 16 16">'
        f'<path fill="{color}" d="{path}"/></svg>', encoding='utf-8')


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    frame('button_stone', '#203537', '#6c7667', '#a5b39d', '#0b191c')
    frame('button_stone_hover', '#304c4b', '#d4b475', '#d9cb9f', '#101f20')
    frame('button_stone_pressed', '#172a2e', '#bd975e', '#668077', '#081315')
    frame('button_bronze', '#78552e', '#ddb373', '#ffda92', '#302719')
    frame('button_bronze_hover', '#926b39', '#ffe0a2', '#fff1bd', '#302719')
    frame('button_bronze_pressed', '#574124', '#d6b477', '#aa814d', '#241d17')
    frame('button_disabled', '#1c2a2c', '#485752', '#64736a', '#0e191d')
    (DEST / 'button_focus.svg').write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="64">'
        '<path fill="#fff0ad" fill-rule="evenodd" d="M8 0H184V4H188V8H192V56H188V60H184V64H8V60H4V56H0V8H4V4H8Z '
        'M12 4V8H8V12H4V52H8V56H12V60H180V56H184V52H188V12H184V8H180V4Z"/>'
        '<path fill="#fff0ad" d="M0 24H4V40H0ZM188 24H192V40H188Z"/></svg>', encoding='utf-8')
    glyph('icon_new', 'M3 1H5V15H3ZM5 2H13V8H9V6H5ZM1 14H7V16H1Z')
    glyph('icon_load', 'M2 2H7V3H9V2H14V14H9V15H7V14H2ZM4 4V12H6V4ZM10 4V12H12V4Z')
    glyph('icon_settings', 'M6 0H10V3H12V2H14V4H13V6H16V10H13V12H14V14H12V13H10V16H6V13H4V14H2V12H3V10H0V6H3V4H2V2H4V3H6ZM6 6V10H10V6Z')
    glyph('icon_quit', 'M1 1H10V5H8V3H3V13H8V11H10V15H1ZM9 7H12V4H13V5H14V6H15V7H16V9H15V10H14V11H13V12H12V9H9Z')
    (DEST / 'crest.svg').write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 32 32">'
        '<path fill="#987b4e" d="M14 0H18V4H22V8H26V12H30V20H26V24H22V28H18V32H14V28H10V24H6V20H2V12H6V8H10V4H14Z"/>'
        '<path fill="#13272d" d="M14 4H18V8H22V12H26V20H22V24H18V28H14V24H10V20H6V12H10V8H14Z"/>'
        '<path fill="#efd09a" d="M14 7H18V11H20V15H22V23H10V15H12V11H14ZM14 15V19H18V15ZM3 14H7V18H3ZM25 14H29V18H25Z"/>'
        '<path fill="#ffffff" d="M14 7H18V9H14ZM10 21H22V23H10Z"/></svg>', encoding='utf-8')


if __name__ == '__main__':
    main()
