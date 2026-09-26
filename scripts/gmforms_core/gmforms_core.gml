/// GMForms — core: global state, logging, drawing and rect helpers.
/// All library globals live in a single struct: global.gmforms (plan section 17).

#macro GMF_VERSION "0.1.0"

/// @func gmforms_init()
/// @desc Creates global.gmforms if it doesn't exist yet. Safe to call any number of times.
/// @returns {Struct} The global GMForms state struct.
function gmforms_init() {
    if (variable_global_exists("gmforms") && is_struct(global.gmforms)) return global.gmforms;
    global.gmforms = {
        theme: undefined,
        registry: {},          // class name -> constructor, keyed by class_name (e.g. "Button")
        scissor_stack: [],
        scissor_scale_x: 1,
        scissor_scale_y: 1,
        log_enabled: true,
    };
    global.gmforms.theme = gmforms_theme_dark();

    // Built-in controls. User controls register themselves with gmforms_register().
    gmforms_register("Form", GMF_Form);
    gmforms_register("Panel", GMF_Panel);
    gmforms_register("Button", GMF_Button);
    gmforms_register("Label", GMF_Label);

    return global.gmforms;
}

/// @func gmforms_register(class_name, ctor)
/// @desc Adds (or replaces) a class in the registry so the loader can instantiate it by name.
/// @param {String} class_name Must match the value the constructor sets for `class_name`.
/// @param {Function} ctor
function gmforms_register(_class_name, _ctor) {
    gmforms_init().registry[$ _class_name] = _ctor;
}

/// @func gmforms_log(message)
/// @desc Writes a GMForms message to the output log. The library warns instead of crashing where it can.
/// @param {Any} message
function gmforms_log(_msg) {
    if (gmforms_init().log_enabled) show_debug_message("[GMForms] " + string(_msg));
}

/// @func gmforms_theme()
/// @desc Returns the active theme struct.
/// @returns {Struct}
function gmforms_theme() {
    return gmforms_init().theme;
}

/// @func gmforms_set_theme(theme)
/// @desc Replaces the active theme.
/// @param {Struct} theme A struct shaped like the one returned by gmforms_theme_dark().
function gmforms_set_theme(_theme) {
    gmforms_init().theme = _theme;
}

/// @func gmforms_create(ctor, [props])
/// @desc Creates a control and applies a struct of properties to it.
/// @param {Function} ctor  A control constructor, e.g. GMF_Button.
/// @param {Struct} [props] Property values, e.g. { name: "btnOk", caption: "OK", left: 8, top: 8 }.
/// @returns {Struct} The new control.
function gmforms_create(_ctor, _props = undefined) {
    var _c = new _ctor();
    if (is_struct(_props)) _c.set(_props);
    return _c;
}

// ---------------------------------------------------------------------------
// Rect helpers
// ---------------------------------------------------------------------------

/// @func gmforms_rect_intersect(a, b)
/// @desc Intersection of two {x, y, w, h} rects. Width/height are never negative.
function gmforms_rect_intersect(_a, _b) {
    var _x1 = max(_a.x, _b.x);
    var _y1 = max(_a.y, _b.y);
    var _x2 = min(_a.x + _a.w, _b.x + _b.w);
    var _y2 = min(_a.y + _a.h, _b.y + _b.h);
    return { x: _x1, y: _y1, w: max(0, _x2 - _x1), h: max(0, _y2 - _y1) };
}

// ---------------------------------------------------------------------------
// Scissor (clip) stack. Coordinates are GUI pixels, which equal window pixels
// because the host keeps the GUI layer sized 1:1 with the window (decision D5).
// ---------------------------------------------------------------------------

/// @func gmforms_scissor_reset(x, y, w, h, [scale_x], [scale_y])
/// @desc Starts a new clip stack with a base rect in GUI pixels. Called by GMF_Form.render().
///       scale_x/scale_y convert GUI pixels to render-target pixels (they differ from 1 when the
///       back buffer isn't the same size as the GUI layer, e.g. while the window is being resized).
function gmforms_scissor_reset(_x, _y, _w, _h, _scale_x = 1, _scale_y = 1) {
    var _g = gmforms_init();
    _g.scissor_scale_x = _scale_x;
    _g.scissor_scale_y = _scale_y;
    _g.scissor_stack = [{ x: floor(_x), y: floor(_y), w: max(0, floor(_w)), h: max(0, floor(_h)) }];
    __gmforms_scissor_apply(_g.scissor_stack[0]);
}

