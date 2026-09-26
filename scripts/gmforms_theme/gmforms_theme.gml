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
        checkbox_mark:    make_colour_rgb(222, 222, 228),
        splitter:         make_colour_rgb(46, 46, 52),
        splitter_hover:   make_colour_rgb(70, 70, 80),
        splitter_pressed: make_colour_rgb(0, 122, 204),
        splitter_grip:    make_colour_rgb(110, 110, 120),
        viewport_bg:      make_colour_rgb(18, 18, 20),
        viewport_border:  make_colour_rgb(62, 62, 70),
        viewport_grid:    make_colour_rgb(50, 50, 56),
        edit_bg:          make_colour_rgb(24, 24, 28),
        edit_bg_disabled: make_colour_rgb(38, 38, 42),
        edit_border:      make_colour_rgb(84, 84, 96),
        edit_selection:   make_colour_rgb(0, 96, 170),
        edit_caret:       make_colour_rgb(222, 222, 228),
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
        checkbox_mark:    make_colour_rgb(24, 24, 28),
        splitter:         make_colour_rgb(214, 214, 220),
        splitter_hover:   make_colour_rgb(200, 200, 210),
        splitter_pressed: make_colour_rgb(0, 110, 200),
        splitter_grip:    make_colour_rgb(140, 140, 150),
        viewport_bg:      make_colour_rgb(255, 255, 255),
        viewport_border:  make_colour_rgb(190, 190, 198),
        viewport_grid:    make_colour_rgb(225, 225, 230),
        edit_bg:          make_colour_rgb(255, 255, 255),
        edit_bg_disabled: make_colour_rgb(238, 238, 240),
        edit_border:      make_colour_rgb(170, 170, 180),
        edit_selection:   make_colour_rgb(0, 110, 200),
        edit_caret:       make_colour_rgb(24, 24, 28),
        text_padding: 6,
    };
}
