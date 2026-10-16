# Context inspectors

`ContextPanelStyle.gd` applies the approved pixel HUD palette and frames locally
to city, unit and tile inspectors. Headers use the existing city level or map
badge, a pixel title, readable subtitle and separate status chips. Stat blocks,
commands, abilities, production choices and tabs share square details and
consistent spacing. Ordinary strategic screens retain their own layouts.

City health and shield share a row. The five city tabs remain accessible, with
measured tab widths rather than equally truncating every label. Production
categories and the current project normally remain above the scrolling catalog.
At short logical heights, project details and fortification chips join the
scrolling content so choices have usable space. The production catalog still
updates existing items when its category and item structure are unchanged.

Unit health and attributes remain above the scrolling commands, abilities,
traits, effects and context. Commands use the same pixel frame and height;
valid founding retains its primary color and F shortcut. Disabled choices keep
readable names and the original runtime reasons. Grid columns follow their
actual allocated width, including accessibility scaling, without polling.

Resources and lairs gain their own inspector identity. Terrain, ownership,
resource improvements, modifications and temporary environments retain the
existing fog-aware presenter data. Explicit monster and rival inspection now
routes the occupant selector for that tile instead of retaining the previous
unit's label. Commands, production and targeting retain the existing APIs.

The shell respects both preferred and minimum inspector heights so compact
panels retain their bottom gap above turn controls. Width grows with interface
scale while staying below 40% of the viewport. Long identities use wrapping or
ellipsis with their full text available on hover.

Native review: `tools/art_pipeline/review_context_panels.gd`. Its disposable Main
scene captures all city tabs, both settler states, troops, a mage, a builder,
a legendary unit, a monster and an improved resource. It checks 1280x720,
1600x900, 1920x1080 and ultrawide, including 125% and 150% scale, plus a long
city name. Output: `docs/previews/context_panels/`, including `validation.json`.
It does not write saved matches or persistent preferences.
