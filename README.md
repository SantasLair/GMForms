# GMForms

A Delphi-style RAD form system for GameMaker. See `gamemaker-form-designer-plan.md` for the full plan.

**Status: M1 (runtime core) and M2 (serialization) implemented.** Built for GameMaker IDE 2026.0.

## Run the demo

1. Open `GMForms.yyp` in GameMaker.
2. Run (F5). The `rm_demo_m1` room builds a form in code and hands it to a host object.
3. Resize the window: toolbar, status bar, palette, inspector and client area reflow; anchored buttons keep their edge distances.
4. Press **Tab** or **Shift+Tab** to cycle focus, and **Space** or **Enter** to click the focused button.
5. Use the toolbar's *Toggle palette*, *Toggle inspector* and *Disable top-right* buttons to test reflow when visibility changes, and to test disabled state.

## What's in M1 + M2

| Script | Contents |
|---|---|
| `gmforms_core` | `global.gmforms` state, `gmforms_log`, `gmforms_create`, rect, scissor-stack and drawing helpers |
| `gmforms_theme` | `gmforms_theme_dark()` (default) and `gmforms_theme_light()` flat-colour themes |
| `gmforms_control` | `GMF_Control`: tree, setters, **Align + Anchors layout engine**, hit testing, clipped drawing, input hooks |
| `gmforms_form` | `GMF_Form`: root control and input manager (hover, capture, click, wheel bubbling, focus, Tab order, key routing), `update()` / `render()` |
| `gmforms_controls_basic` | `GMF_Panel`, `GMF_Button`, `GMF_Label` |
| `gmforms_host` + `obj_gmforms_host` | Host object: tracks window size, resizes `application_surface` and the GUI layer to it (1:1, no letterboxing), resizes the form, forwards Step / Draw GUI |
| `gmforms_serialize` | Registry-driven JSON save/load: `gmforms_form_to_json`, `gmforms_save_form`, `gmforms_load_form` / `gmforms_load_form_json`, event-name binding, `gmforms_value_equals` |
| `gmforms_tests` | 144 headless checks of Align, Anchors, reflow, hit testing, focus/Tab, keyboard clicks and M2 serialization round-trips. They run at demo start when `GMF_RUN_TESTS` is true and print `[GMForms tests] N passed, M failed` to the Output window |

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

Set `GMF_DEMO_CAPTURE` to `true` (in `demo_m1`). The demo then saves `m1_*.png` screenshots to the save area (`%LOCALAPPDATA%\GMForms`) at 1024×700, 1200×760 (palette hidden, focus moved) and 760×520 (top-right button disabled), and then quits.

## Notes from testing on GameMaker LTS 2026 (Windows)

- A filled `draw_rectangle` covers `[x1, x2)`, so `gmforms_draw_rect` passes `x + w`. With `x + w - 1`, 1px border strips didn't draw at all.
- With **Keep aspect ratio** on, GameMaker draws the GUI layer inside the letterboxed application-surface rect. That broke 1:1 pixels and scissor clipping after a resize. The host resizes `application_surface` to the window, which fixes this.
- GameMaker's built-in font is fairly wide. Captions longer than their button are clipped, which is intentional. Proper theme fonts come with the theme milestone.
- Editing project files outside the IDE while the project is open: the IDE picks the change up after a few seconds. If you press Run straight away, it can write back its own copy.

## Project settings

Windows, macOS and Linux options have **Allow window resize** turned on. That's required for reflow.
