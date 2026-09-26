# GameMaker RAD Form Designer — Project Plan

> **How to use this document:** This is the working plan for a project. If you are an AI assistant reading this at the start of a session, treat it as the source of truth for goals, decisions, and conventions. Ask before contradicting a decision listed under *Decisions made*. Verify specific GML function names against the current GameMaker manual before relying on them — they are noted here from memory and may have changed.

Working name: **GMForms** (placeholder — rename freely)

> **Progress (2026-09-25):** M1 is done and tested in GameMaker LTS 2026: the project runs, 130 headless checks pass, and screenshots were checked at 3 window sizes. See `README.md`. Provisional answers: Q1 → `GMF_` prefix; Q3 → proportional centre (Delphi). Next up: **M2 Serialization**.

---

## 1. Summary

A Delphi-style RAD (Rapid Application Development) system for GameMaker, consisting of:

1. **Runtime library** — pure GML. Loads form files (JSON), lays out and runs controls, dispatches events to user code.
2. **Visual designer** — a GameMaker application (built with the runtime library itself) for laying out forms visually and saving them as JSON.

**Target audience:** GameMaker users who want to build **game-related tools**: level/tilemap editors, dialogue editors, data/stat table editors, animation previewers, mod tools, debug panels.

**Pitch:** "Build your level editor's UI in an afternoon." Visual designer + Delphi-style Align/Anchors layout + a live Viewport control + a struct-bound Property Grid.

---

## 2. Goals and non-goals

### Goals
- Delphi-like workflow: drag controls onto a form, set properties in an Object Inspector, bind events by name.
- Delphi-style layout: **Align** (Top, Bottom, Left, Right, Client, None) and **Anchors** (Left, Top, Right, Bottom) — not HBox/VBox nesting.
- Apps reflow like desktop apps when the window is resized (1:1 pixels, no scaling).
- Pure GML, no extensions/DLLs, so it works on every GameMaker target (focus: Windows, macOS, Linux desktop).
- Controls that game tools actually need: Viewport, PropertyGrid, TreeView, Splitter, Tabs, menus, toolbars.
- Low-ceremony API usable by hobbyist GML programmers; strong docs and sample projects.

### Non-goals (for now)
- Native OS look. The library draws its own themed controls.
- Integrating with the GameMaker IDE (no IDE plugin; the designer is a standalone app).
- Automatically editing the user's `.yyp`/`.yy` project files.
- Mobile/touch-first design (should not break on touch, but not optimized for it).
- Rich text, HTML rendering, full IME support in v1.

---

## 3. Decisions made

| # | Decision | Rationale |
|---|---|---|
| D1 | Controls are **GML constructor structs**, not objects | Lightweight, support inheritance (`Button : Control`), clean parent/child tree |
| D2 | One **host object** owns a form and forwards Step/Draw GUI/input to it | Keeps instance count at one per form |
| D3 | **Custom Align/Anchors layout engine** inside the form | More faithful to Delphi than mapping onto flexbox; avoids generated nested flex panels |
| D4 | GameMaker **UI Layer / Flex Panels** used only for the outer shell (optional) | Provides the app's current rectangle and fixed chrome; the form lays itself out inside that rect |
| D5 | UI drawn in the **Draw GUI** event; on window resize call `display_set_gui_size(window_get_width(), window_get_height())` | 1:1 pixels, reflow instead of scale |
| D6 | Form files are **JSON** stored in Included Files | Human-readable, diffable, easy for AI tools to edit |
| D7 | Events bound by **name** via a user-supplied handler struct, *and* directly in code | GML lacks reliable reflection; also supports simple beginner style |
| D8 | Each control class declares **published property metadata** | Drives the Object Inspector, JSON save/load, and the runtime PropertyGrid (GML has no RTTI) |
| D9 | Designer is **built with the runtime library** | Dogfooding; the designer needs PropertyGrid, TreeView, Splitter anyway |
| D10 | Designer emits **event stub scripts** rather than editing the GameMaker project | Designer runs outside the IDE; editing `.yy` files is fragile |
| D11 | Distribute as a **local package (.yymps)**; test on both LTS and monthly GameMaker releases | Community is split between the two |
| D12 | **Dark theme by default**, DPI scale factor supported | Tools feel wrong in light gray; high-DPI laptops are common |

---

