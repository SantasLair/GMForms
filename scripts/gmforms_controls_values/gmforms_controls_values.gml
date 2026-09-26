/// GMForms — value controls (M5): GMF_SpinEdit, GMF_Slider, GMF_ColorPicker (+ GMF_ColorPopup).

/// @func GMF_SpinEdit()
/// @desc Numeric edit with up/down buttons. Type a number (committed on Enter or focus loss), use
///       Up/Down (±step), PageUp/PageDown (±10 steps), the buttons, or the wheel while focused/hovered.
///       value is clamped to [min_value, max_value] and rounded to `decimals`. on_change(sender, value)
///       fires when value changes (not per keystroke).
function GMF_SpinEdit() : GMF_Edit() constructor {
    class_name = "SpinEdit";
    width = 100;
    value = 0;
    min_value = 0;
    max_value = 100;
    step = 1;
    decimals = 0;
    text = "0";
    _inset_r = 16;
    _shown_value = 0;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",     type: "int",  default_value: 100 },
        { name: "height",    type: "int",  default_value: 24 },
        { name: "tab_stop",  type: "bool", default_value: true },
        { name: "value",     type: "real", default_value: 0 },
        { name: "min_value", type: "real", default_value: 0 },
        { name: "max_value", type: "real", default_value: 100 },
        { name: "step",      type: "real", default_value: 1 },
        { name: "decimals",  type: "int",  default_value: 0 },
    ]);

    static _snap = function(_v) {
        _v = clamp(_v, min(min_value, max_value), max(min_value, max_value));
        var _p = power(10, max(0, decimals));
        return round(_v * _p) / _p;
    };

    static _format = function(_v) {
        return (decimals <= 0) ? string(round(_v)) : string_format(_v, 0, decimals);
    };

    /// @func set_value(value, [fire])
    static set_value = function(_v, _fire = true) {
        _v = _snap(_v);
        var _changed = (_v != value);
        value = _v;
        _sync_text();
        if (_changed && _fire && is_callable(on_change)) on_change(self, value);
    };

    static _sync_text = function() {
        text = _format(value);
        _shown_value = value;
        _caret = string_length(text);
        _sel_anchor = _caret;
        _scroll_x = 0;
    };

    /// @func commit()
    /// @desc Parses the typed text into value (invalid text reverts to the current value).
    static commit = function() {
        var _v = __gmforms_parse_number(text);
        if (_v == undefined) _sync_text(); else set_value(_v);
    };

    static _fire_change = function() {};   // typing doesn't fire on_change; commits do

    static key_char = function(_ch) {
        if (string_pos(_ch, "0123456789.-+eE") == 0) return;
        gmforms_inherited(self, GMF_Edit, "key_char")(_ch);
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (!is_enabled()) return false;
        switch (_key) {
            case vk_up:       commit(); set_value(value + step); select_all(); return true;
            case vk_down:     commit(); set_value(value - step); select_all(); return true;
            case vk_pageup:   commit(); set_value(value + step * 10); select_all(); return true;
            case vk_pagedown: commit(); set_value(value - step * 10); select_all(); return true;
            case vk_enter:    commit(); select_all(); return true;
            case vk_escape:   _sync_text(); select_all(); return true;
        }
        return _edit_key(_key);
    };

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        if (_btn == mb_left && _x >= width - _inset_r) {
            commit();
            set_value(value + ((_y < height * 0.5) ? step : -step));
            return;
        }
        _edit_mouse_down(_x, _y, _btn);
    };

    static mouse_wheel = function(_delta) {
        if (is_callable(on_mouse_wheel) && on_mouse_wheel(self, _delta) == true) return true;
        if (!is_focused() && !is_hot()) return false;
        commit();
        set_value(value - _delta * step);
        return true;
    };

    static focus_lost = function() {
        commit();
        if (is_callable(on_blur)) on_blur(self);
    };

    static draw = function() {
        if (!is_focused() && _shown_value != value) _sync_text();   // value assigned directly / loaded from JSON
        gmforms_inherited(self, GMF_Edit, "draw")();
        var _th = gmforms_theme();
        var _en = is_enabled();
        var _bx = _sx + width - _inset_r;
        var _hh = floor(height / 2);
        for (var _k = 0; _k < 2; _k++) {
            var _by = _sy + _k * _hh;
            var _bh = (_k == 0) ? _hh : height - _hh;
            gmforms_draw_rect(_bx, _by, _inset_r, _bh, _en ? _th.button : _th.button_disabled);
            gmforms_draw_frame(_bx, _by, _inset_r, _bh, _th.button_border);
            var _cx = _bx + _inset_r * 0.5;
            var _cy = _by + _bh * 0.5;
            draw_set_colour(_en ? _th.text : _th.text_disabled);
            if (_k == 0) draw_triangle(_cx - 3, _cy + 2, _cx + 3, _cy + 2, _cx, _cy - 2, false);
            else draw_triangle(_cx - 3, _cy - 2, _cx + 3, _cy - 2, _cx, _cy + 2, false);
        }
    };
}

