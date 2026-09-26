# CLAUDE.md — GMForms

Delphi-style RAD form system for GameMaker (runtime library + later a visual designer).

- **Source of truth for goals, decisions (D1–D12), milestones (M1–M7) and open questions:** `gamemaker-form-designer-plan.md`. Ask before contradicting a listed decision.
- **What's built, the layout rules, and usage:** `README.md`.

## Status

- **M1 (runtime core) is done.** It was tested in GameMaker LTS 2026 (IDE 2026.0.0.16, runtime 2026.0.0.23) on Windows.
- **M2 (serialization) is done and verified.** Registry, published property metadata, JSON load/save (`scripts/gmforms_serialize`), and name-bound event handling are all in. Confirmed by an actual headless build+run via `gm-cli` (see "Building, running and testing" below): `[GMForms tests] 144 passed, 0 failed`, and every M2 warning path (missing handler, unknown class, bad version, wrong format) logged exactly as designed.
- **M3 (Tier 1 controls) is done and verified.** CheckBox, Splitter, Viewport, Edit are all in, plus the small core additions Edit needed (`key_char` hook, clipboard-key + typed-character forwarding — see "M3 notes" below). `[GMForms tests] 208 passed, 0 failed` via `tools/gmtest.sh`; Viewport's surface/camera rendering was additionally confirmed with a manual screenshot check (the automated suite can only verify its coordinate math, not actual pixels).
- **M4 (PropertyGrid + undo) is done and verified headlessly.** `GMF_UndoStack` (`scripts/gmforms_undo`), `GMF_PropertyGrid` (`scripts/gmforms_controls_propgrid`), and the hand-built tile editor sample (`scripts/demo_tiles`, `rm_demo_tiles`, now the **first room**). `[GMForms tests] 309 passed, 0 failed` via `tools/gmtest.sh`; the sample's rendering was checked with a scripted screenshot run (`DEMO_TILES_CAPTURE`, see M4 notes). Hands-on mouse/keyboard use of the sample (painting strokes, dragging the grid divider/scrollbar) has **not** been exercised yet — do that in the IDE before building on it.
- **M5 (Tier 2 controls) is done and verified headlessly.** It adds a popup layer in `GMF_Form` and ListBox, TreeView, ComboBox, SpritePicker (`scripts/gmforms_controls_lists`), MenuBar + PopupMenu with context menus and shortcuts (`scripts/gmforms_controls_menus`), TabControl + Toolbar (`scripts/gmforms_controls_containers`), and SpinEdit, Slider, ColorPicker (`scripts/gmforms_controls_values`). The PropertyGrid now uses dropdowns for enum/sprite values and the colour popup for colours. `[GMForms tests] 433 passed, 0 failed`. The acceptance criterion ("menus and dropdowns render above everything and close correctly on outside click/Escape") is covered by tests that drive the real input path (`simulate_click`/`simulate_key`) and by scripted screenshots of both demos (`DEMO_TILES_CAPTURE`, `DEMO_M5_CAPTURE`). None of this has been used by hand with a real mouse and keyboard yet.
- **M6 (Designer MVP) is done and verified headlessly.** The designer (`rm_designer`, scripts in the `Designer` folder) is built with the library itself. It has a palette, a structure tree, a design canvas (select, move, resize with snap, create, reparent, nudge, delete, restack, tab pages, context menu), a Properties/Events inspector, snapshot undo/redo, New/Open/Save, and handler-stub generation. **Acceptance:** `designer_script_tile_editor()` rebuilds the tile editor's form through the designer's own operations. Its output is the Included File `datafiles/tile_editor.gmform.json`, which the tile editor now loads, binding every event by name. A test rebuilds it and compares the result byte for byte. `[GMForms tests] 500 passed, 0 failed`, plus scripted screenshots of the designer (`DESIGNER_CAPTURE`). Real mouse and keyboard use hasn't been tried by hand yet, and neither have the native Open/Save dialogs (see M6 notes about the file sandbox).
- **Next: M7 Release prep** (samples, docs, .yymps package).
- Provisional answers to open questions, both easy to change:
  - **Q1:** constructors use the `GMF_` prefix.
  - **Q3:** a control with no left/right (or top/bottom) anchor keeps a proportional centre.

## Project layout