## 4. Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Host object (obj_gmforms_host)                          │
│   Step → form.update()   Draw GUI → form.draw()         │
│   Window resize → display_set_gui_size + form.set_bounds│
└───────────────┬─────────────────────────────────────────┘
                │ owns
        ┌───────▼────────┐
        │ Form (Control) │── theme, focus manager, popup layer, modal stack
        └───────┬────────┘
                │ children (tree)
   ┌────────────┼──────────────┬──────────────┐
 Panel       Splitter       Viewport      PropertyGrid ...
   │
 Button, Label, Edit ...
```

### Core modules
1. **Control base** — tree, bounds, visibility, enabled, layout props, hit-testing, drawing hooks, events.
2. **Layout engine** — Align + Anchors (Section 6).
3. **Input manager** — mouse hit-testing, hover, mouse capture, keyboard focus, tab order, key repeat, wheel routing.
4. **Popup layer** — draws above everything (ComboBox dropdowns, menus, tooltips, context menus).
5. **Modal stack** — dialogs that block input to underlying forms.
6. **Theme** — nine-slice sprites, colors, fonts, metrics, DPI scale.
7. **Serializer** — JSON ↔ control tree, driven by property metadata.
8. **Event binder** — resolves event names against a handler struct.
9. **Registry** — maps class names (`"Button"`) to constructors so JSON can instantiate them.

---

## 5. Form file format (JSON)

```json
{
  "format": "gmforms",
  "version": 1,
  "root": {
    "class": "Form",
    "name": "frmMain",
    "caption": "Tile Editor",
    "width": 1024, "height": 700,
    "children": [
      { "class": "Panel", "name": "pnlToolbar", "align": "top", "height": 36,
        "children": [
          { "class": "Button", "name": "btnSave", "left": 6, "top": 4,
            "width": 80, "height": 28, "caption": "Save",
            "anchors": ["left", "top"], "onClick": "btnSave_Click" }
        ] },
      { "class": "PropertyGrid", "name": "gridProps", "align": "right", "width": 260 },
      { "class": "Splitter", "name": "split1", "align": "right", "width": 4 },
      { "class": "Viewport", "name": "vpMap", "align": "client",
        "onDraw": "vpMap_Draw", "onMouseDown": "vpMap_MouseDown" }
    ]
  }
}
```

### Rules
- `class` must exist in the registry. Unknown classes → load error with the control's `name` and path.
- `name` must be unique within a form. Used for `form.find(name)`.
- Properties not present use the class default. Serializer writes only non-default values.
- Event properties start with `on` and hold a handler **name** (string).
- Child order in `children` = creation order = Align processing order within each align group = default tab order.
- `version` allows future migrations; loader must reject unknown major versions with a clear message.

---

## 6. Layout engine specification

### Align (Delphi semantics)
Values: `none` (default), `top`, `bottom`, `left`, `right`, `client`.

Algorithm for a container's client rect `R` (after the container's padding):
1. For each child with `align = top`, in child order: place at top of `R` with full `R` width and its own `height`; shrink `R` from the top.
2. Then all `bottom` children: place at bottom of `R`; shrink `R` from the bottom.
3. Then all `left` children: full remaining height, own `width`; shrink `R` from the left.
4. Then all `right` children.
5. Then all `client` children: each gets the remaining `R`.
6. Clamp `R` to non-negative size at every step.
7. Children with `align = none` are positioned by Anchors (below).
8. Each aligned child's `margin` is respected when placing it.

### Anchors (Delphi semantics)
Set of `left`, `top`, `right`, `bottom`. Default `[left, top]`.
- When a control is placed or its parent is resized *while design values are captured*, store its distances to each parent edge.
- On parent resize:
  - `left` only → keep distance to left edge (x fixed).
  - `right` only → keep distance to right edge (moves with right edge).
  - `left + right` → keep both distances (width stretches).
  - Neither → keep relative center position (optional; Delphi behavior).
  - Same logic vertically for `top`/`bottom`.

### Constraints
- `min_width`, `min_height`, `max_width`, `max_height` applied after Align/Anchors.

### Layout invalidation
- Changing bounds, align, anchors, visibility, or children marks the parent dirty.
- Layout runs once per frame before drawing, top-down, only on dirty subtrees.

---

## 7. Control base API (sketch)

```gml
function Control() constructor {
    // identity
    name = "";
    parent = undefined;
    children = [];

    // bounds (relative to parent client area)
    left = 0; top = 0; width = 100; height = 30;

    // layout
    align = "none";                 // none, top, bottom, left, right, client
    anchors = ["left", "top"];
    margin = { l: 0, t: 0, r: 0, b: 0 };
    padding = { l: 0, t: 0, r: 0, b: 0 };

    // state
    visible = true;
    enabled = true;
    tab_stop = false;
    tab_order = -1;
    hint = "";                      // tooltip text

    // events (set directly in code, or bound by name from JSON)
    on_click = undefined;
    on_mouse_down = undefined;
    on_mouse_up = undefined;
    on_mouse_move = undefined;
    on_key_down = undefined;
    on_change = undefined;
    on_resize = undefined;

    static add = function(_child) { /* set parent, push, invalidate */ };
    static remove = function(_child) {};
    static find = function(_name) { /* recursive */ };
    static screen_rect = function() {};
    static hit_test = function(_x, _y) {};   // deepest visible, enabled child
    static invalidate_layout = function() {};
    static draw = function() {};             // override in subclasses
    static draw_children = function() {};    // applies scissor clipping
    static handle_mouse = function(_ev) {};
    static handle_key = function(_ev) {};
    static focus = function() {};
}

