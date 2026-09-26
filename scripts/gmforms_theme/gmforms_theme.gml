/// GMForms — themes. M1 draws with flat colours; nine-slice sprites and DPI scale come in a later milestone.

/// @func gmforms_theme_dark()
/// @desc The default dark theme (decision D12).
/// @returns {Struct}
function gmforms_theme_dark() {
    return {
        name: "dark",
        font: -1,                                   // -1 = GameMaker's built-in font
        form_bg:         make_colour_rgb(30, 30, 34),
        panel:           make_colour_rgb(42, 42, 47),
        panel_border:    make_colour_rgb(62, 62, 70),
        panel_caption:   make_colour_rgb(130, 130, 140),
        text:            make_colour_rgb(222, 222, 228),
        text_disabled:   make_colour_rgb(115, 115, 124),
        button:          make_colour_rgb(58, 58, 66),
        button_hover:    make_colour_rgb(72, 72, 82),
        button_pressed:  make_colour_rgb(0, 96, 170),
        button_disabled: make_colour_rgb(46, 46, 52),
        button_border:   make_colour_rgb(84, 84, 96),
        accent:          make_colour_rgb(0, 122, 204),
        focus:           make_colour_rgb(0, 160, 255),
        text_padding: 6,
    };
}

/// @func gmforms_theme_light()
/// @desc A light theme with the same keys as the dark one.
/// @returns {Struct}
function gmforms_theme_light() {
    return {
        name: "light",
        font: -1,
        form_bg:         make_colour_rgb(236, 236, 240),
        panel:           make_colour_rgb(246, 246, 248),
        panel_border:    make_colour_rgb(190, 190, 198),
        panel_caption:   make_colour_rgb(120, 120, 130),
        text:            make_colour_rgb(24, 24, 28),
        text_disabled:   make_colour_rgb(150, 150, 158),
        button:          make_colour_rgb(225, 225, 230),
        button_hover:    make_colour_rgb(210, 222, 238),
        button_pressed:  make_colour_rgb(0, 110, 200),
        button_disabled: make_colour_rgb(232, 232, 236),
        button_border:   make_colour_rgb(170, 170, 180),
        accent:          make_colour_rgb(0, 110, 200),
        focus:           make_colour_rgb(0, 120, 215),
        text_padding: 6,
    };
}
