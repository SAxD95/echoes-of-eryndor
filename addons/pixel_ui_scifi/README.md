# Pixel UI Sci-Fi

A sci-fi pixel-art GUI and HUD skin for Godot 4.3+: colour themes as ready-made `Theme`
resources, icons, segmented bar fills, HUD reticles, a cursor and a bitmap font. Every image is
also a plain PNG, with its 9-slice margins listed for any other engine.

**The full pack:** **[Pixel UI Sci-Fi](https://heyheythere.itch.io/pixel-ui-scifi)** has six neon themes (cyan, amber,
green, magenta, red and steel), 56 icons (planets, aliens, robots, satellites, chips, radar,
keycards, credits, crystals, cargo, and a full menu set) and four HUD reticles. Same files and
names: install it over this one.

## Use it in Godot

1. Copy `addons/pixel_ui_scifi/` into your project.
2. Project Settings:
   - *Rendering > Textures > Default Texture Filter*: **Nearest**, or the pixels blur.
   - *GUI > Theme > Custom*: `res://addons/pixel_ui_scifi/themes/cyan.tres` (or any theme), so
     every Control uses it. Or set `theme` on one Control and its children follow.
3. Draw the UI at a whole-number scale. The art is 1x (the font is 8px tall), made for a UI about
   240 pixels high: set *Display > Window > Stretch > Mode* to `canvas_items` and either use a
   small viewport (for example 320x180 or 480x270), or keep yours and set
   `get_tree().root.content_scale_factor` to 2, 3 or 4, as `demo/demo.gd` does.

## Themes

Each `themes/<name>.tres` styles Button, OptionButton, CheckBox (check and radio), Label, Panel,
PanelContainer, LineEdit, HSlider, ProgressBar, TabContainer, PopupMenu, tooltips, scroll bars and
HSeparator. Set `theme_type_variation` for the extras:

| Variation | On | Looks like |
|---|---|---|
| `WindowPanel` | PanelContainer | a window with a title bar; its first line of content sits in the bar |
| `Title` | Label | the text for that title bar |
| `InsetPanel` | PanelContainer | a sunken slot, 24x24 around a 16px icon |
| `BracketPanel` | PanelContainer | corner brackets only, for HUD frames and targets |
| `RedBar`, `GreenBar`, `BlueBar`, `GoldBar` | ProgressBar | hull, stamina, shield and energy fills |

A window: PanelContainer (`WindowPanel`) > VBoxContainer > Label (`Title`) first, then the content.
The variation names are the same as in Pixel UI, so a project can switch between the two kits by
switching its theme.

## Icons

The icons are white with a dark outline, so they take any colour. A Button tints its `icon` with
the theme's colours by itself. Anywhere else, set `self_modulate`, for example to the theme's
`icon_normal_color` of `Button`, as `demo/demo.gd`'s `tint` does. `icons/_sheet_<theme>.png`
has them all already tinted, on one 8-column sheet per theme.

## Other engines

Every part is a PNG in `themes/<name>/`. `themes/slices.json` lists each one's 9-slice borders
(left, top, right, bottom, in pixels; the same in every theme):

| Parts | Borders |
|---|---|
| `button_*`, `focus`, `panel`, `line_edit` | 4, 4, 4, 4 |
| `window` | 6, 12, 4, 4 (the title bar is the top 11 rows) |
| `bracket` | 5, 5, 5, 5 |
| `panel_inset`, `tooltip`, `progress_bg` | 3, 3, 3, 3 |
| `slider`, `slider_fill` | 3, 1, 3, 1 |
| `progress_fill`, `bars/bar_*` | 2, 3, 2, 2, with the middle **tiled** horizontally, not stretched, so it draws segments |
| `tab_selected` | 4, 4, 4, 1 |
| `tab_unselected`, `tab_hover` | 4, 5, 4, 2 |
| `scroll*`, `menu_hover` | 2, 2, 2, 2 |

The rest are drawn as they are: `checkbox_*` and `radio_*` (9x9), `grabber*` (5x9), `arrow`
(the option button's, 7x4).

## Files

- `themes/<name>.tres` and `themes/<name>/*.png`: the Theme and its parts.
- `icons/*.png`: 16x16, white, outlined, on a transparent background.
- `bars/bar_*.png`: the bar fills.
- `hud/reticle_*.png`: 16x16 crosshairs, white like the icons.
- `cursor.png` and `cursor_2x/3x/4x.png`: a mouse pointer, hotspot at the top-left pixel. The OS
  draws cursors unscaled, so pick the copy that matches your UI scale for *Display > Mouse Cursor >
  Custom Image*.
- `font/pixel_ui_scifi_font.fnt`: a proportional BMFont with all printable ASCII, 8px glyphs on a
  10px line. Keep it at size 8 and scale the UI instead.