| Path | Contents |
|---|---|
| `scripts/gmforms_core` | `global.gmforms`, `gmforms_log`, `gmforms_create(ctor, props)`, rect / scissor-stack / draw helpers |
| `scripts/gmforms_theme` | `gmforms_theme_dark()` (default), `gmforms_theme_light()` |
| `scripts/gmforms_control` | `GMF_Control`: tree, setters, Align + Anchors layout engine, hit test, clipped drawing, input hooks |
| `scripts/gmforms_form` | `GMF_Form`: root + input manager. Call `update()` in Step and `render()` in Draw GUI |
| `scripts/gmforms_controls_basic` | `GMF_Panel`, `GMF_Button`, `GMF_Label`, `GMF_CheckBox`, `GMF_Splitter` |
| `scripts/gmforms_controls_viewport` | `GMF_Viewport`: pannable/zoomable camera, own surface, matrix-transformed user drawing |
| `scripts/gmforms_controls_edit` | `GMF_Edit`: single-line text, caret, selection, clipboard, scroll, password mode |
| `scripts/gmforms_controls_lists` | `GMF_ListBase` (shared), `GMF_ListBox`, `GMF_TreeView`, `GMF_ComboBox`, `GMF_SpritePicker`, `GMF_DropDownList` + `gmforms_dropdown_open()`, sprite helpers |
| `scripts/gmforms_controls_menus` | `GMF_MenuBar`, `GMF_PopupMenu`, `gmforms_menu_item` / `_separator` / `gmforms_submenu`, shortcut parsing |
| `scripts/gmforms_controls_containers` | `GMF_TabControl` + `GMF_TabSheet`, `GMF_Toolbar` + `GMF_ToolSeparator` |
| `scripts/gmforms_controls_values` | `GMF_SpinEdit`, `GMF_Slider`, `GMF_ColorPicker` + `GMF_ColorPopup` / `gmforms_color_popup_open()` |
| `scripts/gmforms_controls_propgrid` | `GMF_PropertyGrid`: inferred / metadata-driven / `bind_control` editors; colour and number helpers |
| `scripts/gmforms_undo` | `GMF_UndoStack`: command undo/redo, groups, `set_value`, `push_snapshot`; `gmforms_get_value` / `gmforms_put_value` |
| `scripts/gmforms_host` + `objects/obj_gmforms_host` | Host object. Create one with `gmforms_host_create(form)` |
| `scripts/gmforms_serialize` | Registry-driven JSON: `gmforms_form_to_json`, `gmforms_save_form`, `gmforms_load_form`/`gmforms_load_form_json`, `gmforms_value_equals` |
| `scripts/gmforms_tests` | Headless test suite `gmforms_run_tests()` (500 checks). Runs in the first room's Create event when `GMF_RUN_TESTS` is true |
| `scripts/demo_tiles` + `objects/obj_demo_tiles` + `rooms/rm_demo_tiles` | Tile editor sample (first room). Since M6 its UI is loaded from `datafiles/tile_editor.gmform.json`, with events bound by name to its `handlers` struct. `DEMO_TILES_CAPTURE` runs a scripted session, saves `m4_*.png`, then quits |
| `scripts/designer_canvas` | `GMF_DesignCanvas`: shows the designed form (a real `GMF_Form` whose `update()` is never called) and edits it: select, move, resize, create, reparent, nudge, delete, restack, tab pages |
| `scripts/designer_app` + `objects/obj_designer` + `rooms/rm_designer` | `DesignerApp`: the designer UI, snapshot undo, files, inspector wiring. `DESIGNER_EXPORT_TILES` re-exports the tile editor form |
| `scripts/designer_codegen` | Handler stub generation: `gmforms_design_handlers_source(form, [existing])` and helpers |
| `scripts/designer_scripts` | `designer_script_tile_editor()` (the M6 acceptance rebuild) and the `DESIGNER_CAPTURE` screenshot script |
| `datafiles/tile_editor.gmform.json` | The tile editor's UI, made with the designer; an Included File that `DemoTilesApp` loads |
| `scripts/demo_m5` + `objects/obj_demo_m5` + `rooms/rm_demo_m5` | M5 controls gallery (tile editor: File > Other demos). `DEMO_M5_CAPTURE` makes the first room jump there, saves `m5_*.png`, then quits |
| `scripts/demo_m1` + `objects/obj_demo_m1` + `rooms/rm_demo_m1` | M1 layout demo (tile editor: File > Other demos). `GMF_DEMO_CAPTURE` saves screenshots, then quits |

## Code conventions

