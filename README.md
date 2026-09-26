# GMForms

A Delphi-style RAD form system for GameMaker. See `gamemaker-form-designer-plan.md` for the full plan.

**Status: M1 (runtime core), M2 (serialization), M3 (Tier 1 controls) M4 (PropertyGrid + undo, with a tile editor sample) and M5 (Tier 2 controls: menus, popups, lists, tabs, toolbar, value editors) implemented.** Built for GameMaker IDE 2026.0.

## Run the demos

Open `GMForms.yyp` in GameMaker and run it (F5). The first room is the **M4 tile editor sample** (`rm_demo_tiles`), built by hand in `scripts/demo_tiles`:

1. **Paint:** pick a tile in the left palette, then left-drag on the map. Right-drag erases. Each stroke is one undo step.
2. **Select:** switch to the *Select* tool and click a cell to edit it in the property grid (tile, tag, spawn point). Right-click a cell to pick up its tile.
3. **Property grid:** clicking a palette tile shows its type (metadata-driven: categories, colour, ranges). *Map props* shows the map info with inferred editors (nested struct, array). Click a value to edit it; Enter commits and Escape cancels. Bools toggle and enums cycle on click; numbers have -/+ buttons. Drag the column divider to resize.
4. **Undo/Redo:** use the Edit menu, the toolbar, or Ctrl+Z / Ctrl+Y (or Ctrl+Shift+Z). It covers paint strokes, grid edits and *Clear*, which uses a JSON snapshot.
5. **Save/Open:** use the toolbar or Ctrl+S / Ctrl+O. This writes `tilemap.json` to the save area (`%LOCALAPPDATA%\GMForms` on Windows).
6. Pan with middle-drag or Space+drag, and zoom with the wheel. The splitters resize the palette and the inspector.