/// @func GMF_Slider()
/// @desc Horizontal track bar. Drag the thumb or click the track; Left/Right (±step), PageUp/PageDown
///       (±10%), Home/End, wheel. on_change(sender, value).
function GMF_Slider() : GMF_Control() constructor {
    class_name = "Slider";
    width = 160;
    height = 24;
    tab_stop = true;
    value = 0;
    min_value = 0;
    max_value = 100;
    step = 1;
    thumb_width = 10;
    _dragging = false;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",     type: "int",  default_value: 160 },
        { name: "height",    type: "int",  default_value: 24 },
        { name: "tab_stop",  type: "bool", default_value: true },
        { name: "value",     type: "real", default_value: 0 },
        { name: "min_value", type: "real", default_value: 0 },
        { name: "max_value", type: "real", default_value: 100 },
        { name: "step",      type: "real", default_value: 1 },
    ]);

    static _snap = function(_v) {
        _v = clamp(_v, min(min_value, max_value), max(min_value, max_value));
        if (step > 0) _v = min_value + round((_v - min_value) / step) * step;
        _v = clamp(_v, min(min_value, max_value), max(min_value, max_value));
        return round(_v * 1000000) / 1000000;
    };

    /// @func set_value(value, [fire])
    static set_value = function(_v, _fire = true) {
        _v = _snap(_v);
        if (_v == value) return;
        value = _v;
        if (_fire && is_callable(on_change)) on_change(self, value);
    };

    static _ratio = function() {
        return (max_value != min_value) ? clamp((value - min_value) / (max_value - min_value), 0, 1) : 0;
    };

    /// Value under a local x.
    static _value_at = function(_lx) {
        var _t = clamp((_lx - thumb_width * 0.5) / max(1, width - thumb_width), 0, 1);
        return min_value + _t * (max_value - min_value);
    };

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        if (_btn != mb_left) return;
        _dragging = true;
        set_value(_value_at(_x));
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        var _f = get_form();
        if (_dragging && _f != undefined && _f.capture == self) set_value(_value_at(_x));
    };

    static mouse_up = function(_x, _y, _btn) {
        if (is_callable(on_mouse_up)) on_mouse_up(self, _x, _y, _btn);
        _dragging = false;
    };

    static mouse_wheel = function(_delta) {
        if (is_callable(on_mouse_wheel) && on_mouse_wheel(self, _delta) == true) return true;
        set_value(value - _delta * max(step, 0.000001));
        return true;
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (!is_enabled()) return false;
        var _page = max(step, (max_value - min_value) / 10);
        switch (_key) {
            case vk_left:
            case vk_down:     set_value(value - step); return true;
            case vk_right:
            case vk_up:       set_value(value + step); return true;
            case vk_pagedown: set_value(value - _page); return true;
            case vk_pageup:   set_value(value + _page); return true;
            case vk_home:     set_value(min_value); return true;
            case vk_end:      set_value(max_value); return true;
        }
        return false;
    };

    static draw = function() {
        var _th = gmforms_theme();
        var _en = is_enabled();
        var _cy = _sy + floor(height / 2);
        var _tx = _sx + floor(thumb_width / 2);
        var _tw = width - thumb_width;
        var _px = _sx + round(_ratio() * _tw);
        gmforms_draw_rect(_tx, _cy - 2, _tw, 4, _th.slider_track);
        gmforms_draw_rect(_tx, _cy - 2, _px - _sx, 4, _en ? _th.accent : _th.text_disabled);
        var _col = _en ? ((_dragging || is_hot()) ? _th.text : _th.slider_thumb) : _th.button_disabled;
        gmforms_draw_rect(_px, _sy + 3, thumb_width, height - 6, _col);
        gmforms_draw_frame(_px, _sy + 3, thumb_width, height - 6, _th.button_border);
    };

    static draw_overlay = function() {
        if (is_focused()) gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().focus, 1);
    };
}

