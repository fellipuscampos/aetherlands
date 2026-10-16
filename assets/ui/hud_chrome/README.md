# Live HUD chrome

`scripts/ui/HUDChromeTheme.gd` brings the approved menu's stone and brass
button frames to the live HUD. Hand-authored pixel SVG panels and icons use
nearest filtering, square details and stepped corners. Rebuild the assets
with `python tools/art_pipeline/build_hud_chrome_art.py`.

Turn controls, pending decisions, minimap controls, notifications, critical
alerts and shared context cards use this theme. Pixelify Sans is reserved for
headings and controls; descriptions and numeric details retain readable body
fonts. The top bar and research board keep their dedicated local themes.

The footer keeps 16 px outer margins and separate areas for the minimap,
pending decisions and turn controls. Expanded pending decisions scroll above
their existing summary button. Skipping unresolved decisions still requires
the existing confirmation, whose initial keyboard focus returns to decisions.
Critical banner events remain in history and are not repeated as simultaneous
toasts. Other notifications stack without taking mouse input from the map.

The minimap retains its terrain raster, fog delta updates, fixed world bounds,
camera indicator and click/drag interaction. Only an actual interface scale
change invalidates its layout cache; reduced motion changes do not rebuild it.

Native review: `tools/art_pipeline/review_hud_chrome.gd`. Run it through Godot
with the project path to capture a disposable real Main scene, including
expanded decisions, keyboard interaction, skip confirmation, minimap,
notifications and processing states. Screenshots and `validation.json` go to
`docs/previews/hud_chrome/`. The review covers 1280x720, 1600x900, 1920x1080
and ultrawide, including interface scales of 125% and 150%, without writing
saved matches or persistent preferences.