**File > Other demos** opens the **M5 controls gallery** (menus with submenus, a tree context menu, ListBox, TreeView, ComboBox, SpinEdit, Slider, ColorPicker, SpritePicker, and the property grid's popup editors on three tabs, with a dark/light theme switch under View) and the **M1 layout demo**. In the M1 demo, Resize the window there to watch Align/Anchors reflow. Tab/Shift+Tab cycles focus, and Space/Enter clicks the focused button.

## What's in M1–M4

| Script | Contents |
|---|---|
| `gmforms_core` | `global.gmforms` state, `gmforms_log`, `gmforms_create`, rect, scissor-stack and drawing helpers |
| `gmforms_theme` | `gmforms_theme_dark()` (default) and `gmforms_theme_light()` flat-colour themes |
| `gmforms_control` | `GMF_Control`: tree, setters, **Align + Anchors layout engine**, hit testing, clipped drawing, input hooks |
| `gmforms_form` | `GMF_Form`: root control and input manager (hover, capture, click, wheel bubbling, focus, Tab order, key routing, typed-character and clipboard-key forwarding), `update()` / `render()` |
| `gmforms_controls_basic` | `GMF_Panel`, `GMF_Button`, `GMF_Label`, `GMF_CheckBox`, `GMF_Splitter` |
| `gmforms_controls_viewport` | `GMF_Viewport`: pannable/zoomable camera over its own surface, for hosting your own GML drawing |
| `gmforms_controls_edit` | `GMF_Edit`: single-line text — caret, selection, clipboard, scroll, password mode |
| `gmforms_controls_propgrid` | `GMF_PropertyGrid`: edits a struct with inferred or metadata-driven editors, or a control's published properties (`bind_control`). Also `gmforms_color_to_hex` / `gmforms_color_from_hex` and `gmforms_format_number` |
| `gmforms_controls_lists` | `GMF_ListBox`, `GMF_TreeView`, `GMF_ComboBox`, `GMF_SpritePicker` and the dropdown popup they share |
| `gmforms_controls_menus` | `GMF_MenuBar`, `GMF_PopupMenu` (context menus, submenus), menu item helpers and shortcuts |
| `gmforms_controls_containers` | `GMF_TabControl` / `GMF_TabSheet`, `GMF_Toolbar` / `GMF_ToolSeparator` |
| `gmforms_controls_values` | `GMF_SpinEdit`, `GMF_Slider`, `GMF_ColorPicker` |
| `gmforms_undo` | `GMF_UndoStack`: command-based undo/redo with groups, `set_value` and JSON-snapshot steps |
| `gmforms_host` + `obj_gmforms_host` | Host object: tracks window size, resizes `application_surface` and the GUI layer to it (1:1, no letterboxing), resizes the form, forwards Step / Draw GUI |
| `gmforms_serialize` | Registry-driven JSON save/load: `gmforms_form_to_json`, `gmforms_save_form`, `gmforms_load_form` / `gmforms_load_form_json`, event-name binding, `gmforms_value_equals` |
| `gmforms_tests` | 433 headless checks of Align, Anchors, reflow, hit testing, focus/Tab, keyboard clicks, M2 serialization round-trips, and M3 controls (CheckBox toggling, Splitter drag-resize, Viewport camera math, Edit text editing), plus M4 (undo stack, PropertyGrid editing/metadata/undo integration, and the tile editor's document model), plus M5 (popup layer, menus, shortcuts, context menus, and every Tier 2 control, driven through the form's real input path). They run in the first room when `GMF_RUN_TESTS` is true and print `[GMForms tests] N passed, M failed` to the Output window |

## Minimal usage

```gml
// Create event of any object
form = gmforms_create(GMF_Form, { caption: "My Tool", width: 800, height: 600 });
var _bar = form.add(gmforms_create(GMF_Panel, { align: "top", height: 36 }));
var _ok  = _bar.add(gmforms_create(GMF_Button, { name: "btnOk", caption: "OK", left: 6, top: 4 }));
_ok.on_click = function(_sender) { show_debug_message("clicked " + _sender.name); };
form.add(gmforms_create(GMF_Panel, { align: "client" }));
gmforms_host_create(form);
```

## Layout rules

- **Align** (`none`, `top`, `bottom`, `left`, `right`, `client`) is processed in that order, each group in child order, inside the parent's padding. Margins are respected. Invisible controls are skipped.
- **Anchors** (any of `left`, `top`, `right`, `bottom`; default left + top) keep the distances captured at **design size**, which is the form's `width`/`height` when it is first laid out. `left` + `right` stretches the control. With neither, the control keeps its centre at the same relative position (Delphi behaviour, answers Q3).
- `left`/`top` are relative to the parent's top-left corner. Padding affects aligned children only.
- To move or resize a control from code, use `set_bounds()` or `set({...})`. They re-capture anchors. Assigning `left`/`width` directly on an anchored control is overwritten by the next layout.
- `min_width`, `min_height`, `max_width` and `max_height` are applied after Align/Anchors (0 means no limit).
- **`GMF_Splitter`** resizes the nearest *earlier* sibling with the same `align` (Delphi-exact, no explicit target). A left/top-aligned splitter grows its target when dragged away from the center; a right/bottom-aligned one shrinks its target when dragged toward it.

## Controls (M3)

**Viewport** hosts your own drawing behind a pan/zoom camera:
```gml
var _vp = form.add(gmforms_create(GMF_Viewport, { name: "vpMap", align: "client", grid_size: 32 }));
_vp.on_draw = function(_sender, _cam) {
    // draw in world coordinates — the viewport already applied cam's translate/zoom
    draw_set_colour(c_lime);
    draw_rectangle(0, 0, 64, 64, false);
};
```
Pan with middle-mouse or Space+left-drag; zoom with the wheel (zooms toward the cursor). `cam = {x, y, zoom}`; use `_vp.screen_to_world(x, y)` / `_vp.world_to_screen(x, y)` to convert.

**Edit** is a single-line text box:
```gml
var _ed = form.add(gmforms_create(GMF_Edit, { name: "edName", left: 8, top: 8, width: 200 }));
_ed.on_change = function(_sender, _text) { show_debug_message("now: " + _text); };
```
Supports caret movement, Shift-extend selection, Ctrl+A/C/X/V, mouse click/drag-select, horizontal scroll, and `password: true` for masked input.

## Menus, popups and Tier 2 controls (M5)

```gml
var _menu = form.add(gmforms_create(GMF_MenuBar));          // align "top"
_menu.add_menu("File", [
    gmforms_menu_item("Save", function(_sender, _item) { save(); }, { shortcut: "Ctrl+S" }),
    gmforms_submenu("Export", [ gmforms_menu_item("PNG", export_png) ]),
    gmforms_menu_separator(),
    gmforms_menu_item("Exit", function(_s, _it) { game_end(); }),
]);

var _bar = form.add(gmforms_create(GMF_Toolbar));           // lines its children up left to right
_bar.add_button("Save", function(_sender) { save(); });
_bar.add_separator();
_bar.add(gmforms_create(GMF_ComboBox, { items: ["50%", "100%"], item_index: 1, width: 90 }));

_tree.popup_menu = gmforms_create(GMF_PopupMenu, { items: [ gmforms_menu_item("Delete", delete_node) ] });  // right-click

var _tabs = form.add(gmforms_create(GMF_TabControl, { align: "client" }));
var _page = _tabs.add_page("General");                      // add controls to the page
```
- **Popups** (menus, dropdown lists, the colour popup) draw above everything. A click outside closes them (and does nothing else); Escape closes the topmost one. `form.show_popup(control, x, y, owner)` puts any control of your own in the popup layer.
- **Shortcuts** in menu items work from anywhere in the form: `"Ctrl+S"`, `"Ctrl+Shift+Z"`, `"F5"`, `"Ctrl+Delete"`. Add `alt_shortcut` for a second, undisplayed binding.
- **ListBox** / **TreeView**: `on_change(sender, index | node)` and `on_activate` (double-click / Enter). Tree nodes are `{ text, nodes, expanded, data }`; use `add_node(parent, text, [data])`, `remove_node`, `select_node` and `expand_all`.
- **ComboBox** / **SpritePicker**: `on_change(sender, index | sprite)`. SpritePicker lists the project's sprites, or your own `sprites` + `labels`.
- **SpinEdit** / **Slider**: `value`, `min_value`, `max_value`, `step` (plus `decimals` on SpinEdit), and `on_change(sender, value)`.
- **ColorPicker**: `color`, `on_change(sender, colour)` (fires live while you drag).
- The **PropertyGrid** uses these popups: enum values open a dropdown, colour swatches open the colour popup (one undo step per drag), and sprites open a thumbnail list.
- GML has no `super`. From an override, `gmforms_inherited(self, GMF_Base, "method")(args)` calls the base version.

## PropertyGrid and undo (M4)

**PropertyGrid** edits any struct:
```gml
var _grid = form.add(gmforms_create(GMF_PropertyGrid, { name: "gridProps", align: "right", width: 280 }));

_grid.bind(enemy);                       // editors inferred from the values (bool, string, number, struct, array)

_grid.bind(enemy, [                      // or metadata-driven
    { name: "name",  type: "string", category: "General" },
    { name: "kind",  type: "enum", values: [0, 1, 2], labels: ["Orc", "Elf", "Dwarf"], category: "General" },
    { name: "hp",    type: "int",  min: 1, max: 999, step: 5, category: "Stats" },
    { name: "speed", type: "real", range: { min: 0, max: 2, step: 0.1 }, category: "Stats" },
    { name: "tint",  type: "color", category: "Look" },
    { name: "id",    type: "int", readonly: true },
]);

_grid.on_change = function(_sender, _key, _old, _new, _owner) { show_debug_message(_key + " = " + string(_new)); };
```
- Metadata types: `string`, `int`, `real`, `bool`, `enum`, `color` (edited as `#RRGGBB`), `sprite` / `font` (by asset name), `anchors`, `struct`, `array`. Other entry fields are `label`, `category`, `readonly`, `fields` (metadata for a nested struct) and `set_fn(owner, field, value)`.
- Values are read live, so the grid always shows the current data. Call `refresh()` only after you add or remove fields.
- `_grid.bind_control(control)` shows a control's published properties and writes them through `set()`. This is the basis for the designer's Object Inspector.

**GMF_UndoStack** is a public helper. The grid records its own edits when you set `grid.undo`:
```gml
undo = new GMF_UndoStack();
_grid.undo = undo;

undo.set_value(cell, "t", 3, "Paint");   // one-liner for a field write
undo.execute({                           // or a full command; its functions can read its own fields
    label: "Move", obj: _o, dx: 16,
    do_fn:   function() { obj.x += dx; },
    undo_fn: function() { obj.x -= dx; },
});
undo.begin_group("Paint stroke"); /* ...many steps... */ undo.end_group();   // one undo step
undo.push_snapshot("Clear", _json_before, _json_after, restore_fn);           // snapshot-style step
undo.undo(); undo.redo(); undo.can_undo(); undo.undo_label();
```

## Serialization (M2)

Every control class declares a `static published` list of `{ name, type, default_value }` entries (base list: `gmforms_base_published()`; subclasses `array_concat()` their own on top, which can override a base default). Only non-default published properties are written to JSON — see plan section 5 for the file format.

```gml
// Save
gmforms_save_form("main.gmform.json", form);   // writes to Included Files (datafiles/)

// Load, binding "onClick": "btnSave_Click" style handlers by name
function MainHandlers() constructor {
    btnSave_Click = function(_sender) { save_map(); };
}
var _form = gmforms_load_form("main.gmform.json", new MainHandlers());
gmforms_host_create(_form);
```

- A missing handler name logs one warning and leaves that event unset — it still doesn't crash, and the name is kept so re-saving the form doesn't lose it.
- An unknown `class` logs a warning and that node (and its subtree) is skipped; siblings still load.
- Anchored controls (`align: "none"`) save the design rect captured at first layout, not whatever their current (possibly resized) rect is.
- Custom control classes register themselves with `gmforms_register("MyClass", MyCtor)` so the loader can instantiate them.

## Choices made for open questions

- **Q1:** constructors use the `GMF_` prefix (`GMF_Button`) to avoid collisions in user projects. This is easy to rename before release.
- **Q3:** controls with no horizontal (or vertical) anchor keep a proportional centre, as in Delphi.

## Visual check

For the controls gallery, set `DEMO_M5_CAPTURE` to `true` (in `demo_m5`). The first room then jumps to the gallery, which opens each menu, dropdown and popup in turn and saves `m5_*.png`. For the tile editor, set `DEMO_TILES_CAPTURE` to `true` (in `demo_tiles`). It then plays a short scripted session (cell edit, map properties, painting, a tile type) and saves `m4_*.png` to the save area before quitting.


Set `GMF_DEMO_CAPTURE` to `true` (in `demo_m1`). The demo then saves `m1_*.png` screenshots to the save area (`%LOCALAPPDATA%\GMForms`) at 1024×700, 1200×760 (palette hidden, focus moved) and 760×520 (top-right button disabled), and then quits.

## Notes from testing on GameMaker LTS 2026 (Windows)

- A filled `draw_rectangle` covers `[x1, x2)`, so `gmforms_draw_rect` passes `x + w`. With `x + w - 1`, 1px border strips didn't draw at all.
- With **Keep aspect ratio** on, GameMaker draws the GUI layer inside the letterboxed application-surface rect. That broke 1:1 pixels and scissor clipping after a resize. The host resizes `application_surface` to the window, which fixes this.
- GameMaker's built-in font is fairly wide. Captions longer than their button are clipped, which is intentional. Proper theme fonts come with the theme milestone.
- Editing project files outside the IDE while the project is open: the IDE picks the change up after a few seconds. If you press Run straight away, it can write back its own copy.

## Project settings

Windows, macOS and Linux options have **Allow window resize** turned on. That's required for reflow.
