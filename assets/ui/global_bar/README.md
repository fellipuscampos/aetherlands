# Live top bar

`scripts/ui/GlobalBarTheme.gd` scopes the approved pixel menu frames, colors,
Pixelify Sans headings and readable body numbers to `GlobalBarPresenter`.
The rest of the HUD retains its own theme. Icons are hand-authored SVG pixel
symbols; rebuild them with `python tools/art_pipeline/build_global_bar_art.py`.

The bar is one continuous surface with 12 px horizontal and 6 px vertical
content margins (scaled with the interface), inset 12 px from the sides and
8 px from the top. Its normal minimum height is 56 px; accessibility scaling
can grow its actual height. The shell reserves that actual height for overlays.

Gold, supply usage/capacity, Mana and banked Knowledge/income remain visible.
On wider screens the bar also shows cities, troops and labeled navigation.
Smaller widths use icons or the keyboard-accessible More menu; city/troop
counts and all navigation destinations remain available there. Exact values
and state explanations remain in tooltips. Economy, world era, research,
alerts and unread-event counts still come from the existing runtime APIs.

The research widget now supports Enter/Space and has a pixel focus frame.
Responsive layout is event-driven, without per-frame polling. Resource icon
overrides continue to work through `set_resource_icon`.

Native review: `tools/art_pipeline/review_global_bar.gd`. It renders an isolated
real map and HUD, exercises banked Knowledge, navigation and deficit/logistics
states, and writes screenshots plus `validation.json` to
`docs/previews/global_bar/`. It does not write a saved match or change persistent
settings.