/// @func GMF_ColorPicker()
/// @desc Colour button: swatch + #RRGGBB. Click (or Enter/Space) opens a GMF_ColorPopup with a
///       saturation/value square, a hue bar and preset swatches. on_change(sender, colour) fires live
///       while dragging in the popup.
function GMF_ColorPicker() : GMF_Control() constructor {
    class_name = "ColorPicker";
    width = 130;
    height = 24;
    tab_stop = true;
    color = c_white;
    _popup = undefined;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",    type: "int",   default_value: 130 },
        { name: "height",   type: "int",   default_value: 24 },
        { name: "tab_stop", type: "bool",  default_value: true },
        { name: "color",    type: "color", default_value: c_white },
    ]);

    /// @func set_color(colour, [fire])
    static set_color = function(_c, _fire = true) {
        if (_c == color) return;
        color = _c;
        if (_fire && is_callable(on_change)) on_change(self, color);
    };

    // colour popup source
    static _cp_get = function() { return color; };
    static _cp_set = function(_c, _final) { set_color(_c); };

    /// @func is_open()
    static is_open = function() {
        var _f = get_form();
        return _f != undefined && _f.is_popup_open(_popup);
    };

    /// @func open()
    static open = function() {
        if (!is_enabled() || is_open()) return;
        _popup = gmforms_color_popup_open(self, self, 0, 0, width, height);
    };

    static click = function() {
        if (is_open()) { var _f = get_form(); _f.close_popup(_popup); } else open();
        if (is_callable(on_click)) on_click(self);
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (_key == vk_enter || _key == vk_space) { open(); return true; }
        return false;
    };

    static draw = function() {
        var _th = gmforms_theme();
        var _en = is_enabled();
        var _col = _th.button;
        if (!_en) _col = _th.button_disabled;
        else if (is_open() || is_pressed()) _col = _th.button_pressed;
        else if (is_hot()) _col = _th.button_hover;
        gmforms_draw_rect(_sx, _sy, width, height, _col);
        var _s = height - 8;
        gmforms_draw_rect(_sx + 4, _sy + 4, _s * 2, _s, color);
        gmforms_draw_frame(_sx + 4, _sy + 4, _s * 2, _s, _th.button_border);
        gmforms_draw_text_in(_sx + 8 + _s * 2, _sy, width - 8 - _s * 2, height, gmforms_color_to_hex(color),
            _en ? _th.text : _th.text_disabled, fa_left, fa_middle, 2);
    };

    static draw_overlay = function() {
        var _th = gmforms_theme();
        if (is_focused()) gmforms_draw_frame(_sx, _sy, width, height, _th.focus, 2);
        else gmforms_draw_frame(_sx, _sy, width, height, _th.button_border);
    };
}

/// @func gmforms_color_popup_open(owner, source, lx, ly, w, h)
/// @desc Opens a GMF_ColorPopup below (or above) the owner-local rect. source provides
///       _cp_get() -> colour and _cp_set(colour, final): final is false while dragging, true on
///       release / preset click (so an undo step can be recorded once).
/// @returns {Struct|Undefined}
function gmforms_color_popup_open(_owner, _source, _lx, _ly, _w, _h) {
    var _f = _owner.get_form();
    if (_f == undefined) {
        gmforms_log("colour popup: owner is not in a form");
        return undefined;
    }
    var _p = new GMF_ColorPopup();
    _p.source = _source;
    _p._load();
    var _top = _owner._sy - _f._sy + _ly;
    var _y = _top + _h;
    if (_y + _p.height > _f.height && _top - _p.height >= 0) _y = _top - _p.height;
    _f.show_popup(_p, _owner._sx - _f._sx + _lx, _y, _owner);
    return _p;
}

