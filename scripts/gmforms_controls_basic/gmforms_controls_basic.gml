/// GMForms — basic controls: Panel, Button, Label, CheckBox, Splitter.
/// M1 draws them with flat theme colours (no sprites yet).

/// @func GMF_Panel()
/// @desc Container with an optional background, border and small caption in the top-left corner.
function GMF_Panel() : GMF_Control() constructor {
    class_name = "Panel";
    caption = "";
    color = undefined;          // background colour; undefined = theme.panel
    transparent = false;        // true = no background fill
    border = true;

    static published = array_concat(gmforms_base_published(), [
        { name: "caption",     type: "string", default_value: "" },
        { name: "color",       type: "color",  default_value: undefined },
        { name: "transparent", type: "bool",   default_value: false },
        { name: "border",      type: "bool",   default_value: true },
    ]);

    static draw = function() {
        var _th = gmforms_theme();
        if (!transparent) gmforms_draw_rect(_sx, _sy, width, height, color ?? _th.panel);
        if (caption != "") {
            gmforms_draw_text_in(_sx, _sy, width, 22, caption, _th.panel_caption, fa_left, fa_middle, _th.text_padding);
        }
    };

    static draw_overlay = function() {
        if (border) gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().panel_border);
    };
}

/// @func GMF_Button()
/// @desc Push button. Fires on_click on mouse release over the button, or Space/Enter while focused.
function GMF_Button() : GMF_Control() constructor {
    class_name = "Button";
    caption = "Button";
    width = 80;
    height = 28;
    tab_stop = true;
    down = false;               // latched pressed look, e.g. the active tool in a toolbar (Delphi SpeedButton.Down)
    _key_down = false;          // Space/Enter held while focused (pressed look)

    static published = array_concat(gmforms_base_published(), [
        { name: "caption", type: "string", default_value: "Button" },
        { name: "width",   type: "int",    default_value: 80 },
        { name: "height",  type: "int",    default_value: 28 },
        { name: "down",    type: "bool",   default_value: false },
    ]);

    static draw = function() {
        var _th = gmforms_theme();
        var _en = is_enabled();
        var _col = _th.button;
        if (!_en)                           _col = _th.button_disabled;
        else if (is_pressed() || _key_down || down) _col = _th.button_pressed;
        else if (is_hot())                  _col = _th.button_hover;
        gmforms_draw_rect(_sx, _sy, width, height, _col);
        gmforms_draw_text_in(_sx, _sy, width, height, caption, _en ? _th.text : _th.text_disabled, fa_center, fa_middle, _th.text_padding);
    };

    static draw_overlay = function() {
        var _th = gmforms_theme();
        if (is_focused()) {
            gmforms_draw_frame(_sx, _sy, width, height, _th.focus, 2);
        } else {
            gmforms_draw_frame(_sx, _sy, width, height, _th.button_border);
        }
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (_key == vk_space || _key == vk_enter) {
            _key_down = true;
            return true;
        }
        return false;
    };

    static key_up = function(_key) {
        if (is_callable(on_key_up)) on_key_up(self, _key);
        if ((_key == vk_space || _key == vk_enter) && _key_down) {
            _key_down = false;
            if (is_enabled()) click();
        }
    };

    static focus_lost = function() {
        _key_down = false;
        if (is_callable(on_blur)) on_blur(self);
    };
}

/// @func GMF_Label()
/// @desc Static text. text_align: "left" | "center" | "right"; text_valign: "top" | "middle" | "bottom".
function GMF_Label() : GMF_Control() constructor {
    class_name = "Label";
    caption = "Label";
    width = 120;
    height = 22;
    text_align = "left";
    text_valign = "middle";
    color = undefined;          // text colour; undefined = theme.text

    static published = array_concat(gmforms_base_published(), [
        { name: "caption",     type: "string", default_value: "Label" },
        { name: "width",       type: "int",    default_value: 120 },
        { name: "height",      type: "int",    default_value: 22 },
        { name: "text_align",  type: "enum",   values: ["left", "center", "right"], default_value: "left" },
        { name: "text_valign", type: "enum",   values: ["top", "middle", "bottom"], default_value: "middle" },
        { name: "color",       type: "color",  default_value: undefined },
    ]);

    static draw = function() {
        var _th = gmforms_theme();
        var _col = is_enabled() ? (color ?? _th.text) : _th.text_disabled;
        gmforms_draw_text_in(_sx, _sy, width, height, caption, _col,
            gmforms_halign_from_string(text_align), gmforms_valign_from_string(text_valign), _th.text_padding);
    };
}

