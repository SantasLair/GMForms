/// GMForms — GMF_Form: the root control. Owns hover/capture/focus (input manager) and drives layout.
///
/// A form's width/height when it is first laid out are its *design size*: anchored children
/// capture their distances to the edges at that size, then the host resizes the form to the
/// window and everything reflows (Delphi behaviour).

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

    /// Clears hover/capture/focus if they point into a subtree that is being hidden, disabled or removed.
    static _forget_subtree = function(_root) {
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
        var _hit = hit_test(_mx, _my);

        // hover
        if (_hit != hover) {
            var _old = hover;
            hover = _hit;
            if (_old != undefined) _old.mouse_leave();
            if (_hit != undefined) _hit.mouse_enter();
        }

        // buttons
        for (var _b = 0; _b < 3; _b++) {
            var _btn = _mouse_buttons[_b];

            if (mouse_check_button_pressed(_btn) && capture == undefined) {
                if (_hit != undefined && _hit.is_enabled()) {
                    capture = _hit;
                    capture_button = _btn;
                    if (_hit.tab_stop) set_focus(_hit);
                    _hit.mouse_down(_mx - _hit._sx, _my - _hit._sy, _btn);
                }
            }

            if (mouse_check_button_released(_btn) && capture != undefined && capture_button == _btn) {
                var _c = capture;
                capture = undefined;
                capture_button = -1;
                _c.mouse_up(_mx - _c._sx, _my - _c._sy, _btn);
                if (_btn == mb_left && _hit == _c && _c.is_enabled()) _c.click();
            }
        }

        // move
        if (_mx != _last_mx || _my != _last_my) {
            _last_mx = _mx;
            _last_my = _my;
            var _target = capture ?? _hit;
            if (_target != undefined && _target.is_enabled()) {
                _target.mouse_move(_mx - _target._sx, _my - _target._sy);
            }
        }

        // wheel: bubbles from the hovered control up to the form until handled
        var _wd = mouse_wheel_down() - mouse_wheel_up();
        if (_wd != 0) {
            var _t = _hit;
            while (_t != undefined) {
                if (_t.is_enabled() && _t.mouse_wheel(_wd)) break;
                _t = _t.parent;
            }
        }

        _update_keys();
    };

    static _update_keys = function() {
        if (keyboard_check_pressed(vk_tab)) {
            focus_next(keyboard_check(vk_shift) ? -1 : 1);
            return;
        }
        if (focused == undefined) return;
        var _n = array_length(_nav_keys);
        for (var _i = 0; _i < _n; _i++) {
            var _k = _nav_keys[_i];
            if (keyboard_check_pressed(_k)) focused.key_down(_k);
            // focus may change inside a handler
            if (focused == undefined) return;
            if (keyboard_check_released(_k)) focused.key_up(_k);
            if (focused == undefined) return;
        }

        if (keyboard_check(vk_control)) {
            var _cn = array_length(_clipboard_keys);
            for (var _i = 0; _i < _cn; _i++) {
                var _k = _clipboard_keys[_i];
                if (keyboard_check_pressed(_k)) focused.key_down(_k);
                if (focused == undefined) return;
            }
        }

        // Printable typed characters. GMF_Form is the sole consumer of keyboard_string (cleared after
        // reading each frame) — a control needing typed text should implement key_char, not read it directly.
        if (keyboard_string != "") {
            var _s = keyboard_string;
            keyboard_string = "";
            var _len = string_length(_s);
            for (var _i = 1; _i <= _len; _i++) {
                var _ch = string_char_at(_s, _i);
                if (ord(_ch) >= 32) focused.key_char(_ch);
                if (focused == undefined) return;
            }
        }
    };

    // -----------------------------------------------------------------------
    // Drawing (call from Draw GUI)
    // -----------------------------------------------------------------------

    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, color ?? _th.form_bg);
    };

    /// @func render()
    /// @desc Lays out (if needed) and draws the whole form. Call from the Draw GUI event.
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

        gpu_set_scissor(_prev_sc.x, _prev_sc.y, _prev_sc.w, _prev_sc.h);
        draw_set_colour(_col);
        draw_set_alpha(_alpha);
        draw_set_halign(_ha);
        draw_set_valign(_va);
        if (_font != -1) draw_set_font(_font);
    };
}
