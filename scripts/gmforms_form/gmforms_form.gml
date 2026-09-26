/// GMForms — GMF_Form: the root control. Owns hover/capture/focus (input manager), the popup layer,
/// and drives layout.
///
/// A form's width/height when it is first laid out are its *design size*: anchored children
/// capture their distances to the edges at that size, then the host resizes the form to the
/// window and everything reflows (Delphi behaviour).
///
/// Popup layer (M5): show_popup(control, x, y, owner) puts any control above the whole tree
/// (menus, dropdown lists, colour popups). While popups are open:
///   - they are hit-tested first and drawn last, on top of everything;
///   - a mouse press outside every popup closes them all and is consumed;
///   - Escape closes the topmost popup, Tab closes all of them;
///   - navigation keys go to the topmost popup instead of the focused control.

/// @func GMF_Form()
function GMF_Form() : GMF_Control() constructor {
    class_name = "Form";
    is_form = true;
    caption = "Form";
    color = undefined;                  // background; undefined = theme.form_bg
    width = 640;
    height = 480;

    // input manager state
    hover = undefined;                  // control under the mouse
    capture = undefined;                // control that received the mouse-down; gets move/up until release
    capture_button = -1;
    focused = undefined;                // keyboard focus
    popups = [];                        // open popups, bottom to top

    _design_done = false;
    _last_mx = -100000;
    _last_my = -100000;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",   type: "int",    default_value: 640 },
        { name: "height",  type: "int",    default_value: 480 },
        { name: "caption", type: "string", default_value: "Form" },
        { name: "color",   type: "color",  default_value: undefined },
    ]);

    // keys forwarded to the focused control (Tab is handled by the form)
    static _nav_keys = [
        vk_enter, vk_space, vk_escape, vk_backspace, vk_delete,
        vk_left, vk_right, vk_up, vk_down,
        vk_home, vk_end, vk_pageup, vk_pagedown,
    ];
    static _mouse_buttons = [mb_left, mb_right, mb_middle];
    // Clipboard/select-all keys, forwarded to key_down only while Ctrl is held (see _update_keys) —
    // plain "A"/"C"/"X"/"V" never reach key_down; they only arrive via key_char (typed text).
    static _clipboard_keys = [ ord("A"), ord("C"), ord("X"), ord("V") ];

    // -----------------------------------------------------------------------
    // Bounds and layout
    // -----------------------------------------------------------------------

    /// @func set_bounds(left, top, width, height)
    /// @desc Sets the form's rect on screen (normally the whole window). The first call lays the form
    ///       out at its design size first so anchors capture design-time distances.
    static set_bounds = function(_l, _t, _w, _h) {
        if (!_design_done) _design_pass();
        left = _l;
        top = _t;
        if (_w != width || _h != height) {
            width = _w;
            height = _h;
            _layout_dirty = true;
            if (is_callable(on_resize)) on_resize(self);
        }
        return self;
    };

    static _design_pass = function() {
        _design_done = true;
        _sx = left;
        _sy = top;
        layout_tree();
    };

    /// @func layout()
    /// @desc Runs any pending layout. Called automatically by update() and render().
    static layout = function() {
        if (!_design_done) _design_pass();
        _sx = left;
        _sy = top;
        layout_tree();
        var _n = array_length(popups);
        for (var _i = 0; _i < _n; _i++) {
            var _p = popups[_i];
            _p._sx = _sx + _p.left;
            _p._sy = _sy + _p.top;
            _p.layout_tree();
        }
    };

    // -----------------------------------------------------------------------
    // Popup layer
    // -----------------------------------------------------------------------

    /// @func show_popup(control, x, y, [owner])
    /// @desc Shows a control above everything at form-local (x, y), clamped inside the form.
    ///       owner is the control that opened it: hiding/disabling/removing the owner closes it.
    ///       If the control is already open, it (and everything above it) is closed first.
    /// @returns {Struct} The popup.
    static show_popup = function(_p, _x, _y, _owner = undefined) {
        if (is_popup_open(_p)) close_popup(_p);
        _p.parent = self;
        _p._popup_owner = _owner;
        _p.left = clamp(round(_x), 0, max(0, width - _p.width));
        _p.top = clamp(round(_y), 0, max(0, height - _p.height));
        _p._layout_dirty = true;
        array_push(popups, _p);
        _p._sx = _sx + _p.left;
        _p._sy = _sy + _p.top;
        _p.layout_tree();
        return _p;
    };

    /// @func close_popup(control)
    /// @desc Closes a popup and every popup opened above it (e.g. its submenus).
    static close_popup = function(_p) {
        var _i = array_get_index(popups, _p);
        if (_i < 0) return;
        while (array_length(popups) > _i) {
            var _q = array_pop(popups);
            if (hover != undefined && _q.is_ancestor_of(hover)) {
                var _h = hover;
                hover = undefined;
                _h.mouse_leave();
            }
            if (capture != undefined && _q.is_ancestor_of(capture)) {
                capture = undefined;
                capture_button = -1;
            }
            _q.parent = undefined;
            _q.popup_closed();
        }
    };

    /// @func close_popups()
    /// @desc Closes every open popup.
    static close_popups = function() {
        if (array_length(popups) > 0) close_popup(popups[0]);
    };

    /// @func is_popup_open(control)
    static is_popup_open = function(_p) {
        return _p != undefined && array_get_index(popups, _p) >= 0;
    };

    /// @func top_popup()
    /// @desc The topmost open popup, or undefined.
    static top_popup = function() {
        var _n = array_length(popups);
        return (_n > 0) ? popups[_n - 1] : undefined;
    };

    static _in_popup = function(_ctrl) {
        var _n = array_length(popups);
        for (var _i = 0; _i < _n; _i++) if (popups[_i].is_ancestor_of(_ctrl)) return true;
        return false;
    };

    // -----------------------------------------------------------------------
    // Focus
    // -----------------------------------------------------------------------

    /// @func set_focus(control)
    /// @desc Moves keyboard focus (undefined clears it). Fires on_blur / on_focus.
    static set_focus = function(_ctrl) {
        if (_ctrl == focused) return;
        var _old = focused;
        focused = _ctrl;
        if (_old != undefined) _old.focus_lost();
        if (_ctrl != undefined) _ctrl.focus_gained();
    };

    /// @func get_tab_list()
    /// @desc Visible, enabled, tab_stop controls in tab order (depth first; siblings by tab_order, then child order).
    static get_tab_list = function() {
        var _out = [];
        _collect_tabs(self, _out);
        return _out;
    };

    static _collect_tabs = function(_ctrl, _out) {
        var _n = array_length(_ctrl.children);
        if (_n == 0) return;
        var _items = array_create(_n);
        for (var _i = 0; _i < _n; _i++) {
            var _c = _ctrl.children[_i];
            _items[_i] = { c: _c, k: (_c.tab_order >= 0) ? _c.tab_order : _i, i: _i };
        }
        array_sort(_items, function(_a, _b) {
            if (_a.k != _b.k) return _a.k - _b.k;
            return _a.i - _b.i;
        });
        for (var _i = 0; _i < _n; _i++) {
            var _c = _items[_i].c;
            if (!_c.visible || !_c.enabled) continue;
            if (_c.tab_stop) array_push(_out, _c);
            _collect_tabs(_c, _out);
        }
    };

    /// @func focus_next([direction])
    /// @desc Moves focus to the next (1) or previous (-1) control in tab order, wrapping around.
    static focus_next = function(_dir = 1) {
        var _list = get_tab_list();
        var _n = array_length(_list);
        if (_n == 0) return;
        var _idx = (focused == undefined) ? -1 : array_get_index(_list, focused);
        if (_idx < 0) _idx = (_dir > 0) ? 0 : _n - 1;
        else _idx = (_idx + _dir + _n) mod _n;
        set_focus(_list[_idx]);
    };

    /// Clears hover/capture/focus if they point into a subtree that is being hidden, disabled or
    /// removed, and closes popups owned by (or inside) it.
    static _forget_subtree = function(_root) {
        for (var _i = array_length(popups) - 1; _i >= 0; _i--) {
            if (_i >= array_length(popups)) continue;
            var _p = popups[_i];
            var _owner = _p[$ "_popup_owner"];
            if (_root.is_ancestor_of(_p) || (_owner != undefined && _root.is_ancestor_of(_owner))) close_popup(_p);
        }
        if (hover != undefined && _root.is_ancestor_of(hover)) {
            var _h = hover;
            hover = undefined;
            _h.mouse_leave();
        }
        if (capture != undefined && _root.is_ancestor_of(capture)) {
            capture = undefined;
            capture_button = -1;
        }
        if (focused != undefined && _root.is_ancestor_of(focused)) set_focus(undefined);
    };

    // -----------------------------------------------------------------------
    // Per-frame update (call from Step)
    // -----------------------------------------------------------------------

    /// @func update()
    /// @desc Processes mouse and keyboard input for this frame. Call once per Step.
    static update = function() {
        layout();

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        _update_hover(_mx, _my);

        for (var _b = 0; _b < 3; _b++) {
            var _btn = _mouse_buttons[_b];
            if (mouse_check_button_pressed(_btn)) _mouse_press(_btn, _mx, _my);
            if (mouse_check_button_released(_btn)) _mouse_release(_btn, _mx, _my);
        }

        if (_mx != _last_mx || _my != _last_my) {
            _last_mx = _mx;
            _last_my = _my;
            _mouse_move_to(_mx, _my);
        }

        var _wd = mouse_wheel_down() - mouse_wheel_up();
        if (_wd != 0) _mouse_wheel_at(_wd, _mx, _my);

        _update_keys();
    };

    /// @func control_at(gui_x, gui_y)
    /// @desc Topmost control under a point: open popups first, then the form's tree.
    static control_at = function(_mx, _my) {
        for (var _i = array_length(popups) - 1; _i >= 0; _i--) {
            var _h = popups[_i].hit_test(_mx, _my);
            if (_h != undefined) return _h;
        }
        return hit_test(_mx, _my);
    };

    static _update_hover = function(_mx, _my) {
        var _hit = control_at(_mx, _my);
        if (_hit != hover) {
            var _old = hover;
            hover = _hit;
            if (_old != undefined) _old.mouse_leave();
            if (_hit != undefined) _hit.mouse_enter();
        }
        return _hit;
    };

    static _mouse_press = function(_btn, _mx, _my) {
        if (capture != undefined) return;
        var _hit = control_at(_mx, _my);
        // A press outside every popup closes them all, and does nothing else (Windows menu behaviour).
        if (array_length(popups) > 0 && (_hit == undefined || !_in_popup(_hit))) {
            close_popups();
            return;
        }
        if (_hit == undefined || !_hit.is_enabled()) return;
        capture = _hit;
        capture_button = _btn;
        if (_hit.tab_stop) set_focus(_hit);
        _hit.mouse_down(_mx - _hit._sx, _my - _hit._sy, _btn);

        if (_btn == mb_right && array_length(popups) == 0) {
            var _c = _hit;
            while (_c != undefined && _c.popup_menu == undefined) _c = _c.parent;
            if (_c != undefined) _c.popup_menu.popup(_mx - _sx, _my - _sy, _hit, self);
        }
    };

    static _mouse_release = function(_btn, _mx, _my) {
        if (capture == undefined || capture_button != _btn) return;
        var _c = capture;
        capture = undefined;
        capture_button = -1;
        _c.mouse_up(_mx - _c._sx, _my - _c._sy, _btn);
        if (_btn == mb_left && control_at(_mx, _my) == _c && _c.is_enabled()) _c.click();
    };

    static _mouse_move_to = function(_mx, _my) {
        var _target = capture ?? control_at(_mx, _my);
        if (_target != undefined && _target.is_enabled()) {
            _target.mouse_move(_mx - _target._sx, _my - _target._sy);
        }
    };

    /// Wheel bubbles from the control under the mouse up to the form until handled.
    static _mouse_wheel_at = function(_wd, _mx, _my) {
        var _t = control_at(_mx, _my);
        while (_t != undefined) {
            if (_t.is_enabled() && _t.mouse_wheel(_wd)) break;
            _t = _t.parent;
        }
    };

    /// @func simulate_click(gui_x, gui_y, [button])
    /// @desc Runs a press + release at a point through the same code as real input (for tests and scripts).
    static simulate_click = function(_mx, _my, _btn = mb_left) {
        layout();
        _update_hover(_mx, _my);
        _mouse_move_to(_mx, _my);       // a real click is preceded by the mouse arriving there
        _mouse_press(_btn, _mx, _my);
        layout();
        _mouse_release(_btn, _mx, _my);
        layout();
    };

    /// @func simulate_move(gui_x, gui_y)
    /// @desc Moves the (virtual) mouse through the same code as real input.
    static simulate_move = function(_mx, _my) {
        layout();
        _update_hover(_mx, _my);
        _mouse_move_to(_mx, _my);
    };

    /// @func simulate_key(key)
    /// @desc Routes one key press exactly like a real one (Tab, popups, focused control).
    static simulate_key = function(_key) {
        _route_key_down(_key, false);
    };

    // -----------------------------------------------------------------------
    // Keyboard
    // -----------------------------------------------------------------------

    static _update_keys = function() {
        var _ctrl = keyboard_check(vk_control);
        var _shift = keyboard_check(vk_shift);
        var _alt = keyboard_check(vk_alt);

        // Candidate shortcut: Ctrl/Alt + key, or F1–F12. Offered after the focused control had its chance.
        var _sk = keyboard_key;
        if (_sk <= 0 || !keyboard_check_pressed(_sk) || !gmforms_is_shortcut_key(_sk, _ctrl, _alt)) _sk = -1;

        if (keyboard_check_pressed(vk_tab)) {
            _route_key_down(vk_tab, _shift);
            return;
        }

        if (array_length(popups) > 0) {
            var _n = array_length(_nav_keys);
            for (var _i = 0; _i < _n; _i++) {
                if (keyboard_check_pressed(_nav_keys[_i])) _route_key_down(_nav_keys[_i], _shift);
            }
            keyboard_string = "";   // typed text doesn't leak to the focused control behind a popup
            return;
        }

        if (focused != undefined) {
            var _n = array_length(_nav_keys);
            for (var _i = 0; _i < _n; _i++) {
                var _k = _nav_keys[_i];
                if (keyboard_check_pressed(_k)) _route_key_down(_k, _shift);
                // focus may change inside a handler
                if (focused == undefined) break;
                if (keyboard_check_released(_k)) focused.key_up(_k);
                if (focused == undefined) break;
                if (array_length(popups) > 0) break;
            }
        }

        if (focused != undefined && _ctrl && array_length(popups) == 0) {
            var _cn = array_length(_clipboard_keys);
            for (var _i = 0; _i < _cn; _i++) {
                var _k = _clipboard_keys[_i];
                if (keyboard_check_pressed(_k) && focused.key_down(_k) && _k == _sk) _sk = -1;
                if (focused == undefined) break;
            }
        }

        if (_sk >= 0) dispatch_shortcut(_sk, _ctrl, _shift, _alt);

        // Printable typed characters. GMF_Form is the sole consumer of keyboard_string (cleared after
        // reading each frame) — a control needing typed text should implement key_char, not read it directly.
        if (keyboard_string != "") {
            var _s = keyboard_string;
            keyboard_string = "";
            if (focused == undefined || array_length(popups) > 0) return;
            var _len = string_length(_s);
            for (var _i = 1; _i <= _len; _i++) {
                var _ch = string_char_at(_s, _i);
                if (ord(_ch) >= 32) focused.key_char(_ch);
                if (focused == undefined) return;
            }
        }
    };

    /// One pressed key: Tab moves focus (closing popups), Escape closes the top popup, other keys go
    /// to the top popup if any, else to the focused control.
    static _route_key_down = function(_k, _shift) {
        if (_k == vk_tab) {
            close_popups();
            focus_next(_shift ? -1 : 1);
            return;
        }
        var _top = top_popup();
        if (_top != undefined) {
            if (_k == vk_escape) close_popup(_top);
            else _top.key_down(_k);
            return;
        }
        if (focused != undefined) focused.key_down(_k);
    };

    /// @func dispatch_shortcut(key, ctrl, shift, alt)
    /// @desc Offers a shortcut to every visible, enabled control's handle_shortcut() (depth first)
    ///       until one returns true. Returns true if it was handled.
    static dispatch_shortcut = function(_key, _ctrl, _shift, _alt) {
        return _offer_shortcut(self, _key, _ctrl, _shift, _alt);
    };

    static _offer_shortcut = function(_c, _key, _ctrl, _shift, _alt) {
        if (!_c.visible || !_c.enabled) return false;
        if (_c.handle_shortcut(_key, _ctrl, _shift, _alt)) return true;
        var _n = array_length(_c.children);
        for (var _i = 0; _i < _n; _i++) {
            if (_offer_shortcut(_c.children[_i], _key, _ctrl, _shift, _alt)) return true;
        }
        return false;
    };

    // -----------------------------------------------------------------------
    // Drawing (call from Draw GUI)
    // -----------------------------------------------------------------------

    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, color ?? _th.form_bg);
    };

    /// @func render()
    /// @desc Lays out (if needed) and draws the whole form, then the open popups on top.
    ///       Restores colour, alpha, alignment, font and scissor afterwards.
    static render = function() {
        layout();

        var _col = draw_get_colour();
        var _alpha = draw_get_alpha();
        var _ha = draw_get_halign();
        var _va = draw_get_valign();
        var _font = draw_get_font();

        // The scissor at the start of Draw GUI covers the whole back buffer. Comparing it with the
        // GUI size gives the GUI -> render-target scale (1 in the normal case, see decision D5).
        var _prev_sc = gpu_get_scissor();
        var _gw = display_get_gui_width();
        var _gh = display_get_gui_height();
        var _scx = (_gw > 0 && _prev_sc.w > 0) ? _prev_sc.w / _gw : 1;
        var _scy = (_gh > 0 && _prev_sc.h > 0) ? _prev_sc.h / _gh : 1;
        gmforms_scissor_reset(0, 0, _gw, _gh, _scx, _scy);
        draw_set_alpha(1);

        draw_tree();

        var _th = gmforms_theme();
        var _n = array_length(popups);
        for (var _i = 0; _i < _n; _i++) {
            var _p = popups[_i];
            gmforms_scissor_reset(0, 0, _gw, _gh, _scx, _scy);
            draw_set_alpha(0.35);
            gmforms_draw_rect(_p._sx + 3, _p._sy + 3, _p.width, _p.height, _th.popup_shadow);
            draw_set_alpha(1);
            _p.draw_tree();
        }

        gpu_set_scissor(_prev_sc.x, _prev_sc.y, _prev_sc.w, _prev_sc.h);
        draw_set_colour(_col);
        draw_set_alpha(_alpha);
        draw_set_halign(_ha);
        draw_set_valign(_va);
        if (_font != -1) draw_set_font(_font);
    };
}

/// @func gmforms_is_shortcut_key(key, ctrl, alt)
/// @desc True for keys that are offered as shortcuts: Ctrl/Alt + a non-modifier key, or F1–F12.
function gmforms_is_shortcut_key(_k, _ctrl, _alt) {
    if (_k >= vk_f1 && _k <= vk_f12) return true;
    if (!_ctrl && !_alt) return false;
    switch (_k) {
        case vk_control: case vk_shift: case vk_alt:
        case vk_lcontrol: case vk_rcontrol: case vk_lshift: case vk_rshift: case vk_lalt: case vk_ralt:
            return false;
    }
    return true;
}
