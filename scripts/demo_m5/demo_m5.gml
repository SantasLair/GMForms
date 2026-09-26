/// M5 sample: a gallery of the Tier 2 controls — MenuBar (submenus, checks, shortcuts), context menus,
/// Toolbar, TabControl, ListBox, TreeView, ComboBox, SpinEdit, Slider, ColorPicker, SpritePicker, and
/// the PropertyGrid's popup editors (enum / colour / sprite) plus bind_control (the future inspector).
/// Open it from the tile editor's File > Other demos menu.

#macro DEMO_M5_CAPTURE false   // true: the first room jumps here, saves m5_*.png screenshots, then quits

/// @func DemoSpritePreview()
/// @desc Tiny custom control: draws one sprite scaled to fit.
function DemoSpritePreview() : GMF_Control() constructor {
    class_name = "DemoSpritePreview";
    sprite = -1;
    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, _th.viewport_bg);
        gmforms_draw_sprite_fit(sprite, _sx + 8, _sy + 8, width - 16, height - 16);
        gmforms_draw_frame(_sx, _sy, width, height, _th.panel_border);
    };
}

/// @func demo_m5_make_sprite(shape, colour)
/// @desc Draws a 32x32 sprite at runtime (the project has no sprite assets): "circle", "square", "triangle", "diamond".
function demo_m5_make_sprite(_shape, _col) {
    var _s = surface_create(32, 32);
    surface_set_target(_s);
    draw_clear_alpha(c_black, 0);
    draw_set_colour(_col);
    switch (_shape) {
        case "circle":   draw_circle(15.5, 15.5, 13, false); break;
        case "square":   draw_rectangle(4, 4, 28, 28, false); break;
        case "triangle": draw_triangle(16, 3, 29, 28, 3, 28, false); break;
        case "diamond":
            draw_triangle(16, 2, 30, 16, 2, 16, false);
            draw_triangle(2, 16, 30, 16, 16, 30, false);
            break;
    }
    surface_reset_target();
    var _spr = sprite_create_from_surface(_s, 0, 0, 32, 32, false, false, 16, 16);
    surface_free(_s);
    return _spr;
}

