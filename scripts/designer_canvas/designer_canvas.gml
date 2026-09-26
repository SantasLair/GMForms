/// GMForms designer — GMF_DesignCanvas: shows the form being designed and edits it with the mouse and
/// keyboard (plan section 14).
///
/// The designed form is a real GMF_Form: the runtime in "design mode". The canvas lays it out and
/// draws it, but never calls its update(), so none of its events fire and clicks only select.
///
///   click                 select (clicking a TabControl's tab also switches the page)
///   drag a control        move it (snapped); drop it on another container to reparent it
///   drag a handle         resize (aligned controls only along their free edge; the form by its
///                         right/bottom edge, which changes its design size)
///   palette armed         click to place a control at its default size, or drag out its rect
///   arrows / Shift+arrows nudge by 1 px / one grid step       Delete  delete
///   Escape                cancel placing, else select the parent
///   middle-drag / wheel   pan the view (Shift+wheel scrolls sideways)
///
/// Every committed change fires on_modified(sender, label); the designer takes an undo snapshot there.

/// @func gmforms_design_is_container(control)
/// @desc Controls the designer lets you drop other controls into. A custom class can opt in with a
///       `design_container = true` field.
function gmforms_design_is_container(_c) {
    switch (_c.class_name) {
        case "Form": case "Panel": case "TabSheet": case "Toolbar":
            return true;
    }
    return _c[$ "design_container"] == true;
}

