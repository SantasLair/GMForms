/// GMForms — containers (M5): GMF_TabControl + GMF_TabSheet, GMF_Toolbar + GMF_ToolSeparator.

/// @func GMF_TabControl()
/// @desc Tabbed pages. Each page is a GMF_TabSheet child (add_page()); only the active page is visible.
///       Pages fill the area below the tab strip. Click a tab, or focus the control and use Left/Right.
///       on_change(sender, tab_index).
function GMF_TabControl() : GMF_Control() constructor {
    class_name = "TabControl";
    width = 300;
    height = 200;
    tab_stop = true;
    tab_height = 26;
    tab_index = 0;
    _hot_tab = -1;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",      type: "int",  default_value: 300 },
        { name: "height",     type: "int",  default_value: 200 },
        { name: "tab_stop",   type: "bool", default_value: true },
        { name: "tab_height", type: "int",  default_value: 26 },
        { name: "tab_index",  type: "int",  default_value: 0 },
    ]);

    /// @func pages()
    /// @desc The GMF_TabSheet children, in tab order.
    static pages = function() {
        var _out = [];
        var _n = array_length(children);
        for (var _i = 0; _i < _n; _i++) if (children[_i].class_name == "TabSheet") array_push(_out, children[_i]);
        return _out;
    };

    /// @func add_page(caption)
    /// @returns {Struct.GMF_TabSheet} The new page; add controls to it.
    static add_page = function(_caption) {
        var _p = add(gmforms_create(GMF_TabSheet, { caption: _caption, name: name + "_page" + string(array_length(pages())) }));
        _sync_pages();
        return _p;
    };

    /// @func get_page([index])
    static get_page = function(_i = tab_index) {
        var _p = pages();
        return (_i >= 0 && _i < array_length(_p)) ? _p[_i] : undefined;
    };

    /// @func set_tab_index(index, [fire])
    static set_tab_index = function(_i, _fire = true) {
        var _n = array_length(pages());
        if (_n == 0) return;
        _i = clamp(_i, 0, _n - 1);
        if (_i == tab_index) { _sync_pages(); return; }
        tab_index = _i;
        _sync_pages();
        if (_fire && is_callable(on_change)) on_change(self, tab_index);
    };

    static _sync_pages = function() {
        var _p = pages();
        var _n = array_length(_p);
        for (var _i = 0; _i < _n; _i++) _p[_i].set_visible(_i == tab_index);
    };

    /// Pages go below the tab strip (aligned children use this rect).
    static client_rect = function() {
        return {
            x: 1 + padding.l,
            y: tab_height + padding.t,
            w: max(0, width - 2 - padding.l - padding.r),
            h: max(0, height - tab_height - 1 - padding.t - padding.b),
        };
    };

    /// Keeps page visibility in step with tab_index (e.g. after tab_index was assigned directly,
    /// or a form was loaded), then runs the normal Align/Anchors pass.
    static arrange_children = function() {
        var _p = pages();
        var _n = array_length(_p);
        for (var _i = 0; _i < _n; _i++) {
            if (_p[_i].visible != (_i == tab_index)) { _sync_pages(); break; }
        }
        gmforms_inherited(self, GMF_Control, "arrange_children")();
    };

    static _tab_rects = function() {
        var _th = gmforms_theme();
        if (_th.font != -1) draw_set_font(_th.font);
        var _out = [];
        var _p = pages();
        var _x = 2;
        var _n = array_length(_p);
        for (var _i = 0; _i < _n; _i++) {
            var _w = string_width(_p[_i].caption) + 20;
            array_push(_out, { x: _x, w: _w });
            _x += _w + 2;
        }
        return _out;
    };

    static _tab_at = function(_lx, _ly) {
        if (_ly < 0 || _ly >= tab_height) return -1;
        var _r = _tab_rects();
        for (var _i = 0; _i < array_length(_r); _i++) if (_lx >= _r[_i].x && _lx < _r[_i].x + _r[_i].w) return _i;
        return -1;
    };

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        if (_btn != mb_left) return;
        var _i = _tab_at(_x, _y);
        if (_i >= 0) set_tab_index(_i);
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        _hot_tab = _tab_at(_x, _y);
    };

    static mouse_leave = function() {
        _hot_tab = -1;
        if (is_callable(on_mouse_leave)) on_mouse_leave(self);
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (!is_enabled()) return false;
        var _n = array_length(pages());
        if (_n == 0) return false;
        switch (_key) {
            case vk_left:  set_tab_index((tab_index - 1 + _n) mod _n); return true;
            case vk_right: set_tab_index((tab_index + 1) mod _n); return true;
            case vk_home:  set_tab_index(0); return true;
            case vk_end:   set_tab_index(_n - 1); return true;
        }
        return false;
    };

    static draw = function() {
        var _th = gmforms_theme();
        var _p = pages();
        var _r = _tab_rects();
        var _n = array_length(_p);
        gmforms_draw_rect(_sx, _sy + tab_height, width, height - tab_height, _th.tab_active);
        for (var _i = 0; _i < _n; _i++) {
            var _active = (_i == tab_index);
            var _x = _sx + _r[_i].x;
            var _y = _sy + (_active ? 0 : 3);
            var _h = tab_height - (_active ? 0 : 3);
            var _col = _active ? _th.tab_active : ((_i == _hot_tab) ? _th.tab_hover : _th.tab_inactive);
            gmforms_draw_rect(_x, _y, _r[_i].w, _h, _col);
            gmforms_draw_rect(_x, _y, _r[_i].w, 1, _active ? _th.accent : _th.panel_border);
            gmforms_draw_rect(_x, _y, 1, _h, _th.panel_border);
            gmforms_draw_rect(_x + _r[_i].w - 1, _y, 1, _h, _th.panel_border);
            gmforms_draw_text_in(_x, _y, _r[_i].w, _h, _p[_i].caption,
                is_enabled() ? (_active ? _th.text : _th.text_disabled) : _th.text_disabled, fa_center, fa_middle, 0);
        }
    };

    static draw_overlay = function() {
        var _th = gmforms_theme();
        var _y = _sy + tab_height - 1;
        var _col = is_focused() ? _th.focus : _th.panel_border;
        gmforms_draw_frame(_sx, _y, width, height - tab_height + 1, _col);
        // open the frame under the active tab so the tab joins its page
        var _r = _tab_rects();
        if (tab_index >= 0 && tab_index < array_length(_r)) {
            gmforms_draw_rect(_sx + _r[tab_index].x + 1, _y, _r[tab_index].w - 2, 1, _th.tab_active);
        }
    };
}

