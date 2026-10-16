# In-game research

Local theme: `scripts/ui/ResearchMenuTheme.gd`. Reuses the approved pixel menu
frames, Pixelify Sans headings and existing game glyphs. Body text uses Godot's
readable fallback font. `grain.svg` is a hand-authored repeating pixel texture.
`ResearchCardDecoration.gd` draws static square ornaments and focus/hover frames.
No generated raster art or new gameplay data is required.

The three research trees retain their real state, costs, city requirements,
prerequisites, banked Knowledge preview and single active project. Clicking or
pressing Enter selects a technology; the explicit footer action starts or pauses
research. Tier headers and branch labels stay fixed, with signal-driven scrolling.
Cards retain keyboard focus when progress replaces their presentation.

UI scale is honored. At narrow logical widths, jumps and zoom are available in
the **Navegar / zoom** popup. The selected tab identifies the tree without an
additional heading block. Balanced 80–84 px rows, 24 px page margins, 8 px card
padding and a compact action footer keep the tree readable without oversized
chrome. The node description is
available in tooltips; requirements and progress remain in the footer. Longer
selected-node information scrolls inside it. Development tools remain debug-only and
collapsed by default. No polling or decorative animation is introduced.

Native review (actual Main → HUD overlay, no saved match is written):

```powershell
& '<Godot console executable>' --path . --script tools/art_pipeline/review_research_menu.gd --windowed --resolution 1600x900
```

Screenshots and machine-readable results: `docs/previews/research/`.