/// @func GMF_DesignCanvas()
function GMF_DesignCanvas() : GMF_Control() constructor {
    class_name = "DesignCanvas";
    tab_stop = true;
    target = undefined;         // the GMF_Form being designed
    selected = undefined;
    grid_size = 8;
    snap = true;
    show_grid = true;
    place_class = "";           // palette class waiting to be placed ("" = none)
    offset_x = 24;              // the form's top-left inside the canvas (middle-drag pans)
    offset_y = 40;
    on_select = undefined;      // (sender, control)
    on_modified = undefined;    // (sender, label) — a change was committed
    on_placed = undefined;      // (sender, control or undefined) — placement finished or cancelled

    _drag = "";                 // "", "pan", "create", "move", "resize", "form"
    _handle = -1;
    _start_x = 0;
    _start_y = 0;
    _orig = undefined;
    _moved = false;
    _create_parent = undefined;
    _create_rect = undefined;
    _drop_target = undefined;
    static _hs = 7;             // handle size

    // -----------------------------------------------------------------------
    // Target, layout, selection
    // -----------------------------------------------------------------------

    /// @func set_target(form)
    static set_target = function(_form) {
        target = _form;
        selected = undefined;
        _drag = "";
        select(_form);
    };

    /// Lays the designed form out at its design size, drawn at the canvas offset.
    static _layout_target = function() {
        if (target == undefined) return;
        if (!target._design_done) target._design_pass();
        target._sx = _sx + offset_x;
        target._sy = _sy + offset_y;
        target.layout_tree();
    };

    /// @func select(control)
    /// @desc Selects a control (undefined = the form). A control on a hidden tab page brings that page to the front.
    static select = function(_c) {
        if (_c == undefined) _c = target;
        var _p = _c;
        while (_p != undefined && _p.parent != undefined) {
            if (_p.class_name == "TabSheet" && _p.parent.class_name == "TabControl") {
                var _idx = array_get_index(_p.parent.pages(), _p);
                if (_idx >= 0 && _p.parent.tab_index != _idx) _p.parent.set_tab_index(_idx, false);
            }
            _p = _p.parent;
        }
        if (selected == _c) return;
        selected = _c;
        if (is_callable(on_select)) on_select(self, _c);
    };

    /// @func select_parent()
    static select_parent = function() {
        if (selected != undefined && selected != target) select(selected.parent);
    };

    static _modified = function(_label) {
        if (is_callable(on_modified)) on_modified(self, _label);
    };

    static _snap = function(_v) {
        return (snap && grid_size > 1) ? round(_v / grid_size) * grid_size : round(_v);
    };

    // -----------------------------------------------------------------------
    // Hit testing (GUI coordinates)
    // -----------------------------------------------------------------------

    static _hit = function(_c, _gx, _gy, _exclude) {
        if (_c == _exclude || !_c.visible || _c.width <= 0 || _c.height <= 0) return undefined;
        if (_gx < _c._sx || _gy < _c._sy || _gx >= _c._sx + _c.width || _gy >= _c._sy + _c.height) return undefined;
        for (var _i = array_length(_c.children) - 1; _i >= 0; _i--) {
            var _h = _hit(_c.children[_i], _gx, _gy, _exclude);
            if (_h != undefined) return _h;
        }
        return _c;
    };

    /// @func control_at(gui_x, gui_y)
    /// @desc Deepest designed control under a point, or undefined outside the form.
    static control_at = function(_gx, _gy) {
        _layout_target();
        return (target == undefined) ? undefined : _hit(target, _gx, _gy, undefined);
    };

    /// @func container_at(gui_x, gui_y, [exclude])
    /// @desc Innermost container under a point (a TabControl counts as its active page), ignoring
    ///       the `exclude` subtree (the control being dragged).
    static container_at = function(_gx, _gy, _exclude = undefined) {
        _layout_target();
        if (target == undefined) return undefined;
        var _c = _hit(target, _gx, _gy, _exclude);
        while (_c != undefined) {
            if (_c.class_name == "TabControl") {
                var _pg = _c.get_page();
                if (_pg != undefined) return _pg;
            }
            if (gmforms_design_is_container(_c)) return _c;
            _c = _c.parent;
        }
        return undefined;
    };

    /// Handles each selection allows: 0 tl, 1 t, 2 tr, 3 r, 4 br, 5 b, 6 bl, 7 l.
    static _allowed_handles = function(_c) {
        if (_c == undefined) return [];
        if (_c == target) return [3, 4, 5];
        switch (_c.align) {
            case "none":   return [0, 1, 2, 3, 4, 5, 6, 7];
            case "top":    return [5];
            case "bottom": return [1];
            case "left":   return [3];
            case "right":  return [7];
        }
        return [];
    };

    static _handle_pos = function(_c, _h) {
        var _x = _c._sx, _y = _c._sy, _w = _c.width, _hh = _c.height;
        switch (_h) {
            case 0: return { x: _x,          y: _y };
            case 1: return { x: _x + _w / 2, y: _y };
            case 2: return { x: _x + _w,     y: _y };
            case 3: return { x: _x + _w,     y: _y + _hh / 2 };
            case 4: return { x: _x + _w,     y: _y + _hh };
            case 5: return { x: _x + _w / 2, y: _y + _hh };
            case 6: return { x: _x,          y: _y + _hh };
            case 7: return { x: _x,          y: _y + _hh / 2 };
        }
        return { x: _x, y: _y };
    };

    static _handle_at = function(_gx, _gy) {
        if (selected == undefined || !selected.is_showing()) return -1;
        var _hs2 = _hs / 2 + 1;
        var _list = _allowed_handles(selected);
        for (var _i = 0; _i < array_length(_list); _i++) {
            var _p = _handle_pos(selected, _list[_i]);
            if (abs(_gx - _p.x) <= _hs2 && abs(_gy - _p.y) <= _hs2) return _list[_i];
        }
        return -1;
    };

    // -----------------------------------------------------------------------
    // Editing operations (also the designer's scripting API)
    // -----------------------------------------------------------------------

    /// @func unique_name(prefix)
    /// @desc prefix + the lowest number not used by any control in the form, e.g. "Button3".
    static unique_name = function(_prefix) {
        var _n = 1;
        while (target.find(_prefix + string(_n)) != undefined) _n++;
        return _prefix + string(_n);
    };

    /// @func create_control(class_name, parent, left, top, [width], [height])
    /// @desc Creates a registered class inside parent, names it uniquely, selects it and commits.
    ///       A caption equal to the class name (Button, Label, CheckBox) becomes the control's name.
    /// @returns {Struct|Undefined}
    static create_control = function(_class, _parent, _l, _t, _w = undefined, _h = undefined) {
        var _ctor = gmforms_init().registry[$ _class];
        if (_ctor == undefined || _parent == undefined) {
            gmforms_log("designer: can't create '" + string(_class) + "'");
            return undefined;
        }
        if (_parent.class_name == "TabControl") _parent = _parent.get_page() ?? _parent;
        var _c = new _ctor();
        _c.name = unique_name(_class);
        if (_c[$ "caption"] == _class) _c.caption = _c.name;
        _c.set_bounds(_l, _t, _w ?? _c.width, _h ?? _c.height);
        _parent.add(_c);
        if (_class == "TabControl") {
            var _pg = _c.add_page("");
            _pg.name = unique_name("TabSheet");
            _pg.caption = _pg.name;
        }
        select(_c);
        _modified("Create " + _c.name);
        return _c;
    };

    /// @func delete_selected()
    static delete_selected = function() {
        if (selected == undefined || selected == target) return false;
        var _c = selected;
        var _p = _c.parent;
        _p.remove(_c);
        if (_p.class_name == "TabControl") _p.set_tab_index(_p.tab_index, false);
        select(_p);
        _modified("Delete " + _c.name);
        return true;
    };

    /// @func move_selected(left, top)
    /// @desc Moves an anchored (align "none") selection and commits.
    static move_selected = function(_l, _t) {
        if (selected == undefined || selected == target || selected.align != "none") return false;
        selected.set_bounds(_l, _t, selected.width, selected.height);
        _modified("Move " + selected.name);
        return true;
    };

    /// @func nudge(dx, dy)
    static nudge = function(_dx, _dy) {
        if (selected == undefined || selected == target || selected.align != "none") return false;
        return move_selected(selected.left + _dx, selected.top + _dy);
    };

    /// @func reparent(control, new_parent)
    /// @desc Moves a control into another container, keeping its position on screen. Commits.
    static reparent = function(_c, _newp) {
        if (_c == undefined || _newp == undefined || _c == target || _c.is_ancestor_of(_newp)) return false;
        if (_newp.class_name == "TabControl") _newp = _newp.get_page() ?? _newp;
        if (_newp == _c.parent) return false;
        _layout_target();
        var _gx = _c._sx, _gy = _c._sy;
        _newp.add(_c);
        _c.set_bounds(_gx - _newp._sx, _gy - _newp._sy, _c.width, _c.height);
        select(_c);
        _modified("Move " + _c.name + " into " + _newp.name);
        return true;
    };

    /// @func bring_to_front() / send_to_back()
    /// @desc Changes the selection's position among its siblings (last = drawn on top; for aligned
    ///       controls it is also the Align processing order).
    static bring_to_front = function() { return _restack(true); };
    static send_to_back = function() { return _restack(false); };

    static _restack = function(_front) {
        if (selected == undefined || selected == target) return false;
        var _sib = selected.parent.children;
        var _i = array_get_index(_sib, selected);
        array_delete(_sib, _i, 1);
        if (_front) array_push(_sib, selected); else array_insert(_sib, 0, selected);
        selected.parent.invalidate_layout();
        _modified((_front ? "Bring to front " : "Send to back ") + selected.name);
        return true;
    };

    /// @func add_tab_page()
    /// @desc Adds a page to the selected TabControl (or the one owning the selected page).
    static add_tab_page = function() {
        var _tc = selected;
        if (_tc != undefined && _tc.class_name == "TabSheet") _tc = _tc.parent;
        if (_tc == undefined || _tc.class_name != "TabControl") return undefined;
        var _pg = _tc.add_page("");
        _pg.name = unique_name("TabSheet");
        _pg.caption = _pg.name;
        _tc.set_tab_index(array_length(_tc.pages()) - 1, false);
        select(_pg);
        _modified("Add page " + _pg.name);
        return _pg;
    };

    /// After the form's design size changes, anchored controls have moved: make their current
    /// rects the new design rects (otherwise saving would write the old ones).
    static _recapture_anchors = function() {
        target.walk(function(_c) {
            _c._anchor_captured = false;
            _c._layout_dirty = true;
        });
    };

    /// @func set_form_size(width, height)
    static set_form_size = function(_w, _h) {
        target.width = max(40, _w);
        target.height = max(40, _h);
        target._layout_dirty = true;
        _layout_target();
        _recapture_anchors();
        _modified("Resize form");
    };

    // -----------------------------------------------------------------------
    // Mouse and keyboard
    // -----------------------------------------------------------------------

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        _layout_target();
        if (target == undefined) return;
        var _gx = _sx + _x, _gy = _sy + _y;
        _start_x = _gx;
        _start_y = _gy;
        _moved = false;

        if (_btn == mb_middle) {
            _drag = "pan";
            _orig = { l: offset_x, t: offset_y };
            return;
        }
        if (_btn == mb_right) {
            var _rc = control_at(_gx, _gy);
            if (_rc != undefined) select(_rc);
            return;     // the form opens popup_menu next
        }
        if (_btn != mb_left) return;

        if (place_class != "") {
            var _p = container_at(_gx, _gy);
            if (_p == undefined) return;
            _create_parent = _p;
            var _x0 = _p._sx + _snap(_gx - _p._sx);
            var _y0 = _p._sy + _snap(_gy - _p._sy);
            _create_rect = { x1: _x0, y1: _y0, x2: _x0, y2: _y0 };
            _drag = "create";
            return;
        }

        var _h = _handle_at(_gx, _gy);
        if (_h >= 0) {
            _handle = _h;
            _orig = { l: selected.left, t: selected.top, w: selected.width, h: selected.height };
            _drag = (selected == target) ? "form" : "resize";
            return;
        }

        var _c = control_at(_gx, _gy);
        if (_c == undefined) { select(target); return; }
        if (_c.class_name == "TabControl") {
            var _tab = _c._tab_at(_gx - _c._sx, _gy - _c._sy);
            if (_tab >= 0) _c.set_tab_index(_tab, false);
        }
        select(_c);
        if (_c != target && _c.align == "none") {
            _drag = "move";
            _orig = { l: _c.left, t: _c.top, w: _c.width, h: _c.height };
            _drop_target = _c.parent;
        }
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        var _f = get_form();
        if (_drag == "" || _f == undefined || _f.capture != self) return;
        _layout_target();
        var _gx = _sx + _x, _gy = _sy + _y;
        var _dx = _gx - _start_x, _dy = _gy - _start_y;
        if (abs(_dx) + abs(_dy) >= 3) _moved = true;
        switch (_drag) {
            case "pan":
                offset_x = _orig.l + _dx;
                offset_y = _orig.t + _dy;
                break;
            case "create":
                _create_rect.x2 = _create_parent._sx + _snap(_gx - _create_parent._sx);
                _create_rect.y2 = _create_parent._sy + _snap(_gy - _create_parent._sy);
                break;
            case "move":
                if (!_moved) break;
                selected.set_bounds(_snap(_orig.l + _dx), _snap(_orig.t + _dy), _orig.w, _orig.h);
                _layout_target();
                _drop_target = container_at(_gx, _gy, selected) ?? selected.parent;
                break;
            case "resize":
                _resize_to(_dx, _dy);
                break;
            case "form":
                var _w = (_handle == 3 || _handle == 4) ? _snap(_orig.w + _dx) : _orig.w;
                var _h = (_handle == 5 || _handle == 4) ? _snap(_orig.h + _dy) : _orig.h;
                target.width = max(40, _w);
                target.height = max(40, _h);
                target._layout_dirty = true;
                break;
        }
    };

    static _resize_to = function(_dx, _dy) {
        var _l = _orig.l, _t = _orig.t, _r = _orig.l + _orig.w, _b = _orig.t + _orig.h;
        if (_handle == 0 || _handle == 6 || _handle == 7) _l = min(_snap(_orig.l + _dx), _r - 4);
        if (_handle == 2 || _handle == 3 || _handle == 4) _r = max(_snap(_r + _dx), _l + 4);
        if (_handle == 0 || _handle == 1 || _handle == 2) _t = min(_snap(_orig.t + _dy), _b - 4);
        if (_handle == 4 || _handle == 5 || _handle == 6) _b = max(_snap(_b + _dy), _t + 4);
        if (selected.align == "none") selected.set_bounds(_l, _t, _r - _l, _b - _t);
        else selected.set({ width: _r - _l, height: _b - _t });
    };

    static mouse_up = function(_x, _y, _btn) {
        if (is_callable(on_mouse_up)) on_mouse_up(self, _x, _y, _btn);
        var _d = _drag;
        _drag = "";
        switch (_d) {
            case "create":
                var _r = _create_rect;
                var _cls = place_class;
                var _px = min(_r.x1, _r.x2) - _create_parent._sx;
                var _py = min(_r.y1, _r.y2) - _create_parent._sy;
                var _w = abs(_r.x2 - _r.x1), _h = abs(_r.y2 - _r.y1);
                var _big = (_w >= 8 && _h >= 8);
                if (!keyboard_check(vk_shift)) place_class = "";
                var _c = create_control(_cls, _create_parent, _px, _py, _big ? _w : undefined, _big ? _h : undefined);
                if (is_callable(on_placed)) on_placed(self, _c);
                break;
            case "move":
                if (!_moved) break;
                if (_drop_target != undefined && _drop_target != selected.parent) reparent(selected, _drop_target);
                else _modified("Move " + selected.name);
                break;
            case "resize":
                if (_moved) _modified("Resize " + selected.name);
                break;
            case "form":
                if (_moved) set_form_size(target.width, target.height);
                break;
        }
        _drop_target = undefined;
        _create_rect = undefined;
    };

    /// Wheel scrolls the view (Shift+wheel horizontally).
    static mouse_wheel = function(_delta) {
        if (is_callable(on_mouse_wheel) && on_mouse_wheel(self, _delta) == true) return true;
        if (keyboard_check(vk_shift)) offset_x -= _delta * 48; else offset_y -= _delta * 48;
        return true;
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        var _step = keyboard_check(vk_shift) ? max(1, grid_size) : 1;
        switch (_key) {
            case vk_delete: delete_selected(); return true;
            case vk_escape:
                if (place_class != "") {
                    place_class = "";
                    if (is_callable(on_placed)) on_placed(self, undefined);
                } else select_parent();
                return true;
            case vk_left:  nudge(-_step, 0); return true;
            case vk_right: nudge(_step, 0); return true;
            case vk_up:    nudge(0, -_step); return true;
            case vk_down:  nudge(0, _step); return true;
        }
        return false;
    };

    // -----------------------------------------------------------------------
    // Drawing
    // -----------------------------------------------------------------------

    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, _th.viewport_bg);
        _layout_target();
        if (target == undefined) return;
        var _fx = target._sx, _fy = target._sy, _fw = target.width, _fh = target.height;

        if (gmforms_scissor_push(_sx, _sy, width, height)) {
            // window-style title bar above the form (not part of it)
            gmforms_draw_rect(_fx, _fy - 24, _fw, 24, _th.panel_border);
            gmforms_draw_text_in(_fx, _fy - 24, _fw, 24, target.caption + "   (" + string(_fw) + " x " + string(_fh) + ")",
                _th.text, fa_left, fa_middle, 8);

            target.draw();
            if (show_grid && grid_size >= 4) {
                draw_set_alpha(0.07);
                draw_set_colour(_th.text);
                for (var _gx = grid_size; _gx < _fw; _gx += grid_size) draw_line(_fx + _gx, _fy, _fx + _gx, _fy + _fh);
                for (var _gy = grid_size; _gy < _fh; _gy += grid_size) draw_line(_fx, _fy + _gy, _fx + _fw, _fy + _gy);
                draw_set_alpha(1);
            }
            if (gmforms_scissor_push(_fx, _fy, _fw, _fh)) {
                var _n = array_length(target.children);
                for (var _i = 0; _i < _n; _i++) target.children[_i].draw_tree();
            }
            gmforms_scissor_pop();
            target.draw_overlay();
            gmforms_draw_frame(_fx - 1, _fy - 25, _fw + 2, _fh + 26, _th.panel_border);

            _draw_selection();
        }
        gmforms_scissor_pop();
    };

    static _draw_selection = function() {
        var _th = gmforms_theme();
        if (_drag == "move" && _drop_target != undefined && _drop_target != selected.parent) {
            gmforms_draw_frame(_drop_target._sx, _drop_target._sy, _drop_target.width, _drop_target.height, _th.accent, 2);
        }
        if (_drag == "create" && _create_rect != undefined) {
            var _r = _create_rect;
            gmforms_draw_frame(min(_r.x1, _r.x2), min(_r.y1, _r.y2), max(1, abs(_r.x2 - _r.x1)), max(1, abs(_r.y2 - _r.y1)), _th.accent, 1);
        }
        if (selected == undefined || !selected.is_showing()) return;
        gmforms_draw_frame(selected._sx - 1, selected._sy - 1, selected.width + 2, selected.height + 2, _th.focus, 1);
        var _list = _allowed_handles(selected);
        for (var _i = 0; _i < array_length(_list); _i++) {
            var _p = _handle_pos(selected, _list[_i]);
            var _hx = round(_p.x - _hs / 2), _hy = round(_p.y - _hs / 2);
            gmforms_draw_rect(_hx, _hy, _hs, _hs, _th.text);
            gmforms_draw_frame(_hx, _hy, _hs, _hs, _th.focus);
        }
    };

    static draw_overlay = function() {
        if (is_focused()) gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().focus, 1);
    };
}