/// @func GMF_CheckBox()
/// @desc Toggle control. Fires on_change(sender, checked) then on_click(sender) on click or Space/Enter.
function GMF_CheckBox() : GMF_Control() constructor {
    class_name = "CheckBox";
    caption = "CheckBox";
    checked = false;
    width = 140;
    height = 22;
    tab_stop = true;
    _key_down = false;   // Space/Enter held while focused — same pattern as GMF_Button

    static published = array_concat(gmforms_base_published(), [
        { name: "caption", type: "string", default_value: "CheckBox" },
        { name: "checked",  type: "bool",   default_value: false },
        { name: "width",    type: "int",    default_value: 140 },
        { name: "height",   type: "int",    default_value: 22 },
    ]);

    static draw = function() {
        var _th = gmforms_theme();
        var _en = is_enabled();
        var _box = 16;
        var _by = _sy + round((height - _box) * 0.5);
        var _col = _th.button;
        if (!_en)                           _col = _th.button_disabled;
        else if (is_pressed() || _key_down) _col = _th.button_pressed;
        else if (is_hot())                  _col = _th.button_hover;
        gmforms_draw_rect(_sx, _by, _box, _box, _col);
        gmforms_draw_frame(_sx, _by, _box, _box, _th.button_border);
        if (checked) {
            draw_set_colour(_th.checkbox_mark);
            draw_line_width(_sx + 3, _by + 8, _sx + 6, _by + 12, 2);
            draw_line_width(_sx + 6, _by + 12, _sx + 13, _by + 4, 2);
        }
        gmforms_draw_text_in(_sx + _box + 6, _sy, width - _box - 6, height,
            caption, _en ? _th.text : _th.text_disabled, fa_left, fa_middle, _th.text_padding);
    };

    static draw_overlay = function() {
        if (is_focused()) gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().focus, 2);
    };

    /// @func click()
    /// @desc Toggles checked, fires on_change(self, checked), then on_click(self).
    static click = function() {
        checked = !checked;
        if (is_callable(on_change)) on_change(self, checked);
        if (is_callable(on_click)) on_click(self);
    };

    // Reimplemented from GMF_Button (GML has no super) — Space/Enter click while focused.
    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (_key == vk_space || _key == vk_enter) { _key_down = true; return true; }
        return false;
    };
    static key_up = function(_key) {
        if (is_callable(on_key_up)) on_key_up(self, _key);
        if ((_key == vk_space || _key == vk_enter) && _key_down) {
            _key_down = false;
            if (is_enabled()) click();
        }
    };
    static focus_lost = function() {
        _key_down = false;
        if (is_callable(on_blur)) on_blur(self);
    };
}

/// @func GMF_Splitter()
/// @desc Delphi-style splitter: drag resizes the nearest earlier visible sibling with the same align.
///       align must be "left", "right", "top" or "bottom" to do anything; other aligns no-op the drag.
///       Sign convention (resolves plan Q6, implicit previous-aligned-sibling): a left/top splitter
///       grows its target when dragged away from center; a right/bottom splitter shrinks its target
///       when dragged toward it — see CLAUDE.md M3 notes for the worked example.
function GMF_Splitter() : GMF_Control() constructor {
    class_name = "Splitter";
    align = "left";
    width = 4;
    height = 4;
    min_size = 40;
    tab_stop = false;
    _target = undefined;
    _horizontal = true;
    _drag_start_mouse = 0;
    _drag_start_size = 0;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",    type: "int", default_value: 4 },
        { name: "height",   type: "int", default_value: 4 },
        { name: "min_size", type: "int", default_value: 40 },
    ]);

    /// Nearest earlier visible sibling in parent.children with the same align.
    static _find_target = function() {
        if (parent == undefined) return undefined;
        if (align != "left" && align != "right" && align != "top" && align != "bottom") return undefined;
        var _idx = array_get_index(parent.children, self);
        for (var _i = _idx - 1; _i >= 0; _i--) {
            var _s = parent.children[_i];
            if (_s.visible && _s.align == align) return _s;
        }
        return undefined;
    };

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        if (_btn != mb_left) return;
        _target = _find_target();
        if (_target == undefined) return;
        _horizontal = (align == "left" || align == "right");
        // Reconstructed from the hook's own local coords + current _sx/_sy (not a fresh device poll):
        // the splitter's _sx/_sy shift as the parent re-lays-out mid-drag, so this keeps the delta correct.
        _drag_start_mouse = _horizontal ? (_sx + _x) : (_sy + _y);
        _drag_start_size  = _horizontal ? _target.width : _target.height;
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        // Gate on capture alone, not is_pressed() (which also requires hover) — a thin bar is trivially
        // left behind by fast mouse movement mid-drag, which would silently kill the drag.
        var _f = get_form();
        if (_f == undefined || _f.capture != self || _target == undefined) return;
        var _cur = _horizontal ? (_sx + _x) : (_sy + _y);
        var _sign = (align == "left" || align == "top") ? 1 : -1;
        var _new_size = max(min_size, _drag_start_size + _sign * (_cur - _drag_start_mouse));
        if (_horizontal) _target.width = _new_size; else _target.height = _new_size;
        parent.invalidate_layout();
    };

    static mouse_up = function(_x, _y, _btn) {
        if (is_callable(on_mouse_up)) on_mouse_up(self, _x, _y, _btn);
        _target = undefined;
    };

    static draw = function() {
        var _th = gmforms_theme();
        var _f = get_form();
        var _col = _th.splitter;
        if (_f != undefined && _f.capture == self) _col = _th.splitter_pressed;
        else if (is_hot()) _col = _th.splitter_hover;
        gmforms_draw_rect(_sx, _sy, width, height, _col);
        var _cx = _sx + width * 0.5, _cy = _sy + height * 0.5;
        draw_set_colour(_th.splitter_grip);
        if (align == "left" || align == "right") {
            for (var _i = -1; _i <= 1; _i++) draw_line(_cx - 1, _cy + _i * 5, _cx + 1, _cy + _i * 5);
        } else {
            for (var _i = -1; _i <= 1; _i++) draw_line(_cx + _i * 5, _cy - 1, _cx + _i * 5, _cy + 1);
        }
    };
}