/// @func gmforms_scissor_push(x, y, w, h)
/// @desc Narrows the clip rect (GUI pixels) to its intersection with the given rect.
/// @returns {Bool} False when the resulting clip area is empty (nothing would be visible).
function gmforms_scissor_push(_x, _y, _w, _h) {
    var _st = gmforms_init().scissor_stack;
    var _r = { x: floor(_x), y: floor(_y), w: max(0, floor(_w)), h: max(0, floor(_h)) };
    var _n = array_length(_st);
    if (_n > 0) _r = gmforms_rect_intersect(_st[_n - 1], _r);
    array_push(_st, _r);
    __gmforms_scissor_apply(_r);
    return (_r.w > 0 && _r.h > 0);
}

/// @func gmforms_scissor_pop()
/// @desc Restores the previous clip rect.
function gmforms_scissor_pop() {
    var _st = gmforms_init().scissor_stack;
    if (array_length(_st) > 1) array_pop(_st);
    __gmforms_scissor_apply(_st[array_length(_st) - 1]);
}

/// Converts a GUI-pixel rect to render-target pixels and sets it as the GPU scissor.
function __gmforms_scissor_apply(_r) {
    var _g = global.gmforms;
    var _sx = _g[$ "scissor_scale_x"] ?? 1;
    var _sy = _g[$ "scissor_scale_y"] ?? 1;
    var _x1 = floor(_r.x * _sx);
    var _y1 = floor(_r.y * _sy);
    var _x2 = ceil((_r.x + _r.w) * _sx);
    var _y2 = ceil((_r.y + _r.h) * _sy);
    gpu_set_scissor(_x1, _y1, max(0, _x2 - _x1), max(0, _y2 - _y1));
}

// ---------------------------------------------------------------------------
// Drawing helpers (plain rectangles for M1; nine-slice theming comes later)
// ---------------------------------------------------------------------------

/// @func gmforms_draw_rect(x, y, w, h, colour)
/// @desc Filled rectangle covering exactly w x h pixels.
///       (Measured on Windows: a filled draw_rectangle covers [x1, x2) x [y1, y2), so x2 = x + w.)
function gmforms_draw_rect(_x, _y, _w, _h, _col) {
    if (_w <= 0 || _h <= 0) return;
    draw_set_colour(_col);
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
}

/// @func gmforms_draw_frame(x, y, w, h, colour, [thickness])
/// @desc 1px (or thicker) outline drawn inside the rect, built from filled strips to avoid outline off-by-one quirks.
function gmforms_draw_frame(_x, _y, _w, _h, _col, _t = 1) {
    if (_w <= 0 || _h <= 0) return;
    gmforms_draw_rect(_x, _y, _w, _t, _col);                 // top
    gmforms_draw_rect(_x, _y + _h - _t, _w, _t, _col);       // bottom
    gmforms_draw_rect(_x, _y + _t, _t, _h - _t * 2, _col);   // left
    gmforms_draw_rect(_x + _w - _t, _y + _t, _t, _h - _t * 2, _col); // right
}

/// @func gmforms_draw_text_in(x, y, w, h, text, colour, halign, valign, [pad])
/// @desc Draws text aligned inside a rect, clipped to that rect.
function gmforms_draw_text_in(_x, _y, _w, _h, _text, _col, _halign = fa_left, _valign = fa_middle, _pad = 4) {
    if (_text == "" || _w <= 0 || _h <= 0) return;
    var _th = gmforms_theme();
    if (_th.font != -1) draw_set_font(_th.font);
    draw_set_colour(_col);
    draw_set_halign(_halign);
    draw_set_valign(_valign);
    var _tx = (_halign == fa_left) ? _x + _pad : ((_halign == fa_center) ? _x + _w * 0.5 : _x + _w - _pad);
    var _ty = (_valign == fa_top) ? _y + _pad : ((_valign == fa_middle) ? _y + _h * 0.5 : _y + _h - _pad);
    if (gmforms_scissor_push(_x, _y, _w, _h)) {
        draw_text(floor(_tx), floor(_ty), _text);
    }
    gmforms_scissor_pop();
}

/// @func gmforms_halign_from_string(name)
/// @desc "left" | "center" | "right" -> fa_* constant.
function gmforms_halign_from_string(_s) {
    switch (_s) {
        case "center": return fa_center;
        case "right":  return fa_right;
        default:       return fa_left;
    }
}

/// @func gmforms_valign_from_string(name)
/// @desc "top" | "middle" | "bottom" -> fa_* constant.
function gmforms_valign_from_string(_s) {
    switch (_s) {
        case "top":    return fa_top;
        case "bottom": return fa_bottom;
        default:       return fa_middle;
    }
}