function Button() : Control() constructor {
    caption = "Button";
    tab_stop = true;
    static draw = function() { /* theme nine-slice + caption */ };
}
```

### Published property metadata
Each class declares a static list used by the inspector, serializer, and PropertyGrid:

```gml
static published = [
    { name: "caption", type: "string", default_value: "Button" },
    { name: "enabled", type: "bool",   default_value: true },
    { name: "align",   type: "enum",   values: ["none","top","bottom","left","right","client"], default_value: "none" },
    { name: "onClick", type: "event" }
];
```
Subclasses concatenate their parent's list. Supported types: `string`, `int`, `real`, `bool`, `enum`, `color`, `sprite`, `font`, `anchors`, `event`, `struct`.

---

## 8. Events and user code

Two supported styles:

**A. Bound by name (from designer JSON):**
```gml
function MainHandlers() constructor {
    btnSave_Click = function(_sender) { save_map(); };
    vpMap_Draw = function(_sender, _cam) { draw_map(); };
}
form = gmforms_load("main.gmform.json", new MainHandlers());
```
Loader resolves `"btnSave_Click"` with `struct_get(handlers, name)`. Missing handler → warning (not a crash), listed once at load.

**B. Directly in code (beginner-friendly):**
```gml
form.find("btnSave").on_click = function(_sender) { save_map(); };
```

Handler signature convention: first argument is always the sender control; extra arguments are event-specific.

---

## 9. Control list and priorities

### Tier 1 — core (needed for first sample tool)
| Control | Notes |
|---|---|
| Form | Root; caption; owns focus, popup layer |
| Panel | Container; optional border/background |
| Label | Static text; alignment; word wrap optional |
| Button | Click; keyboard activation (Space/Enter when focused) |
| CheckBox | Checked state; on_change |
| Splitter | Resizes the adjacent aligned sibling (Delphi TSplitter semantics) |
| **Viewport** | See Section 10 |
| Edit | Single-line text: caret, selection, clipboard, scroll, password mode |
| **PropertyGrid** | See Section 11 |

### Tier 2 — tool essentials
TreeView, TabControl, ListBox, ComboBox (uses popup layer), MenuBar + popup menus, Toolbar, SpinEdit (numeric), Slider/TrackBar, ScrollBox, ColorPicker, SpritePicker (lists project sprites), Image, ProgressBar, RadioButton/RadioGroup.

### Tier 3 — later
Memo (multi-line text), Grid/Table (editable rows), DockPanel (movable tool windows), StatusBar, file dialog wrappers, Toast/notifications.

**Hardest pieces:** text editing (Edit, then Memo), ComboBox/menus (popup layer + focus), TreeView (virtualized scrolling, expand/collapse), PropertyGrid (nested editors).

---

## 10. Viewport control (key feature)

Purpose: host the user's own GML drawing for level/sprite/path editors.

- Owns a **surface** sized to the control; recreate if lost (`surface_exists` check every frame).
- Built-in **pan** (middle mouse or Space+drag) and **zoom** (wheel, centered on cursor); zoom limits configurable.
- Provides a camera struct: `{ x, y, zoom }` plus helpers `screen_to_world(x, y)` and `world_to_screen(x, y)`.
- Optional grid overlay with configurable cell size.
- Events: `on_draw(sender, cam)` (called with the surface as target and a world transform applied), `on_mouse_down/up/move(sender, world_x, world_y, button)`, `on_wheel`.
- Draws the surface into its bounds with scissor clipping.

---

## 11. PropertyGrid control (key feature)

Purpose: edit a user's struct (enemy stats, tile properties, dialogue node) with auto-generated editors.

- `grid.bind(struct, [metadata])`.
- Without metadata: infer editor from value type (string → Edit, real → SpinEdit, bool → CheckBox, struct → expandable nested group, array → expandable list).
- With metadata: supports `enum`, `range {min,max,step}`, `color`, `sprite`, `readonly`, `category`, display `label`.
- Two columns: name / editor; resizable divider; categories collapsible.
- `on_change(sender, key, old_value, new_value)` — integrates with the undo helper.
- The **designer's Object Inspector is this same control** bound to the selected control's published properties.

---

## 12. Theme

- Theme struct: colors (background, panel, text, text_disabled, accent, border, selection, hover), fonts (normal, bold, small, mono), metrics (padding, row height, scrollbar width), and nine-slice sprites per control state (normal, hover, pressed, disabled, focused).
- Use GameMaker sprite **nine-slice** settings and `draw_sprite_stretched` where possible.
- Global `gmforms_set_theme(theme)`; per-control overrides optional.
- DPI: a global `ui_scale` multiplies metrics and font choice; detect from display size or let user set it.
- Ship a dark theme (default) and a light theme.

---

## 13. Undo/redo helper (public)

- Command-based: `{ do_fn, undo_fn, label }`, with `undo_push`, `undo()`, `redo()`, `can_undo`, grouping (`begin_group`/`end_group`) for drags.
- Designer uses it; users get it for their own tools.
- Simple fallback mode: JSON snapshot per step (fine for small documents).

---

## 14. Designer application

### Layout
```
MenuBar / Toolbar
┌──────────┬───────────────────────────────┬──────────────┐
│ Palette  │ Design canvas (form preview)  │ Object       │
│          │                               │ Inspector    │
├──────────┤                               │ (PropertyGrid│
│ Tree view│                               │  + events)   │
└──────────┴───────────────────────────────┴──────────────┘
Status bar
```

### Features (MVP)
- New/Open/Save form JSON.
- Palette: click a class, then click/drag on canvas to create.
- Canvas renders the form using the runtime in **design mode** (events suppressed; clicks select).
- Selection handles, drag to move, handles to resize, snap to grid, keyboard nudge (arrows, Shift = larger step).
- Reparenting: drop a control onto a container.
- Tree view mirrors hierarchy; select in either place.
- Inspector edits published properties; Events tab lists `on*` properties with editable handler names.
- Default handler name on double-click in Events: `<controlName>_<Event>` (e.g. `btnSave_Click`).
- Undo/redo for all edits.

### Event stub generation
- "Generate handlers" writes a `.gml` file containing a handler constructor with empty methods for every event name in the form. Existing method names are preserved; new ones appended.
- The user adds/refreshes this script in their GameMaker project manually.

### Later
- Multi-select and align tools (align lefts, same width, distribute).
- Copy/paste controls (JSON on clipboard).
- Live **in-app design mode** (e.g. F12 inside a running tool to edit its form in place).
- Form templates (tool window with viewport + inspector preset).

---

## 15. GameMaker-specific concerns

- **File sandbox:** tools need to read/write outside the sandbox. Document the Game Options setting to disable the file system sandbox on desktop targets, and wrap `get_open_filename` / `get_save_filename` with sensible defaults.
- **Window resizing:** ensure the window is resizable in Game Options; handle resize each Step by comparing `window_get_width/height` to last known size.
- **Clipping:** `gpu_set_scissor` for containers; save/restore the previous scissor when nesting.
- **Text input:** use `keyboard_string` for typed characters plus `keyboard_check_pressed` for navigation keys; `clipboard_get_text` / `clipboard_set_text` for clipboard; implement key repeat manually for held navigation keys.
- **Surfaces** can be lost (focus loss, resize) — always check `surface_exists` before use.
- **Fonts:** GameMaker fonts are pre-rendered assets; plan a small set of sizes; consider `font_enable_sdf` for scalable text where available.
- **Versions:** test on current LTS and the latest monthly release; note minimum supported version in the README.

> Verify all function names above against the current GameMaker manual.

---

## 16. Roadmap with acceptance criteria

| Milestone | Scope | Done when |
|---|---|---|
| **M1 Runtime core** | Control base, tree, layout engine (Align + Anchors), host object, resize handling, theme basics, input manager (hover, click, capture, focus, tab order) | A hand-coded form with top/left/client panels and anchored buttons reflows correctly on window resize; Tab cycles focus |
| **M2 Serialization** | Registry, published metadata, JSON load/save, event binding (both styles) | A form round-trips JSON → tree → JSON with no diffs; missing handlers produce warnings |
| **M3 Tier 1 controls** | Panel, Label, Button, CheckBox, Splitter, Viewport, Edit | Viewport pans/zooms and calls user draw code; Edit supports caret, selection, clipboard |
| **M4 PropertyGrid + undo** | PropertyGrid with inferred and metadata-driven editors; undo helper | **Sample: tiny tile editor** built by hand — tile palette, map viewport, property grid for selected tile, save/load JSON, undo |
| **M5 Tier 2 controls** | TreeView, Tabs, ListBox, ComboBox + popup layer, MenuBar/popup menus, Toolbar, SpinEdit, Slider, ColorPicker, SpritePicker | Menus and dropdowns render above everything and close correctly on outside click/Escape |
| **M6 Designer MVP** | Section 14 MVP features | The M4 tile editor's form can be recreated entirely in the designer and loads in the sample |
| **M7 Release prep** | Samples (tile editor, dialogue editor, data table editor), docs, .yymps package, dark/light themes | A new user can import the package and run a sample in under 10 minutes following the README |

**Key checkpoint:** M4. If a usable tile editor can be built by hand with the library, the core design is proven.

---

## 17. Code conventions

- Prefix all global functions, macros, and assets with `gmforms_` / `GMF_` to avoid collisions with user projects.
- Constructors named in PascalCase without prefix inside the library namespace only if collision-safe; otherwise `GMF_Button`, etc. (**Open question Q1**).
- Methods and variables in `snake_case`.
- Use `static` methods on constructors to avoid per-instance function copies.
- No global mutable state except a single `global.gmforms` struct (theme, focus, registry, popup layer).
- Every public function has a JSDoc-style comment (`/// @func`, `/// @param`, `/// @returns`) so GameMaker's autocomplete shows it.
- Fail softly: log warnings via a `gmforms_log` function instead of crashing the user's tool.