/// @func GMF_TabSheet()
/// @desc One page of a GMF_TabControl. caption is the tab's title.
function GMF_TabSheet() : GMF_Panel() constructor {
    class_name = "TabSheet";
    caption = "Page";
    align = "client";
    border = false;
    transparent = true;

    static published = array_concat(gmforms_base_published(), [
        { name: "caption",     type: "string", default_value: "Page" },
        { name: "align",       type: "enum",   values: ["none", "top", "bottom", "left", "right", "client"], default_value: "client" },
        { name: "color",       type: "color",  default_value: undefined },
        { name: "transparent", type: "bool",   default_value: true },
        { name: "border",      type: "bool",   default_value: false },
    ]);

    // The caption is shown on the tab, not inside the page.
    static draw = function() {
        if (!transparent) gmforms_draw_rect(_sx, _sy, width, height, color ?? gmforms_theme().tab_active);
    };
}

/// @func GMF_Toolbar()
/// @desc A panel (align "top" by default) that lines its children up left to right, vertically
///       centred, `spacing` pixels apart — children keep their own width/height. Use add_button()
///       and add_separator(), or add() any control (a ComboBox, a SpinEdit, ...).
function GMF_Toolbar() : GMF_Panel() constructor {
    class_name = "Toolbar";
    align = "top";
    height = 36;
    spacing = 4;
    padding = { l: 4, t: 0, r: 4, b: 0 };

    static published = array_concat(gmforms_base_published(), [
        { name: "align",   type: "enum",   values: ["none", "top", "bottom", "left", "right", "client"], default_value: "top" },
        { name: "height",  type: "int",    default_value: 36 },
        { name: "padding", type: "struct", default_value: { l: 4, t: 0, r: 4, b: 0 } },
        { name: "spacing", type: "int",    default_value: 4 },
        { name: "color",   type: "color",  default_value: undefined },
        { name: "border",  type: "bool",   default_value: true },
    ]);

    /// @func add_button(caption, [on_click], [props])
    /// @desc Adds a GMF_Button sized to its caption (unless props sets width). Returns the button.
    static add_button = function(_caption, _on_click = undefined, _props = undefined) {
        var _th = gmforms_theme();
        if (_th.font != -1) draw_set_font(_th.font);
        var _b = gmforms_create(GMF_Button, { caption: _caption, width: string_width(_caption) + 20, height: 26 });
        if (is_struct(_props)) _b.set(_props);
        _b.on_click = _on_click;
        return add(_b);
    };

    /// @func add_separator()
    static add_separator = function() {
        return add(gmforms_create(GMF_ToolSeparator));
    };

    static arrange_children = function() {
        var _x = padding.l;
        var _n = array_length(children);
        for (var _i = 0; _i < _n; _i++) {
            var _c = children[_i];
            if (!_c.visible) continue;
            var _h = min(_c._clamp_h(_c.height), height);
            _c._place(_x, floor((height - _h) * 0.5), _c._clamp_w(_c.width), _h);
            _x += _c.width + spacing;
        }
    };
}

/// @func GMF_ToolSeparator()
/// @desc A thin vertical divider between groups of toolbar buttons.
function GMF_ToolSeparator() : GMF_Control() constructor {
    class_name = "ToolSeparator";
    width = 9;
    height = 24;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",  type: "int", default_value: 9 },
        { name: "height", type: "int", default_value: 24 },
    ]);

    static draw = function() {
        gmforms_draw_rect(_sx + floor(width / 2), _sy + 2, 1, height - 4, gmforms_theme().panel_border);
    };
}
