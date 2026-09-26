/// GMForms — basic controls: Panel, Button, Label.
/// M1 draws them with flat theme colours (no sprites yet).

/// @func GMF_Panel()
/// @desc Container with an optional background, border and small caption in the top-left corner.
function GMF_Panel() : GMF_Control() constructor {
    class_name = "Panel";
    caption = "";
    color = undefined;          // background colour; undefined = theme.panel
    transparent = false;        // true = no background fill
    border = true;

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
    _key_down = false;          // Space/Enter held while focused (pressed look)

    static draw = function() {
        var _th = gmforms_theme();
        var _en = is_enabled();
        var _col = _th.button;
        if (!_en)                           _col = _th.button_disabled;
        else if (is_pressed() || _key_down) _col = _th.button_pressed;
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

    static draw = function() {
        var _th = gmforms_theme();
        var _col = is_enabled() ? (color ?? _th.text) : _th.text_disabled;
        gmforms_draw_text_in(_sx, _sy, width, height, caption, _col,
            gmforms_halign_from_string(text_align), gmforms_valign_from_string(text_valign), _th.text_padding);
    };
}