---

## 18. Open questions

- **Q1** Constructor naming: `Button` vs `GMF_Button` (collision risk vs readability).
- **Q2** Should the optional UI Layer shell be part of v1, or just documented as a pattern?
- **Q3** Should the Anchors "neither left nor right" case keep proportional position (Delphi) or just keep left?
- **Q4** Minimum supported GameMaker version.
- **Q5** License (MIT? free + paid pro controls?) and distribution (GitHub, itch.io, GameMaker Marketplace).
- **Q6** Should Splitter follow Delphi's "resize the previous aligned sibling" rule exactly, or target an explicit control?
- **Q7** Final product name.

---

## 19. Competitive landscape

- **ImGui wrappers for GML** — immediate mode; great for quick debug panels; awkward for polished, persistent tool UIs; no visual designer.
- **Emu (community GML UI library)** — retained mode, built in code; no visual designer, no Delphi-style docking.
- **GameMaker UI Layers / Flex Panels** — good for HUDs and menus; flexbox only; no tool-style widgets (text boxes, trees, grids).

**Differentiator:** visual designer + Delphi Align/Anchors + Viewport + PropertyGrid, aimed specifically at game tools.

---

## 20. Suggested first session task

Implement **M1**: the `Control` base constructor, `Form`, `Panel`, and `Button` (drawn with plain rectangles, no theme yet), the Align + Anchors layout engine per Section 6, the host object with resize handling, and basic mouse hover/click. Include a test room with a hand-built form demonstrating top/bottom/left/right/client panels and anchored buttons.
