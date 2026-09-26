/// GMForms — GMF_Edit: single-line text with caret, selection, clipboard, scroll, password mode.
/// No multi-line editing — Memo (Tier 3) is out of scope.

/// @func GMF_Edit()
/// @desc Single-line text box. Fires on_change(sender, text) on any edit.
function GMF_Edit() : GMF_Control() constructor {
    class_name = "Edit";
    text = "";
    password = false;
    width = 120;
    height = 24;
    tab_stop = true;
    _caret = 0;
    _sel_anchor = 0;   // == _caret means no selection
    _scroll_x = 0;     // pixel horizontal scroll offset
    _focus_proxy = undefined;   // control whose focus this Edit shows (PropertyGrid's in-place editor)
    _inset_r = 0;               // pixels on the right kept free of text (GMF_SpinEdit draws its buttons there)

    static published = array_concat(gmforms_base_published(), [
        { name: "text",     type: "string", default_value: "" },
        { name: "password", type: "bool",   default_value: false },
        { name: "width",    type: "int",    default_value: 120 },
        { name: "height",   type: "int",    default_value: 24 },
    ]);

    /// @func is_focused()
    /// @desc True if this Edit (or its _focus_proxy, for an in-place editor) has keyboard focus.
    static is_focused = function() {
        var _c = _focus_proxy ?? self;
        var _f = _c.get_form();
        return (_f != undefined && _f.focused == _c);
    };

    static _visible_text = function() {
        return password ? string_repeat("*", string_length(text)) : text;
    };

    /// Character index nearest a local x, accounting for scroll. Used by mouse_down/mouse_move.
    static _index_at_x = function(_local_x) {
        var _th = gmforms_theme();
        if (_th.font != -1) draw_set_font(_th.font);
        var _vis = _visible_text();
        var _len = string_length(_vis);
        var _target = _local_x + _scroll_x - _th.text_padding;
        var _prev_w = 0;
        for (var _i = 1; _i <= _len; _i++) {
            var _w = string_width(string_copy(_vis, 1, _i));
            if (_target < (_prev_w + _w) * 0.5) return _i - 1;
            _prev_w = _w;
        }
        return _len;
    };

    /// Adjusts _scroll_x so the caret stays within the visible width.
    static _ensure_caret_visible = function() {
        var _th = gmforms_theme();
        if (_th.font != -1) draw_set_font(_th.font);
        var _caret_px = string_width(string_copy(_visible_text(), 1, _caret));
        var _view_w = max(0, width - _inset_r - _th.text_padding * 2);
        if (_caret_px - _scroll_x > _view_w) _scroll_x = _caret_px - _view_w;
        if (_caret_px - _scroll_x < 0) _scroll_x = _caret_px;
        _scroll_x = max(0, _scroll_x);
    };

    static _fire_change = function() { if (is_callable(on_change)) on_change(self, text); };

    /// Deletes the current selection (if any). Returns true if it deleted something.
    static _delete_selection = function() {
        var _a = min(_caret, _sel_anchor), _b = max(_caret, _sel_anchor);
        if (_b <= _a) return false;
        text = string_delete(text, _a + 1, _b - _a);
        _caret = _a; _sel_anchor = _a;
        _fire_change();
        return true;
    };

    /// Replaces the selection (if any) with _s, then places the caret after it.
    static _insert_text = function(_s) {
        _delete_selection();
        text = string_insert(_s, text, _caret + 1);
        _caret += string_length(_s);
        _sel_anchor = _caret;
        _fire_change();
        _ensure_caret_visible();
    };

    static _move_caret = function(_new_pos, _extend) {
        _caret = clamp(_new_pos, 0, string_length(text));
        if (!_extend) _sel_anchor = _caret;
        _ensure_caret_visible();
    };

    /// @func select_all()
    static select_all = function() { _sel_anchor = 0; _caret = string_length(text); _ensure_caret_visible(); };

    /// @func copy()
    /// @desc Copies the current selection to the OS clipboard. Fails softly if unavailable.
    static copy = function() {
        var _a = min(_caret, _sel_anchor), _b = max(_caret, _sel_anchor);
        if (_b <= _a) return;
        try { clipboard_set_text(string_copy(text, _a + 1, _b - _a)); }
        catch (_e) { gmforms_log("Edit: clipboard_set_text failed: " + string(_e)); }
    };

    /// @func cut()
    static cut = function() { copy(); _delete_selection(); };

    /// @func paste()
    /// @desc Inserts OS clipboard text at the caret, replacing the selection. Fails softly if unavailable.
    static paste = function() {
        var _s = "";
        try { if (clipboard_has_text()) _s = clipboard_get_text(); }
        catch (_e) { gmforms_log("Edit: clipboard_get_text failed: " + string(_e)); }
        if (_s != "") _insert_text(_s);
    };

    static key_char = function(_ch) {
        if (!is_enabled()) return;
        if (ord(_ch) < 32) return;
        _insert_text(_ch);
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        return _edit_key(_key);
    };

    /// The editing keys, without the user event (subclasses such as GMF_SpinEdit call this directly).
    static _edit_key = function(_key) {
        if (!is_enabled()) return false;
        var _ctrl = keyboard_check(vk_control);
        var _shift = keyboard_check(vk_shift);
        var _has_sel = (_sel_anchor != _caret);

        if (_ctrl && _key == ord("A")) { select_all(); return true; }
        if (_ctrl && _key == ord("C")) { copy(); return true; }
        if (_ctrl && _key == ord("X")) { cut(); return true; }
        if (_ctrl && _key == ord("V")) { paste(); return true; }

        switch (_key) {
            case vk_left:
                _move_caret((_has_sel && !_shift) ? min(_caret, _sel_anchor) : _caret - 1, _shift);
                return true;
            case vk_right:
                _move_caret((_has_sel && !_shift) ? max(_caret, _sel_anchor) : _caret + 1, _shift);
                return true;
            case vk_home: _move_caret(0, _shift); return true;
            case vk_end:  _move_caret(string_length(text), _shift); return true;
            case vk_backspace:
                if (_has_sel) _delete_selection();
                else if (_caret > 0) { text = string_delete(text, _caret, 1); _caret--; _sel_anchor = _caret; _fire_change(); }
                _ensure_caret_visible();
                return true;
            case vk_delete:
                if (_has_sel) _delete_selection();
                else if (_caret < string_length(text)) { text = string_delete(text, _caret + 1, 1); _fire_change(); }
                _ensure_caret_visible();
                return true;
        }
        return false;
    };

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        _edit_mouse_down(_x, _y, _btn);
    };

    /// Caret placement on press, without the user event.
    static _edit_mouse_down = function(_x, _y, _btn) {
        if (_btn != mb_left) return;
        var _idx = _index_at_x(_x);
        _caret = _idx;
        if (!keyboard_check(vk_shift)) _sel_anchor = _idx;
        _ensure_caret_visible();
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        var _f = get_form();
        if (_f == undefined || _f.capture != self) return;
        _caret = _index_at_x(_x);
        _ensure_caret_visible();
    };

    // Draws text manually (not via gmforms_draw_text_in) — it needs the live -_scroll_x offset.
    static draw = function() {
        var _th = gmforms_theme();
        var _en = is_enabled();
        gmforms_draw_rect(_sx, _sy, width - _inset_r, height, _en ? _th.edit_bg : _th.edit_bg_disabled);

        var _vis = _visible_text();
        if (_th.font != -1) draw_set_font(_th.font);
        var _pad = _th.text_padding;

        if (_sel_anchor != _caret) {
            var _a = min(_caret, _sel_anchor), _b = max(_caret, _sel_anchor);
            var _xa = _sx + _pad - _scroll_x + string_width(string_copy(_vis, 1, _a));
            var _xb = _sx + _pad - _scroll_x + string_width(string_copy(_vis, 1, _b));
            gmforms_draw_rect(_xa, _sy + 2, _xb - _xa, height - 4, _th.edit_selection);
        }

        if (gmforms_scissor_push(_sx, _sy, width - _inset_r, height)) {
            draw_set_colour(_en ? _th.text : _th.text_disabled);
            draw_set_halign(fa_left); draw_set_valign(fa_middle);
            draw_text(floor(_sx + _pad - _scroll_x), floor(_sy + height * 0.5), _vis);
        }
        gmforms_scissor_pop();

        if (is_focused() && (current_time div 500) mod 2 == 0) {
            var _cx = floor(_sx + _pad - _scroll_x + string_width(string_copy(_vis, 1, _caret)));
            gmforms_draw_rect(_cx, _sy + 3, 1, height - 6, _th.edit_caret);
        }
    };

    static draw_overlay = function() {
        var _th = gmforms_theme();
        if (is_focused()) gmforms_draw_frame(_sx, _sy, width, height, _th.focus, 2);
        else gmforms_draw_frame(_sx, _sy, width, height, _th.edit_border);
    };
}
