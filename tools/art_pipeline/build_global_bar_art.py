"""Hand-authored pixel SVG symbols for the live top bar. No raster processing."""
from pathlib import Path

ART = Path(__file__).resolve().parents[2] / "assets/ui/global_bar"
SYMBOLS = {
    "gold": [("#916b37", "M3 2H13V3H15V5H16V12H14V14H3V13H1V11H0V5H2V3H3Z"),
             ("#e6bc77", "M3 3H12V4H14V6H15V11H13V13H4V12H2V10H1V6H3Z"),
             ("#fff0b4", "M4 4H11V5H4ZM3 6H4V10H3Z"),
             ("#ad7c3f", "M7 5H9V6H11V7H8V8H11V11H9V12H7V11H5V10H8V9H5V6H7Z")],
    "supply": [("#796647", "M5 0H11V2H10V4H12V5H14V7H15V14H13V16H3V15H1V7H2V5H4V4H6V2H5Z"),
               ("#ccb986", "M6 1H10V2H9V4H7V2H6ZM5 5H11V6H13V8H14V13H12V15H4V14H2V8H3V6H5Z"),
               ("#f3dfad", "M5 6H7V8H5ZM3 9H5V12H3Z"),
               ("#937449", "M4 4H12V6H4ZM10 9H12V13H10ZM6 13H10V14H6Z")],
    "mana": [("#477d9b", "M7 0H9V2H11V4H13V7H14V12H12V14H10V16H6V15H4V13H2V7H3V4H5V2H7Z"),
             ("#7abcc9", "M7 2H9V4H11V7H12V12H10V14H6V13H4V7H5V4H7Z"),
             ("#d0f0da", "M7 4H9V6H7V9H5V7H6V5H7Z"),
             ("#375d89", "M9 9H12V12H10V14H7V12H9Z")],
    "knowledge": [("#8d7556", "M0 2H6V3H10V2H16V14H10V16H6V14H0Z"),
                  ("#e5d4a4", "M1 3H5V4H7V13H5V12H1ZM9 4H11V3H15V12H11V13H9Z"),
                  ("#fff0c8", "M1 3H5V4H1ZM11 3H15V4H11Z"),
                  ("#9ba28b", "M2 6H5V7H2ZM2 9H5V10H2ZM11 6H14V7H11ZM11 9H14V10H11Z"),
                  ("#b79665", "M7 4H9V15H7Z")],
    "cities": [("#b5c5b9", "M1 1H5V4H7V2H9V4H11V1H15V15H1Z"),
               ("#f0e4c0", "M2 2H4V5H7V4H9V5H12V2H14V14H2Z"),
               ("#557e85", "M3 6H5V9H3ZM11 6H13V9H11ZM6 10H10V15H6Z"),
               ("#78978c", "M2 12H5V14H2ZM11 12H14V14H11Z")],
    "units": [("#9ba6a1", "M5 0H11V2H13V5H14V10H12V11H10V14H13V16H3V14H6V11H4V10H2V5H3V2H5Z"),
              ("#e4dcc5", "M5 2H11V3H12V6H13V9H10V11H6V9H3V6H4V3H5Z"),
              ("#55717e", "M4 5H12V8H4Z"), ("#bd945d", "M7 1H9V5H7ZM6 12H10V14H6ZM4 14H12V15H4Z")],
    "research": [("#e5ce9e", "M0 2H6V3H10V2H16V14H10V16H6V14H0ZM2 4V12H5V13H7V5H5V4ZM9 5V13H11V12H14V4H11V5Z")],
    "empire": [("#e5ce9e", "M1 0H5V4H7V2H9V4H11V0H15V16H1ZM3 6V9H5V6ZM11 6V9H13V6ZM6 11V16H10V11Z")],
    "diplomacy": [("#e5ce9e", "M1 1H3V8H5V10H9V12H11V14H9V16H5V13H3V10H1ZM15 1H13V8H11V10H7V12H5V14H7V16H11V13H13V10H15ZM5 0H11V2H9V7H7V2H5Z")],
    "victory": [("#e5ce9e", "M0 2H3V5H6V0H10V5H13V2H16V13H0ZM2 8V11H14V8H12V7H10V8H6V7H4V8Z")],
    "events": [("#e5ce9e", "M2 1H14V4H12V12H15V15H3V13H1V10H3V4H1V2H2ZM4 4V11H6V6H10V5H6V4ZM5 13V14H13V13Z")],
    "more": [("#e5ce9e", "M1 6H4V10H1ZM6 6H10V10H6ZM12 6H15V10H12Z")],
}

def build():
    ART.mkdir(parents=True, exist_ok=True)
    for name, layers in SYMBOLS.items():
        paths = "".join(f'<path fill="{color}" d="{path}"/>' for color, path in layers)
        (ART / f"{name}.svg").write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 16 16" shape-rendering="crispEdges">{paths}</svg>\n', encoding="utf-8")

if __name__ == "__main__":
    build()