- **Prefixes:** global functions and macros use `gmforms_` / `GMF_`. Constructors are `GMF_PascalCase`. Methods and variables are `snake_case`. Internal members start with `_`.
- **Global state:** the only global is `global.gmforms`. Get it through `gmforms_init()`.
- **Methods:** use `static` methods on constructors. Subclasses override statics by redeclaring them. GML has no `super`: call a base version with `gmforms_inherited(self, GMF_Base, "name")(args)`, where `GMF_Base` is the constructor that *directly* defines the method. Alternatively, split the base method into a hook the subclass can call; `GMF_Edit._edit_key` / `_edit_mouse_down` exist so `GMF_SpinEdit` doesn't fire user events twice. Input hooks such as `key_down` must still fire the user's `on_*` event.
- **Docs:** every public function gets a `/// @func` / `/// @param` / `/// @returns` / `/// @desc` comment.
- **Errors:** fail softly with `gmforms_log(...)` rather than crashing.
- **Event handlers:** the first argument is always the sender control.

## Layout-engine facts (easy to get wrong)

- **Coordinates:** `left`/`top` are relative to the parent's top-left corner. Padding affects **aligned** children only. Anchored children use the parent's full size.
- **Design size:** anchors are captured lazily, on a control's first layout, against the parent's size at that moment. `GMF_Form` runs one layout pass at its design `width`/`height` before the first `set_bounds()`, so design-time distances are what get captured.
- **Moving controls from code:** use `set_bounds()`, `set({...})`, `set_align()`, `set_anchors()`, `set_visible()` or `set_enabled()`. They invalidate layout and re-capture anchors. Assigning `left`/`width` directly on an anchored control is overwritten by the next layout.
- **What the layout writes:** it writes the computed rect back into `left/top/width/height`, and the absolute GUI position into `_sx/_sy`.
- **Hiding or disabling a control** clears hover, capture and focus inside it (`GMF_Form._forget_subtree`).
- **Splitter (M3):** resizes the nearest *earlier* visible sibling with the same `align` (implicit, Delphi-exact — resolves plan Q6) by writing that sibling's `width`/`height` field directly and calling `parent.invalidate_layout()`. Sign convention, traced against `arrange_children`'s actual iteration order (each align group places children at the current outer edge before shrinking the rect, so the sibling added *before* the splitter always sits at the outer edge): a **left/top** splitter grows its target when dragged *away from* center; a **right/bottom** splitter shrinks its target when dragged *toward* it. Drag tracking gates on `get_form().capture == self`, not `is_pressed()` — a thin splitter is trivially left behind by fast mouse movement, and `is_pressed()` also requires `hover == self`.

## GameMaker gotchas found during M1 testing

- **Filled rectangles:** a filled `draw_rectangle(x1,y1,x2,y2,false)` covers `[x1,x2) x [y1,y2)`, so use `x + w`, not `x + w - 1`. With `-1`, 1px strips don't draw at all. Always go through `gmforms_draw_rect` / `gmforms_draw_frame`.
- **Letterboxed GUI:** with "Keep aspect ratio" on, GameMaker draws the GUI layer inside the letterboxed application-surface rect. That breaks 1:1 pixels and scissor clipping. The host fixes it by calling `surface_resize(application_surface, w, h)` together with `display_set_gui_size(w, h)` on every window resize. Keep that.
- **Scissor coordinates:** `gpu_set_scissor` works in render-target pixels. `render()` works out the GUI → target scale from `gpu_get_scissor()` at the start of Draw GUI (normally 1).
- **Built-in font:** it's wide, so captions longer than their control are clipped (intentional). Theme fonts come in a later milestone.
- **Screen capture:** `screen_save("x.png")` writes to the save area `%LOCALAPPDATA%\GMForms\` (sandbox is on). This is how to check the rendering without looking at the game window.
- **`draw_set_font(-1)`:** avoid it; `render()` only restores the font when it isn't -1.

## GML gotchas found during M4

- **`self` inside a struct literal is the new struct**, not the enclosing method's struct: `undo.push({ grid: self, ... })` stores the command itself. Capture it first: `var _grid = self; undo.push({ grid: _grid, ... })`. (Other bare field names inside the literal still resolve in the enclosing scope.) Functions written *inside* a struct literal are bound to that literal, which is what makes `{ cell, old_value, do_fn: function() { cell.t = old_value; } }` commands work.
- **`is_callable(x)` is true for plain numbers that are valid script indices**, so `12` or `true` can count as "callable". To detect function-valued fields, use `is_method()`. `is_callable(on_click)` on event fields is still fine because they're either `undefined` or a method.
- **A `\` anywhere in a `#macro` line's trailing comment continues the macro onto the next line**, silently eating the next `#macro`. Don't put Windows paths with backslashes in macro comments.

## GML gotchas found during M6