/// @func DemoM5App()
function DemoM5App() constructor {
    // runtime sprites are made once and reused if the room is visited again
    static shared = { sprites: undefined, labels: ["Circle", "Square", "Triangle", "Diamond"] };
    if (shared.sprites == undefined) {
        shared.sprites = [
            demo_m5_make_sprite("circle", c_orange),
            demo_m5_make_sprite("square", c_aqua),
            demo_m5_make_sprite("triangle", c_lime),
            demo_m5_make_sprite("diamond", c_fuchsia),
        ];
    }
    sprites = shared.sprites;
    sprite_labels = shared.labels;

    form = gmforms_create(GMF_Form, { name: "frmGallery", caption: "GMForms - M5 controls gallery", width: 1024, height: 700 });

    // ---- menu bar ---------------------------------------------------------------
    menu = form.add(gmforms_create(GMF_MenuBar, { name: "mbMain" }));

    // ---- toolbar ------------------------------------------------------------------
    var _tb = form.add(gmforms_create(GMF_Toolbar, { name: "tbMain" }));
    _tb.add_button("New", undefined, { name: "tbNew" });
    _tb.add_button("Open", undefined, { name: "tbOpen" });
    _tb.add_button("Save", undefined, { name: "tbSave" });
    _tb.add_separator();
    _tb.add_button("Bold", undefined, { name: "tbBold" });
    _tb.add_button("Italic", undefined, { name: "tbItalic" });
    _tb.add_separator();
    zoom_combo = _tb.add(gmforms_create(GMF_ComboBox, { name: "cbZoom", width: 100, items: ["50%", "100%", "150%", "200%"], item_index: 1 }));

    // ---- status bar -----------------------------------------------------------------
    var _sb = form.add(gmforms_create(GMF_Panel, { name: "pnlStatus", align: "bottom", height: 26 }));
    status = _sb.add(gmforms_create(GMF_Label, { name: "lblStatus", caption: "Ready",
        left: 4, top: 2, width: 1016, height: 22, anchors: ["left", "top", "right"] }));

    // ---- tabs ---------------------------------------------------------------------------
    tabs = form.add(gmforms_create(GMF_TabControl, { name: "tabMain", align: "client", margin: { l: 4, t: 4, r: 4, b: 4 } }));
    var _p_lists = tabs.add_page("Lists");
    var _p_values = tabs.add_page("Values");
    var _p_grid = tabs.add_page("Property grid");

    // Lists page
    _p_lists.add(gmforms_create(GMF_Label, { caption: "ListBox", left: 12, top: 8, width: 200 }));
    list = _p_lists.add(gmforms_create(GMF_ListBox, { name: "lbFruit", left: 12, top: 32, width: 200, height: 300,
        anchors: ["left", "top", "bottom"] }));
    var _fruit = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape", "Honeydew", "Kiwi", "Lemon",
        "Mango", "Nectarine", "Orange", "Papaya", "Quince", "Raspberry", "Strawberry", "Tangerine"];
    for (var _i = 0; _i < array_length(_fruit); _i++) list.add_item(_fruit[_i]);

    _p_lists.add(gmforms_create(GMF_Label, { caption: "TreeView (right-click it)", left: 228, top: 8, width: 300 }));
    tree = _p_lists.add(gmforms_create(GMF_TreeView, { name: "tvScene", left: 228, top: 32, width: 260, height: 300,
        anchors: ["left", "top", "bottom"] }));
    var _lvl = tree.add_node(undefined, "Level 1");
    var _layer = tree.add_node(_lvl, "Background");
    tree.add_node(_layer, "sky");
    tree.add_node(_layer, "mountains");
    var _ents = tree.add_node(_lvl, "Entities");
    tree.add_node(_ents, "player");
    for (var _i = 1; _i <= 12; _i++) tree.add_node(_ents, "enemy_" + string(_i));
    tree.add_node(undefined, "Level 2");
    tree.set_expanded(_lvl, true);
    tree.set_expanded(_ents, true);

    _p_lists.add(gmforms_create(GMF_Label, { caption: "ComboBox", left: 504, top: 8, width: 200 }));
    combo = _p_lists.add(gmforms_create(GMF_ComboBox, { name: "cbWeather", left: 504, top: 32, width: 200,
        items: ["Sunny", "Cloudy", "Rain", "Snow", "Fog"], item_index: 0 }));
    var _many = [];
    for (var _i = 1; _i <= 40; _i++) array_push(_many, "Stage " + string(_i));
    _p_lists.add(gmforms_create(GMF_ComboBox, { name: "cbStage", left: 504, top: 66, width: 200, items: _many, dropdown_rows: 10 }));
    _p_lists.add(gmforms_create(GMF_Label, { left: 504, top: 110, width: 480, height: 66, text_valign: "top",
        caption: "The dropdowns open over the list and tree\n(popups draw above everything). Escape or a\nclick outside closes them." }));

    // Values page
    _p_values.add(gmforms_create(GMF_Label, { caption: "SpinEdit", left: 12, top: 12, width: 120 }));
    spin = _p_values.add(gmforms_create(GMF_SpinEdit, { name: "seVolume", left: 140, top: 12, width: 90, value: 50 }));
    _p_values.add(gmforms_create(GMF_Label, { caption: "Slider", left: 12, top: 48, width: 120 }));
    slider = _p_values.add(gmforms_create(GMF_Slider, { name: "slVolume", left: 140, top: 48, width: 240, value: 50 }));
    _p_values.add(gmforms_create(GMF_Label, { caption: "(linked)", left: 390, top: 48, width: 120 }));
    _p_values.add(gmforms_create(GMF_Label, { caption: "Decimals", left: 12, top: 84, width: 120 }));
    _p_values.add(gmforms_create(GMF_SpinEdit, { name: "seGravity", left: 140, top: 84, width: 90,
        value: 9.81, decimals: 2, step: 0.1, min_value: -20, max_value: 20 }));

    _p_values.add(gmforms_create(GMF_Label, { caption: "ColorPicker", left: 12, top: 132, width: 120 }));
    color_pick = _p_values.add(gmforms_create(GMF_ColorPicker, { name: "cpTint", left: 140, top: 132, color: make_colour_rgb(0, 122, 204) }));
    swatch = _p_values.add(gmforms_create(GMF_Panel, { name: "pnlSwatch", left: 280, top: 124, width: 120, height: 40, color: color_pick.color }));

    _p_values.add(gmforms_create(GMF_Label, { caption: "SpritePicker", left: 12, top: 188, width: 120 }));
    sprite_pick = _p_values.add(gmforms_create(GMF_SpritePicker, { name: "spIcon", left: 140, top: 186, width: 170 }));
    sprite_pick.sprites = sprites;
    sprite_pick.labels = sprite_labels;
    preview = _p_values.add(gmforms_create(DemoSpritePreview, { name: "sprPreview", left: 330, top: 186, width: 96, height: 96 }));

    // Property grid page: a struct with popup editors, and an inspector for real controls
    unit = {
        name: "Goblin",
        kind: 1,
        tint: make_colour_rgb(86, 160, 72),
        icon: sprites[0],
        hp: 30,
        speed: 1.5,
        hostile: true,
        loot: { gold: 12, gems: 0 },
    };
    _p_grid.add(gmforms_create(GMF_Label, { caption: "A struct (popup editors)", left: 12, top: 8, width: 340 }));
    unit_grid = _p_grid.add(gmforms_create(GMF_PropertyGrid, { name: "gridUnit", left: 12, top: 32, width: 340, height: 280,
        name_width: 110 }));
    unit_grid.bind(unit, [
        { name: "name",    type: "string", category: "General" },
        { name: "kind",    type: "enum", values: [0, 1, 2, 3], labels: ["Orc", "Goblin", "Troll", "Dragon"], category: "General" },
        { name: "hostile", type: "bool", category: "General" },
        { name: "tint",    type: "color", category: "Look" },
        { name: "icon",    type: "sprite", values: sprites, labels: sprite_labels, category: "Look" },
        { name: "hp",      type: "int", min: 1, max: 999, step: 5, category: "Stats" },
        { name: "speed",   type: "real", range: { min: 0, max: 5, step: 0.25 }, category: "Stats" },
        { name: "loot",    type: "struct", category: "Stats" },
    ]);
    unit_grid.undo = new GMF_UndoStack();

    _p_grid.add(gmforms_create(GMF_Label, { caption: "bind_control(): edit these controls live", left: 380, top: 8, width: 400 }));
    inspect_target = _p_grid.add(gmforms_create(GMF_ComboBox, { name: "cbInspect", left: 380, top: 32, width: 200,
        items: ["Sample button", "Sample check box", "Sample slider"], item_index: 0 }));
    sample_button = _p_grid.add(gmforms_create(GMF_Button, { name: "btnSample", caption: "Sample", left: 600, top: 32, width: 100 }));
    sample_check = _p_grid.add(gmforms_create(GMF_CheckBox, { name: "cbxSample", caption: "Sample", left: 600, top: 70 }));
    sample_slider = _p_grid.add(gmforms_create(GMF_Slider, { name: "slSample", left: 600, top: 104, width: 150, value: 30 }));
    inspector = _p_grid.add(gmforms_create(GMF_PropertyGrid, { name: "gridInspector", left: 380, top: 140, width: 380, height: 300,
        name_width: 120, anchors: ["left", "top", "bottom"] }));

    // ---- behaviour ------------------------------------------------------------------------

    static set_status = function(_t) { status.caption = _t; };

    static inspect_sample = function() {
        var _targets = [sample_button, sample_check, sample_slider];
        inspector.bind_control(_targets[max(0, inspect_target.item_index)]);
    };

    static set_theme = function(_light) {
        gmforms_set_theme(_light ? gmforms_theme_light() : gmforms_theme_dark());
        menu.find_item("Dark").checked = !_light;
        menu.find_item("Light").checked = _light;
        set_status("Theme: " + (_light ? "light" : "dark"));
    };

    // ---- menus ------------------------------------------------------------------------------
    var _say = method(self, function(_s, _it) { set_status("Menu: " + _it.caption); });
    menu.add_menu("File", [
        gmforms_menu_item("New",  _say, { shortcut: "Ctrl+N" }),
        gmforms_menu_item("Open", _say, { shortcut: "Ctrl+O" }),
        gmforms_submenu("Open recent", [
            gmforms_menu_item("castle.map", _say),
            gmforms_menu_item("forest.map", _say),
            gmforms_submenu("More", [ gmforms_menu_item("old_01.map", _say), gmforms_menu_item("old_02.map", _say) ]),
        ]),
        gmforms_menu_item("Save", _say, { shortcut: "Ctrl+S" }),
        gmforms_menu_separator(),
        gmforms_menu_item("Back to the tile editor", function(_s, _it) { room_goto(rm_demo_tiles); }, { shortcut: "F2" }),
        gmforms_menu_item("M1 layout demo", function(_s, _it) { room_goto(rm_demo_m1); }),
        gmforms_menu_separator(),
        gmforms_menu_item("Exit", function(_s, _it) { game_end(); }, { shortcut: "Ctrl+Q" }),
    ]);
    menu.add_menu("Edit", [
        gmforms_menu_item("Undo grid edit", method(self, function(_s, _it) {
            set_status(unit_grid.undo.undo() ? "Undid a property grid edit" : "Nothing to undo");
        }), { shortcut: "Ctrl+Z" }),
        gmforms_menu_separator(),
        gmforms_menu_item("Cut",   _say, { enabled: false }),
        gmforms_menu_item("Copy",  _say),
        gmforms_menu_item("Paste", _say, { enabled: false }),
    ]);
    menu.add_menu("View", [
        gmforms_submenu("Theme", [
            gmforms_menu_item("Dark",  method(self, function(_s, _it) { set_theme(false); }), { checked: true }),
            gmforms_menu_item("Light", method(self, function(_s, _it) { set_theme(true); })),
        ]),
        gmforms_menu_separator(),
        gmforms_menu_item("Lists",         method(self, function(_s, _it) { tabs.set_tab_index(0); }), { shortcut: "Ctrl+1" }),
        gmforms_menu_item("Values",        method(self, function(_s, _it) { tabs.set_tab_index(1); }), { shortcut: "Ctrl+2" }),
        gmforms_menu_item("Property grid", method(self, function(_s, _it) { tabs.set_tab_index(2); }), { shortcut: "Ctrl+3" }),
    ]);
    menu.add_menu("Help", [
        gmforms_menu_item("About", method(self, function(_s, _it) { set_status("GMForms " + GMF_VERSION + " - M5 controls gallery"); }), { shortcut: "F1" }),
    ]);

    tree.popup_menu = gmforms_create(GMF_PopupMenu, { items: [
        gmforms_menu_item("Add child", method(self, function(_s, _it) {
            var _parent = tree.selected_node;
            var _node = tree.add_node(_parent, "new node");
            tree.select_node(_node);
            set_status("Added a node" + ((_parent != undefined) ? (" under " + _parent.text) : ""));
        })),
        gmforms_menu_item("Delete", method(self, function(_s, _it) {
            if (tree.selected_node == undefined) { set_status("Nothing selected"); return; }
            var _txt = tree.selected_node.text;
            tree.remove_node(tree.selected_node);
            set_status("Deleted " + _txt);
        })),
        gmforms_menu_separator(),
        gmforms_menu_item("Expand all",   method(self, function(_s, _it) { tree.expand_all(true); })),
        gmforms_menu_item("Collapse all", method(self, function(_s, _it) { tree.expand_all(false); })),
    ] });

    // ---- events ------------------------------------------------------------------------------
    form.find("tbNew").on_click  = method(self, function(_s) { set_status("Toolbar: New"); });
    form.find("tbOpen").on_click = method(self, function(_s) { set_status("Toolbar: Open"); });
    form.find("tbSave").on_click = method(self, function(_s) { set_status("Toolbar: Save"); });
    var _toggle = method(self, function(_s) { _s.down = !_s.down; set_status(_s.caption + (_s.down ? " on" : " off")); });
    form.find("tbBold").on_click = _toggle;
    form.find("tbItalic").on_click = _toggle;
    zoom_combo.on_change = method(self, function(_s, _i) { set_status("Zoom: " + _s.get_text()); });

    list.on_change   = method(self, function(_s, _i) { set_status("ListBox selected " + _s.get_text()); });
    list.on_activate = method(self, function(_s, _i) { set_status("ListBox activated (double-click/Enter) " + _s.get_text()); });
    tree.on_change   = method(self, function(_s, _n) { set_status("TreeView selected " + ((_n != undefined) ? _n.text : "nothing")); });
    tree.on_activate = method(self, function(_s, _n) { set_status("TreeView activated " + _n.text); });
    combo.on_change  = method(self, function(_s, _i) { set_status("Weather: " + _s.get_text()); });
    form.find("cbStage").on_change = method(self, function(_s, _i) { set_status("Stage: " + _s.get_text()); });

    spin.on_change   = method(self, function(_s, _v) { slider.set_value(_v, false); set_status("Volume " + string(_v)); });
    slider.on_change = method(self, function(_s, _v) { spin.set_value(_v, false); set_status("Volume " + string(_v)); });
    form.find("seGravity").on_change = method(self, function(_s, _v) { set_status("Gravity " + string(_v)); });
    color_pick.on_change  = method(self, function(_s, _c) { swatch.color = _c; set_status("Colour " + gmforms_color_to_hex(_c)); });
    sprite_pick.on_change = method(self, function(_s, _spr) { preview.sprite = _spr; set_status("Sprite: " + _s.get_text()); });
    tabs.on_change   = method(self, function(_s, _i) { set_status("Tab: " + _s.get_page().caption); });

    unit_grid.on_change = method(self, function(_s, _k, _o, _n, _owner) { set_status("unit." + string(_k) + " changed (Ctrl+Z undoes)"); });
    inspect_target.on_change = method(self, function(_s, _i) { inspect_sample(); });
    inspector.on_change = method(self, function(_s, _k, _o, _n, _owner) { set_status("Inspector: " + string(_k) + " = " + string(_n)); });

    sprite_pick.set_sprite(sprites[0], false);
    preview.sprite = sprites[0];
    inspect_sample();
    set_status("Try the menus (and their shortcuts), right-click the tree, and the dropdowns on every tab.");
}

