"""Reproducible hand-authored SVG frames and symbols for the live HUD."""
from pathlib import Path

ART = Path(__file__).resolve().parents[2] / 'assets/ui/hud_chrome'

def build():
    ART.mkdir(parents=True, exist_ok=True)
    for name, accent in {'neutral':'#697c70','info':'#7cbdcf','warning':'#dfb76f','critical':'#dc8b78','target':'#bc99d9'}.items():
        (ART / f'panel_{name}.svg').write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" shape-rendering="crispEdges">
<path fill="#06171d" d="M6 0H90V3H93V6H96V90H93V93H90V96H6V93H3V90H0V6H3V3H6Z"/>
<path fill="{accent}" d="M6 3H90V6H93V90H90V93H6V90H3V6H6Z"/>
<path fill="#142c32" d="M9 6H87V9H90V87H87V90H9V87H6V9H9Z"/>
<path fill="#c5bea0" opacity=".18" d="M9 6H87V9H9ZM6 9H9V87H6Z"/>
<path fill="{accent}" opacity=".1" d="M18 18H33V21H18ZM66 24H78V27H66ZM24 72H39V75H24ZM57 66H75V69H57Z"/>
</svg>''', encoding='utf-8')
    symbols = {
        'turn':'M1 3H8V0L15 6L8 12V9H1ZM1 12H5V16H1ZM6 13H10V16H6ZM11 12H15V16H11Z',
        'skip':'M0 3H3V5H5V7H7V9H5V11H3V13H0ZM7 3H10V5H12V7H14V9H12V11H10V13H7ZM14 2H16V14H14Z',
        'pending':'M3 0H13V2H15V16H1V2H3ZM3 3V14H13V3ZM6 5H10V9H6ZM7 11H9V13H7Z',
        'info':'M6 0H10V4H6ZM4 6H10V13H13V16H3V13H6V9H4Z',
        'warning':'M7 0H9V2H11V5H13V8H15V11H16V16H0V11H1V8H3V5H5V2H7ZM7 5V10H9V5ZM7 12V14H9V12Z',
        'critical':'M4 0H12V2H14V4H16V12H14V14H12V16H4V14H2V12H0V4H2V2H4ZM6 3V9H10V3ZM6 11V14H10V11Z',
        'expand':'M0 0H6V2H2V6H0ZM10 0H16V6H14V2H10ZM0 10H2V14H6V16H0ZM14 10H16V16H10V14H14Z',
        'collapse':'M4 0H6V6H0V4H4ZM10 0H12V4H16V6H10ZM0 10H6V16H4V12H0ZM10 10H16V12H12V16H10Z',
        'compass':'M7 0H9V5H11V7H16V9H11V11H9V16H7V11H5V9H0V7H5V5H7ZM7 7V9H9V7Z',
    }
    for name, path in symbols.items():
        (ART / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 16 16" shape-rendering="crispEdges"><path fill="#efd9a6" d="{path}"/></svg>\n', encoding='utf-8')

if __name__ == '__main__':
    build()