- **`json_stringify` key order isn't stable between runs.** The same struct can serialize with its keys in a different order in another run. Form files and undo snapshots go through `gmforms_json_stringify` (deterministic key order, whole numbers without `.0`). Use it wherever output is compared or committed to git.
- **`buffer_string` writes a trailing NUL**, so git sees the file as binary. Write text with `gmforms_write_text_file` (`buffer_text`) and read it with `gmforms_read_text_file`, which handles both kinds.
- **GML has no scientific-notation literals.** `1e15` is a compile error; write `1000000000000000`.
- **`struct_exists(handlers, name)` doesn't see static methods**, so a handlers struct passed to the loader must hold its methods as instance fields (e.g. `handlers = { btnSave_Click: method(_app, function(_s) {...}) }`, with `var _app = self;` captured first).

## Editing the project from outside the IDE

- **The IDE can overwrite your edits.** If the project is open in the GameMaker IDE, it notices external file changes after a few seconds. If Run is pressed before that, it can **write its in-memory copy back over your edit**. Wait about 10–15 s after editing, then re-check the file on disk before running.
- **Adding a script or object resource — use `tools/add-resource.sh`, don't hand-edit.** It does the three things the IDE needs, or it won't see the resource — a folder with `.gml`/`.yy` files from GameMaker's own template, an entry in `GMForms.yyp` → `resources` (kept in the file's existing sort order: grouped by top-level folder alphabetically — `objects` < `rooms` < `scripts` — then by name within each group, *not* creation order), and a matching entry in `GMForms.resource_order` with every `order` renumbered:
  ```sh
  tools/add-resource.sh script <name> [--folder=GMForms|Demo]
  tools/add-resource.sh object <name> [--folder=GMForms|Demo] [--events=create,step,draw,drawgui,cleanup]
  ```
  Verified against the real asset compiler while building the tool — a scaffolded script and object both compiled cleanly (`sc=238`/`ob=3`). Run `tools/gmtest.sh --compile-only` after scaffolding to confirm. Rooms aren't supported (more involved `.yy` shape) — do those by hand: a folder with the `.gml`/`.yy` files (copy an existing `.yy` as a template), an entry in `GMForms.yyp` → `resources`, and one in `GMForms.resource_order`. Scripts go under folder `GMForms` (library) or `Demo`. Folders are virtual: `folders/GMForms.yy`.
- **Object event files and their `eventList` entries:**

  | File | `eventType` | `eventNum` |
  |---|---|---|
  | `Create_0.gml` | 0 | 0 |
  | `Step_0.gml` | 3 | 0 |
  | `Draw_0.gml` | 8 | 0 |
  | `Draw_64.gml` (Draw GUI) | 8 | 64 |
  | `CleanUp_0.gml` | 12 | 0 |

- **File format:** `.yy`/`.yyp` files are GameMaker's JSON dialect, with trailing commas and CRLF line endings. Keep that format.
- **Game Options** come from `options/`. Window resize is enabled for Windows, macOS and Linux (required for reflow).

## Building, running and testing