/// @func GMF_ColorPopup()
/// @desc The popup opened by GMF_ColorPicker (and the PropertyGrid's colour rows).
function GMF_ColorPopup() : GMF_Control() constructor {
    class_name = "ColorPopup";
    width = 204;
    height = 232;
    source = undefined;
    _h = 0;
    _s = 0;
    _v = 255;
    _drag = "";

    static presets = [
        c_black, c_dkgray, c_gray, c_ltgray, c_white, c_maroon, c_red, c_orange,
        c_yellow, c_olive, c_lime, c_green, c_teal, c_aqua, c_blue, c_fuchsia,
    ];
    static _sv = { x: 8, y: 8, w: 160, h: 140 };
    static _hue = { x: 176, y: 8, w: 20, h: 140 };
    static _cell = 21;
    static _gap = 2;
    static _px0 = 11;
    static _py0 = 156;

    static _load = function() {
        var _c = source._cp_get();
        if (!is_numeric(_c)) _c = c_white;
        _h = colour_get_hue(_c);
        _s = colour_get_saturation(_c);
        _v = colour_get_value(_c);
    };

    static get_color = function() { return make_colour_hsv(_h, _s, _v); };

    static _emit = function(_final) { source._cp_set(get_color(), _final); };

    static _preset_at = function(_x, _y) {
        for (var _i = 0; _i < 16; _i++) {
            var _cx = _px0 + (_i mod 8) * (_cell + _gap);
            var _cy = _py0 + (_i div 8) * (_cell + _gap);
            if (_x >= _cx && _x < _cx + _cell && _y >= _cy && _y < _cy + _cell) return _i;
        }
        return -1;
    };

    static _drag_to = function(_x, _y) {
        if (_drag == "sv") {
            _s = clamp((_x - _sv.x) / _sv.w, 0, 1) * 255;
            _v = (1 - clamp((_y - _sv.y) / _sv.h, 0, 1)) * 255;
        } else if (_drag == "hue") {
            _h = clamp((_y - _hue.y) / _hue.h, 0, 1) * 255;
        }
    };

    static mouse_down = function(_x, _y, _btn) {
        if (_btn != mb_left) return;
        if (_x >= _sv.x && _x < _sv.x + _sv.w && _y >= _sv.y && _y < _sv.y + _sv.h) _drag = "sv";
        else if (_x >= _hue.x && _x < _hue.x + _hue.w && _y >= _hue.y && _y < _hue.y + _hue.h) _drag = "hue";
        else {
            var _i = _preset_at(_x, _y);
            if (_i >= 0) {
                var _c = presets[_i];
                _h = colour_get_hue(_c);
                _s = colour_get_saturation(_c);
                _v = colour_get_value(_c);
                _emit(true);
            }
            return;
        }
        _drag_to(_x, _y);
        _emit(false);
    };

    static mouse_move = function(_x, _y) {
        var _f = get_form();
        if (_drag == "" || _f == undefined || _f.capture != self) return;
        _drag_to(_x, _y);
        _emit(false);
    };

    static mouse_up = function(_x, _y, _btn) {
        if (_drag == "") return;
        _drag = "";
        _emit(true);
    };

    static key_down = function(_key) {
        if (_key == vk_enter) {
            var _f = get_form();
            if (_f != undefined) _f.close_popup(self);
            return true;
        }
        return false;
    };

    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, _th.menu_bg);

        // saturation (left->right) x value (top->bottom) square for the current hue
        var _x1 = _sx + _sv.x, _y1 = _sy + _sv.y, _x2 = _x1 + _sv.w, _y2 = _y1 + _sv.h;
        var _pure = make_colour_hsv(_h, 255, 255);
        draw_rectangle_colour(_x1, _y1, _x2, _y2, c_white, _pure, _pure, c_white, false);
        draw_primitive_begin(pr_trianglestrip);
        draw_vertex_colour(_x1, _y1, c_black, 0);
        draw_vertex_colour(_x2, _y1, c_black, 0);
        draw_vertex_colour(_x1, _y2, c_black, 1);
        draw_vertex_colour(_x2, _y2, c_black, 1);
        draw_primitive_end();
        var _mx = _x1 + _s / 255 * _sv.w;
        var _my = _y1 + (1 - _v / 255) * _sv.h;
        draw_set_colour((_v > 128) ? c_black : c_white);
        draw_circle(_mx, _my, 4, true);

        // hue bar, top to bottom
        var _hx = _sx + _hue.x, _hy = _sy + _hue.y;
        for (var _k = 0; _k < 6; _k++) {
            var _ca = make_colour_hsv(_k * 255 / 6, 255, 255);
            var _cb = make_colour_hsv(min(255, (_k + 1) * 255 / 6) mod 256, 255, 255);
            if (_k == 5) _cb = c_red;
            var _ya = _hy + _k * _hue.h / 6;
            var _yb = _hy + (_k + 1) * _hue.h / 6;
            draw_rectangle_colour(_hx, _ya, _hx + _hue.w, _yb, _ca, _ca, _cb, _cb, false);
        }
        var _hy_mark = _hy + _h / 255 * _hue.h;
        gmforms_draw_rect(_hx - 2, _hy_mark - 1, _hue.w + 4, 3, c_white);
        gmforms_draw_frame(_hx - 2, _hy_mark - 2, _hue.w + 4, 5, c_black);

        // presets
        for (var _i = 0; _i < 16; _i++) {
            var _cx = _sx + _px0 + (_i mod 8) * (_cell + _gap);
            var _cy = _sy + _py0 + (_i div 8) * (_cell + _gap);
            gmforms_draw_rect(_cx, _cy, _cell, _cell, presets[_i]);
            gmforms_draw_frame(_cx, _cy, _cell, _cell, _th.button_border);
        }

        // current colour
        var _c = get_color();
        gmforms_draw_rect(_sx + 8, _sy + 206, 40, 18, _c);
        gmforms_draw_frame(_sx + 8, _sy + 206, 40, 18, _th.button_border);
        gmforms_draw_text_in(_sx + 52, _sy + 206, width - 60, 18, gmforms_color_to_hex(_c), _th.text, fa_left, fa_middle, 2);
    };

    static draw_overlay = function() {
        gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().menu_border);
    };
}