/// @func demo_m5_capture_step(app, frame)
/// @desc Scripted visual check used when DEMO_M5_CAPTURE is true.
function demo_m5_capture_step(_app, _t) {
    var _f = _app.form;
    switch (_t) {
        case 20:
            _app.menu.open_menu(0, true);
            _f.top_popup()._hot = 2;
            _f.top_popup()._open_submenu(2);
            break;
        case 35: screen_save("m5_a_menu.png"); break;
        case 36:
            _f.close_popups();
            _app.list.set_item_index(3);
            _app.tree.select_node(_app.tree.nodes[0].nodes[1].nodes[0]);
            _app.combo.drop_down();
            break;
        case 50: screen_save("m5_b_lists_dropdown.png"); break;
        case 51:
            _f.close_popups();
            _app.tree.popup_menu.popup(_app.tree._sx - _f._sx + 60, _app.tree._sy - _f._sy + 90, _app.tree, _f);
            break;
        case 65: screen_save("m5_c_context_menu.png"); break;
        case 66:
            _f.close_popups();
            _app.tabs.set_tab_index(1);
            break;
        case 70:
            _app.color_pick.open();
            break;
        case 85: screen_save("m5_d_values_colour.png"); break;
        case 86:
            _f.close_popups();
            _app.sprite_pick.drop_down();
            break;
        case 100: screen_save("m5_e_sprite_dropdown.png"); break;
        case 101:
            _f.close_popups();
            _app.tabs.set_tab_index(2);
            break;
        case 105:
            _app.unit_grid._open_enum_dropdown(_app.unit_grid.find_row("kind"));
            break;
        case 120: screen_save("m5_f_grid_enum.png"); break;
        case 121:
            _f.close_popups();
            _app.unit_grid._open_sprite_dropdown(_app.unit_grid.find_row("icon"));
            break;
        case 135: screen_save("m5_g_grid_sprite.png"); break;
        case 136:
            _f.close_popups();
            _app.set_theme(true);
            _app.tabs.set_tab_index(0);
            break;
        case 150: screen_save("m5_h_light.png"); break;
        case 151:
            _app.set_theme(false);
            show_debug_message("[GMForms] capture dir: " + game_save_id);
            game_end();
            break;
    }
}