- **From the IDE:** GameMaker LTS2026 is installed at `C:\Program Files\GameMaker-LTS2026\GameMaker-LTS2026.exe`. F5 runs the project. The Output window shows `[GMForms tests] N passed, M failed` right after "About to startroom". Keep that at 0 failed, and add tests to `gmforms_tests.gml` for new behaviour.
- **Headless build+run — `tools/gmtest.sh`.** Wraps [YoYoGames/gm-cli](https://github.com/YoYoGames/gm-cli) (`npx @gamemaker/gm-cli@latest`, which itself wraps Igor, auto-downloads the matching runtime/toolchain, and works with a free guest license — no `login` needed) so you don't have to hand-reconstruct the backgrounding/timeout/ANSI-stripping dance every time. This is a real, working headless edit → build → read-results loop, confirmed against this repo:
  ```sh
  tools/gmtest.sh                  # build + run, print the "[GMForms tests] N passed, M failed" line, exit 0 iff 0 failed
  tools/gmtest.sh --compile-only   # asset-compile check only (no game launch) — faster, good for a quick syntax check
  tools/gmtest.sh --timeout=60     # override the 90s default wait for the result line
  tools/gmtest.sh --log            # print the whole cleaned log: use it to read a runtime crash (FATAL ERROR + stack)
  tools/gmtest.sh --until="capture dir" --timeout=150   # keep running until that log line (screenshot runs) or a crash
  # Scripted runs that start elsewhere: DEMO_M5_CAPTURE, DESIGNER_CAPTURE and DESIGNER_EXPORT_TILES make the first room jump to their room.
  ```
  This is the tool to reach for whenever GML changes need verifying — don't fall back to "can't test without the IDE." Use it after *any* GML edit, the same way you'd run a test suite in any other language.
  - **What it does under the hood**, if it ever needs debugging or reproducing by hand: runs `npx --yes @gamemaker/gm-cli@latest run GMForms.yyp --target=windows --runtime=vm --verbose` in the background (it never exits on its own — the demos only self-quit when their `*_CAPTURE` macro is `true`), polls the log for the `[GMForms tests] N passed` summary or the process dying early (build failure), then kills it. It must wait for the *summary*: `[GMForms tests] FAIL ...` lines come first, and before M4 the script stopped at the first one and killed the game mid-suite, which looked like a crash. A runtime crash before the summary shows up as "no '[GMForms tests]' line" plus the full log.
  - **Capture runs:** set the demo's `*_CAPTURE` macro to `true`, run `tools/gmtest.sh --log --until="capture dir" --timeout=150`, read the PNGs from `%LOCALAPPDATA%\GMForms\`, then set the macro back to `false`. Without `--until`, the script kills the game as soon as the test summary prints. Also note the summary prints *before* the demo forms are built, so a plain `gmtest.sh` run won't catch a crash inside a demo; a capture run will.
  - **Killing the game window: don't trust bash's PID.** gm-cli chains `npx -> node -> Igor.exe -> Runner.exe`; on git-bash/Windows, `$!` from backgrounding that command does **not** reliably map onto the real Windows process tree, so `taskkill //T //PID "$PID"` is a silent no-op and the actual game window (`Runner.exe`) is left running as an orphan. The fix that works: `taskkill //F //IM Runner.exe` and `//IM Igor.exe` by name after the result line is captured — safe because both are GameMaker-exclusive binary names (unlike `node.exe`, never kill that broadly). `gmtest.sh` already does this; verified across repeated runs that no `Runner`/`Igor` process or window survives it.
  - Needs Node; this machine has v22 vs. the tool's stated `>=24` requirement — it still works, just prints an `EBADENGINE` warning to ignore.
  - First run per machine downloads Igor + the runtime + a license into `<project>/.gmcache/` (self-`.gitignore`d, safe to leave) and `%LOCALAPPDATA%\GameMakerCLI\cache\`; later runs reuse that cache and are much faster (a few seconds).
  - `--target`/`--runtime` are hardcoded to `windows`/`vm` in the script (matches "GameMaker LTS 2026 runtime 2026.0.0.23"); edit `tools/gmtest.sh` directly if another target is ever needed.

## Git

- **Line endings:** `core.autocrlf=false` is set for this repo, so files keep their mixed line endings as written. `.gitignore` excludes `/cache/`, `/output/`, `*.old` and OS files.
- **Commits:** the user commits himself unless he asks otherwise.

## M2 notes (serialization — done)

Scope from the plan: registry, published property metadata, JSON load/save, and event binding (both styles). Done when a form round-trips JSON → tree → JSON with no differences, and missing handlers produce warnings. All of this is implemented and verified (see Status above and "Building, running and testing" for how it was run headlessly).

- **Registry:** `gmforms_init()` (in `gmforms_core`) registers the four built-in classes by `class_name`; `gmforms_register(name, ctor)` is public so a user's own control classes can add themselves.
- **Published metadata:** `gmforms_base_published()` (in `gmforms_control`) returns Control's list; each subclass does `array_concat(gmforms_base_published(), [...])` to add or override entries (`gmforms_serialize` dedupes by name, last one wins — that's how e.g. `GMF_Button` changes `width`'s default from 100 to 80). Only non-default values are written; only fields listed in `published` are ever read or written, which is what actually enforces "never serialize `parent`/`_*`/functions" rather than a generic field-exclusion pass.
- **Anchored controls:** `gmforms_control_to_struct` reads `left`/`top`/`width`/`height` from `_anc` (the captured design rect) once `_anchor_captured` is true, instead of the live (possibly resized) values.
- **Event binding:** JSON keys like `"onClick"` map to the field `on_click` via a generic camelCase→snake_case conversion (`__gmforms_event_field`), so a custom control's own `onWhatever` published entries don't need to spell out the field name. Names are resolved with `struct_get`; a name missing from the handlers struct logs one warning (deduped per load call) and leaves the field unset, but the name is kept in `_ev_names` so re-saving doesn't drop it.
- **Form files:** `gmforms_save_form`/`gmforms_load_form` exist and use plain `buffer_string` I/O, but no `.gmform.json` sample has been added to `datafiles/` or wired into the `.yyp`'s `IncludedFiles` yet — the round-trip is currently only exercised in-memory by the test suite (`gmforms_form_to_json` / `gmforms_load_form_json` on a string). Do that wiring when the demo actually needs to load a file.

## M3 notes (Tier 1 controls — done)

CheckBox, Splitter and Viewport were pure additions. Edit needed two small, additive-only core changes first — verified inert (same passed/failed count) via `tools/gmtest.sh` *before* Edit existed, then confirmed working once it did.

- **Text-input plumbing (new, for Edit):** before M3, nothing forwarded printable characters or clipboard shortcuts to any control — `GMF_Form._update_keys()` only forwarded a hardcoded `_nav_keys` array of navigation vkeys. M3 added: (1) a `key_char(ch)` no-op hook on `GMF_Control` (same pattern as `key_down`/`key_up`); (2) a `_clipboard_keys = [ord("A"),ord("C"),ord("X"),ord("V")]` array, forwarded to `key_down` **only while Ctrl is held** — plain "A"/"C"/"X"/"V" never reach `key_down`, so this changes nothing for controls that don't check `keyboard_check(vk_control)` themselves; (3) per-frame forwarding of GameMaker's `keyboard_string` buffer to `focused.key_char(ch)` for each printable character (`ord(ch) >= 32`), clearing it after reading. **`GMF_Form` is the sole consumer of `keyboard_string`** — a future control needing typed text should implement `key_char`, never read `keyboard_string` directly (there's no second-consumer story here).
- **Splitter:** see the "Layout-engine facts" bullet above for the resize mechanic and sign convention (this is the resolution to plan Q6).
- **Viewport:** camera is top-left-anchored (`cam.x/y` = world point at the viewport's local `(0,0)`); see `gamemaker-form-designer-plan.md` section 10's implementation-notes addendum for the exact `screen_to_world`/`world_to_screen`/`zoom_at` formulas. `on_mouse_down`/`on_mouse_up`/`on_mouse_move` deliberately reuse the base `GMF_Control` event field names but carry world-space coordinates for this control — not a bug, matches the plan's own JSON example. The surface/matrix draw pipeline was verified with a manual screenshot (temporarily adding a Viewport with a grid and a couple of known-position rectangles to the M1 demo, flipping `GMF_DEMO_CAPTURE`, then reverting both) — the automated suite only checks the coordinate math, not actual pixels, so re-verify visually if this pipeline changes. Known limitation: no control-level `destroy()` hook exists, so a Viewport's surface leaks if removed mid-session (not yet in scope — GameMaker frees surfaces at room end regardless).
- **Edit:** single-line only (Memo/multi-line is Tier 3). Actions (`select_all`/`copy`/`cut`/`paste`/`_move_caret`) are plain callable methods, not buried behind live keyboard state, so tests exercise them directly without faking real keyboard/clipboard input — same pattern the suite already used for Tab (`focus_next` called directly). `copy()`/`cut()`/`paste()` wrap the real `clipboard_*` calls in `try/catch` (fail softly); the automated tests cover the text-buffer editing logic but do **not** assert real OS clipboard round-trip content.

## M4 notes (PropertyGrid + undo — done)

- **`GMF_UndoStack`** (plan section 13): `push(cmd)` records a change that has already been made. `execute(cmd)` runs `do_fn` and then records it. `set_value(target, key, value, [label], [after_fn])` is the one-liner for a field or array-index write, and `push_snapshot(label, before, after, restore_fn)` is the JSON-snapshot fallback. `begin_group`/`end_group` nest: the outer label wins, empty groups record nothing, and `undo()` closes open groups first. Pushes made *while* an undo/redo runs are ignored (`_busy`). That makes an `on_change` handler that records undo steps safe, even though undo/redo also fire it. `limit` (default 200) drops the oldest steps.
- **`GMF_PropertyGrid`**: rows are rebuilt lazily (`_rows_dirty`) from the bound target. **Values are read live every frame**, so only changes to the target's *shape* need `refresh()`. Row paths (`"stats.hp"`, `"tags.0"`, categories `"#Name"`) key the expand/collapse state and the in-place edit. The metadata entry fields (type, label, category, readonly, values/labels, min/max/step or range, fields, set_fn) are documented at the top of the script. Inferred numbers are always `"real"`, because inferring `"int"` would silently round a later `1.5`.
- **In-place editor:** a private `GMF_Edit` held in `_editor`. It is **not a child**, because a child would be serialized with the form. Its `parent` is set to the grid so `is_enabled()`/`get_form()` work, and `GMF_Edit._focus_proxy` (new in M4) makes `is_focused()` follow the grid's focus so the caret and focus frame draw. The grid positions it (`_place_editor` writes `_sx/_sy` directly) and forwards key_char/key_down/mouse input to it. Enter commits, Escape cancels, Up/Down commit and move, focus loss commits, and `bind()` commits to the old target before switching.
- **Undo integration:** set `grid.undo = stack` and every committed edit is pushed as one step. Undo/redo re-fire `on_change(sender, key, old, new, owner)`, where `owner` is the struct actually written (it differs from the target for nested rows).
- **`bind_control(ctrl)`** is the future Object Inspector (D8). It shows the published non-event properties grouped into Identity/Layout/Behavior/Properties and writes them through `ctrl.set({...})`. Nested writes (e.g. `margin.l`) call `root.set({})` so layout re-runs.
- **Other additive core changes:** `GMF_Button.down` (a latched pressed look for tool buttons; published, default false). `GMF_Viewport` now declares `on_draw`/`on_wheel` (they were read but never initialised). `PropertyGrid` is registered in `gmforms_init()`. Both themes have new `grid_*` and `scrollbar*` keys, which a custom theme needs too.
- **Tile editor sample (`demo_tiles`):** the document is plain structs (`cols/rows/tile_size/info/tiles/cells`), saved with `json_stringify` to `tilemap.json` in the save area. Tile types use a metadata grid (categories, colour, range), cells an enum grid with labels, and map info an **inferred** grid (nested struct + array). Each paint stroke is one undo group built from `undo.set_value`. Clear uses `push_snapshot`, and its restore writes into the **existing** cell structs; replacing them would orphan every older undo step that references a cell. New/Open replace the document, so they call `undo.clear()`. `DemoTileSwatch` shows a user control subclass (unregistered, so not serializable). Tests run only in `room_first`: both demo objects check `room == room_first`.

## M5 notes (Tier 2 controls — done)

- **Popup layer (`GMF_Form`):** `show_popup(ctrl, x, y, owner)`, `close_popup(ctrl)` (also closes everything above it, e.g. submenus), `close_popups()`, `is_popup_open()`, `top_popup()`. Popups are ordinary controls whose `parent` is set to the form but which are **not** in `children`, so they're never serialized. They are laid out in `layout()`, hit-tested first in `control_at()`, and drawn after the tree in `render()` with a full-GUI scissor and a drop shadow. The rules: a press outside every popup closes them all and is **consumed** (Windows menu behaviour, which is also what makes clicking an open combo close it); Escape closes the top popup; Tab closes all popups and then moves focus; navigation keys go to the top popup instead of the focused control; typed text is discarded while a popup is open. Hiding, disabling or removing a popup's `owner` closes it (`_forget_subtree`). `popup_closed()` is a new base hook.
- **Input refactor:** `update()` is now `_update_hover` → `_mouse_press` / `_mouse_release` per button → `_mouse_move_to` → `_mouse_wheel_at` → `_update_keys`, with `_route_key_down` for each pressed key. `simulate_click(x, y, [btn])`, `simulate_move` and `simulate_key` run the *same* code, and the tests use them; prefer them to calling control hooks directly when testing anything that involves popups or focus.
- **Context menus:** `control.popup_menu = gmforms_create(GMF_PopupMenu, { items: [...] })`. The form opens it on a right-button *press* (after `mouse_down`, so ListBase/TreeView have already selected the row under the mouse). Items fire `on_click(sender, item)`: sender is the menu bar for bar menus, the root PopupMenu for context menus, and `popup_component` is the right-clicked control.
- **Shortcuts:** a Ctrl/Alt + key or F1–F12 press is offered, after the focused control has had its clipboard keys, to `handle_shortcut(key, ctrl, shift, alt)` on every visible, enabled control, depth first (`GMF_Form.dispatch_shortcut`). `GMF_MenuBar` matches its items' `shortcut` / `alt_shortcut` strings. Disabled or invisible items don't match. Menus are code-only (items hold functions) and are not serialized.
- **Dropdown sources:** `gmforms_dropdown_open(owner, source, lx, ly, w, h, [row_h], [max_rows])` takes any struct with `_dd_count/_dd_draw/_dd_selected/_dd_pick`. ComboBox and SpritePicker are their own sources; the PropertyGrid builds small struct-literal sources (`_open_enum_dropdown`, `_open_sprite_dropdown`). `gmforms_color_popup_open` works the same way with `_cp_get/_cp_set(colour, final)`. The grid previews live while `final` is false and records one undo step on release.
- **TabControl** overrides `client_rect()` (pages sit below the tab strip) and `arrange_children()`, which re-syncs page visibility with `tab_index` before calling the base version through `gmforms_inherited`. That's what makes a directly assigned or JSON-loaded `tab_index` work. **Toolbar** overrides `arrange_children()` completely (left-to-right flow; children's align/anchors are ignored).
- **SpinEdit** subclasses Edit: `_inset_r` (new on `GMF_Edit`) keeps text out of the button area, `_fire_change` is a no-op so typing doesn't fire `on_change` (commits do), and `draw()` re-syncs the text when `value` was assigned directly. Its `text` is not published; `value` is.
- **TreeView** nodes are plain JSON-able structs `{ text, nodes, expanded, data }` without parent links (those would make `json_stringify` recurse); parents are found by search. Rows are flattened lazily; call `refresh()` after mutating nodes directly.
- **SpritePicker** lists `asset_get_ids(asset_sprite)` unless `sprites`/`labels` are set. `sprite` is a runtime reference, so it isn't published. The demos make their sprites at runtime (`demo_m5_make_sprite`) because the project has no sprite assets.
- **Other additive changes:** `GMF_Control.popup_menu`, `handle_shortcut()`, `popup_closed()`; `gmforms_inherited()` in core; new theme keys `list_*`, `menu_*`, `tab_*`, `slider_*`, `popup_shadow` (both themes). The tile editor now has a MenuBar, a Toolbar and an inspector context menu; its old hand-written Ctrl+Z/Y/S/O handling is gone.

## M6 notes (Designer MVP — done)

- **Design mode = the runtime, not updated.** `GMF_DesignCanvas` lays the designed `GMF_Form` out itself (`_layout_target`: design pass, then `_sx/_sy` = canvas + `offset_x/y`) and draws it, but never calls its `update()`, so no events fire. It hit-tests with its own `_hit` (which can exclude the dragged subtree). Containers are Form, Panel, TabSheet and Toolbar, and a TabControl counts as its active page; a custom class can set `design_container = true`. Invisible controls aren't drawn or hit, so select them in the structure tree.
- **Every edit is one snapshot.** `on_modified` → `DesignerApp.commit(label)` serializes the whole form and pushes `push_snapshot(before, after)` if it changed. Undo/redo rebuild the form from JSON and reselect by name. Old control structs are thrown away on every undo, so never hold on to a designed control across a commit/undo; look it up again with `target.find(name)`.
- **Anchors after a form resize.** Changing the design size moves anchored controls, so `set_form_size` / the form handle reset `_anchor_captured` on the whole tree. The current rects then become the new design rects, which is what gets saved.
- **Inspector.** Properties use `props_grid.bind_control(selected)`: renames are validated for uniqueness (refused and reverted if taken), and `MenuBar.menus` is an editable list of items with nested submenus (+/× buttons, caption / shortcut / onClick name). Events use a proxy struct (event → handler name) whose `set_fn` writes `ctrl._ev_names`. Double-clicking an empty event gives `<control>_<Event>`, and double-clicking an empty menu-item onClick gives `<menubar>_<Caption>_Click`.
- **Library changes for M6 (additive).**
  - `MenuBar.menus` is published (type `"menus"`; items saved with `onClick` handler *names*, `item.on_click_name`).
  - The loader stays silent about unresolved names when no handlers struct is passed (the design-time case).
  - PropertyGrid: `element` / `resizable` / `new_element` / `label_field` metadata for arrays, `add_element` / `remove_element`, `on_dbl_click`, and rows know their `parent_row`.
  - Core: `gmforms_write_text_file` / `gmforms_read_text_file` and `global.gmforms.log_count` (tests assert "no warnings").
  - Serializer: `gmforms_json_stringify`.
  - Form: `simulate_drag`.
- **Files and the sandbox.** Open/Save/Generate use `get_open_filename_ext` / `get_save_filename_ext`. With the Windows file system sandbox on (it is), reading or writing outside the save area may fail; the designer reports that in the status bar instead of crashing. **This hasn't been verified**, because native dialogs can't run headless. "Save to the save area", "Open the tile editor's form" (Included File) and "Copy handler stubs" (clipboard) always work. Disabling the sandbox (Game Options → Windows) is the documented alternative (plan section 15).
- **Regenerating the tile editor form:** set `DESIGNER_EXPORT_TILES` to `true`, run `tools/gmtest.sh --until="capture dir" --timeout=150`, copy `%LOCALAPPDATA%\GMForms\tile_editor.gmform.json` to `datafiles/`, delete the save-area copy (it would shadow the Included File), and set the macro back. The "designer rebuild matches it byte for byte" test fails until you do this after changing `designer_script_tile_editor` or the serializer.
- **Not in the MVP (plan "Later"):** live preview, multi-select, align tools, copy/paste, editing context menus. Controls can't be dragged out of a Toolbar's flow except by reparenting them.
