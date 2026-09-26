# CLAUDE.md — GMForms

Delphi-style RAD form system for GameMaker (runtime library + later a visual designer).

- **Source of truth for goals, decisions (D1–D12), milestones (M1–M7) and open questions:** `gamemaker-form-designer-plan.md`. Ask before contradicting a listed decision.
- **What's built, the layout rules, and usage:** `README.md`.

## Status

- **M1 (runtime core) is done.** It was tested in GameMaker LTS 2026 (IDE 2026.0.0.16, runtime 2026.0.0.23) on Windows.
- **M2 (serialization) is done and verified.** Registry, published property metadata, JSON load/save (`scripts/gmforms_serialize`), and name-bound event handling are all in. Confirmed by an actual headless build+run via `gm-cli` (see "Building, running and testing" below): `[GMForms tests] 144 passed, 0 failed`, and every M2 warning path (missing handler, unknown class, bad version, wrong format) logged exactly as designed.
- **Next: M3 Tier 1 controls** (Panel/Label/Button already exist; add CheckBox, Splitter, Viewport, Edit).
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
| `scripts/gmforms_controls_basic` | `GMF_Panel`, `GMF_Button`, `GMF_Label` |
| `scripts/gmforms_host` + `objects/obj_gmforms_host` | Host object. Create one with `gmforms_host_create(form)` |
| `scripts/gmforms_serialize` | Registry-driven JSON: `gmforms_form_to_json`, `gmforms_save_form`, `gmforms_load_form`/`gmforms_load_form_json`, `gmforms_value_equals` |
| `scripts/gmforms_tests` | Headless test suite `gmforms_run_tests()` (144 checks). Runs at demo start when `GMF_RUN_TESTS` is true |
| `scripts/demo_m1` + `objects/obj_demo_m1` + `rooms/rm_demo_m1` | M1 demo. `GMF_DEMO_CAPTURE` saves screenshots, then quits |

## Code conventions

- **Prefixes:** global functions and macros use `gmforms_` / `GMF_`. Constructors are `GMF_PascalCase`. Methods and variables are `snake_case`. Internal members start with `_`.
- **Global state:** the only global is `global.gmforms`. Get it through `gmforms_init()`.
- **Methods:** use `static` methods on constructors. Subclasses override statics by redeclaring them; GML has no `super`, so re-implement the base behaviour when you need it. Input hooks such as `key_down` must still fire the user's `on_*` event.
- **Docs:** every public function gets a `/// @func` / `/// @param` / `/// @returns` / `/// @desc` comment.
- **Errors:** fail softly with `gmforms_log(...)` rather than crashing.
- **Event handlers:** the first argument is always the sender control.

## Layout-engine facts (easy to get wrong)

- **Coordinates:** `left`/`top` are relative to the parent's top-left corner. Padding affects **aligned** children only. Anchored children use the parent's full size.
- **Design size:** anchors are captured lazily, on a control's first layout, against the parent's size at that moment. `GMF_Form` runs one layout pass at its design `width`/`height` before the first `set_bounds()`, so design-time distances are what get captured.
- **Moving controls from code:** use `set_bounds()`, `set({...})`, `set_align()`, `set_anchors()`, `set_visible()` or `set_enabled()`. They invalidate layout and re-capture anchors. Assigning `left`/`width` directly on an anchored control is overwritten by the next layout.
- **What the layout writes:** it writes the computed rect back into `left/top/width/height`, and the absolute GUI position into `_sx/_sy`.
- **Hiding or disabling a control** clears hover, capture and focus inside it (`GMF_Form._forget_subtree`).

## GameMaker gotchas found during M1 testing

- **Filled rectangles:** a filled `draw_rectangle(x1,y1,x2,y2,false)` covers `[x1,x2) x [y1,y2)`, so use `x + w`, not `x + w - 1`. With `-1`, 1px strips don't draw at all. Always go through `gmforms_draw_rect` / `gmforms_draw_frame`.
- **Letterboxed GUI:** with "Keep aspect ratio" on, GameMaker draws the GUI layer inside the letterboxed application-surface rect. That breaks 1:1 pixels and scissor clipping. The host fixes it by calling `surface_resize(application_surface, w, h)` together with `display_set_gui_size(w, h)` on every window resize. Keep that.
- **Scissor coordinates:** `gpu_set_scissor` works in render-target pixels. `render()` works out the GUI → target scale from `gpu_get_scissor()` at the start of Draw GUI (normally 1).
- **Built-in font:** it's wide, so captions longer than their control are clipped (intentional). Theme fonts come in a later milestone.
- **Screen capture:** `screen_save("x.png")` writes to the save area `%LOCALAPPDATA%\GMForms\` (sandbox is on). This is how to check the rendering without looking at the game window.
- **`draw_set_font(-1)`:** avoid it; `render()` only restores the font when it isn't -1.

## Editing the project from outside the IDE

- **The IDE can overwrite your edits.** If the project is open in the GameMaker IDE, it notices external file changes after a few seconds. If Run is pressed before that, it can **write its in-memory copy back over your edit**. Wait about 10–15 s after editing, then re-check the file on disk before running.
- **Adding a resource** (script, object or room) needs all three of these, or the IDE won't see it:
  1. its folder with the `.gml`/`.yy` files (copy an existing `.yy` as a template);
  2. an entry in `GMForms.yyp` → `resources`;
  3. an entry in `GMForms.resource_order`.
  Scripts go under folder `GMForms` (library) or `Demo`. Folders are virtual: `folders/GMForms.yy`.
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
- **Headless build+run — use `gm-cli`, not raw Igor.** [YoYoGames/gm-cli](https://github.com/YoYoGames/gm-cli) (`npx @gamemaker/gm-cli@latest`) wraps Igor, auto-downloads the matching runtime/toolchain, and works with a free guest license (no `login` needed). This is a real, working headless edit → build → read-results loop — confirmed working in this repo, not theoretical:
  ```sh
  npx --yes @gamemaker/gm-cli@latest compile GMForms.yyp --target=windows --runtime=vm --verbose   # build only, fails fast on GML errors, doesn't open a window
  npx --yes @gamemaker/gm-cli@latest run     GMForms.yyp --target=windows --runtime=vm --verbose   # builds + launches the Runner; the demo room prints "[GMForms tests] ..." from Create_0 near the top of the log, then opens a live window and enters its main loop
  ```
  - Needs Node; this machine has v22 vs. the tool's stated `>=24` requirement — it still works, just prints an `EBADENGINE` warning to ignore.
  - `run` never exits on its own (the demo only quits when `GMF_DEMO_CAPTURE` is `true` in `demo_m1.gml`; the room's initial state doesn't get game-ended). Run it as a backgrounded/piped command with an outer timeout (e.g. `sleep 45; kill`) and grep the captured log for the `[GMForms tests]` line — don't wait on it to finish by itself.
  - Output is a fancy TUI (`@clack/prompts`-style) full of ANSI cursor-movement codes; pipe through `sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g'` (after `tr -d '\r'`) before grepping/reading it.
  - First run per machine downloads Igor + the runtime + a license into `<project>/.gmcache/` (self-`.gitignore`d, safe to leave) and `%LOCALAPPDATA%\GameMakerCLI\cache\`; later runs reuse that cache and are much faster.
  - `--target` accepts `windows`/`mac`/`linux`/`operagx`/etc.; `--runtime` is `vm` (default, matches "GameMaker LTS 2026 runtime 2026.0.0.23") or `native`.
  - This is the tool to reach for whenever GML changes need verifying — don't fall back to "can't test without the IDE."

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
