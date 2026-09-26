/// GMForms designer — scripted sessions.
///
/// designer_script_tile_editor() rebuilds the tile editor sample's form using only the designer's
/// own operations (the ones its palette, canvas and inspector call). Its output is the Included
/// File datafiles/tile_editor.gmform.json that the sample loads — the M6 acceptance check
/// ("the M4 tile editor's form can be recreated entirely in the designer and loads in the sample").
/// The test suite rebuilds it and compares the JSON with that file byte for byte.
///
/// To regenerate the file: set DESIGNER_EXPORT_TILES to true, run, copy
/// %LOCALAPPDATA%/GMForms/tile_editor.gmform.json into datafiles/, set it back to false.

#macro DESIGNER_CAPTURE false   // true: the first room jumps to the designer, saves designer_*.png, then quits

/// @func designer_tile_editor_menus()
/// @desc The tile editor's menus as the designer's menu editor would hold them (handler names, no functions).
function designer_tile_editor_menus() {
    var _m = function(_caption, _handler, _props = undefined) {
        var _it = gmforms_menu_item(_caption, undefined, _props);
        _it.on_click_name = _handler;
        return _it;
    };
    return [
        gmforms_submenu("File", [
            _m("New",  "mnuNew_Click",  { shortcut: "Ctrl+N" }),
            _m("Open", "mnuOpen_Click", { shortcut: "Ctrl+O" }),
            _m("Save", "mnuSave_Click", { shortcut: "Ctrl+S" }),
            gmforms_menu_separator(),
            gmforms_submenu("Other demos", [
                _m("Form designer",       "mnuDesigner_Click"),
                _m("M5 controls gallery", "mnuGallery_Click"),
                _m("M1 layout demo",      "mnuM1Demo_Click"),
            ]),
            gmforms_menu_separator(),
            _m("Exit", "mnuExit_Click"),
        ]),
        gmforms_submenu("Edit", [
            _m("Undo", "mnuUndo_Click", { shortcut: "Ctrl+Z" }),
            _m("Redo", "mnuRedo_Click", { shortcut: "Ctrl+Y", alt_shortcut: "Ctrl+Shift+Z" }),
            gmforms_menu_separator(),
            _m("Clear map", "mnuClear_Click", { shortcut: "Ctrl+Delete" }),
        ]),
        gmforms_submenu("Tools", [
            _m("Paint",  "mnuPaint_Click",  { shortcut: "Ctrl+1", checked: true }),
            _m("Select", "mnuSelect_Click", { shortcut: "Ctrl+2" }),
        ]),
        gmforms_submenu("View", [
            _m("Zoom in",    "mnuZoomIn_Click",    { shortcut: "Ctrl+Up" }),
            _m("Zoom out",   "mnuZoomOut_Click",   { shortcut: "Ctrl+Down" }),
            _m("Reset view", "mnuResetView_Click", { shortcut: "Ctrl+0" }),
            gmforms_menu_separator(),
            _m("Show grid",      "mnuShowGrid_Click", { checked: true }),
            _m("Map properties", "mnuMapProps_Click", { shortcut: "F4" }),
        ]),
    ];
}

/// @func designer_script_tile_editor(app)
/// @desc Rebuilds the tile editor's form in a DesignerApp through its public operations. Returns the form.
function designer_script_tile_editor(_app) {
    var _cv = _app.canvas;
    var _f = _app.new_form({ name: "frmTiles", caption: "GMForms - tile editor sample", width: 1024, height: 700 });

    var _mb = _cv.create_control("MenuBar", _f, 0, 0);
    _app.set_props(_mb, { name: "mbMain", menus: designer_tile_editor_menus() });

    var _tb = _cv.create_control("Toolbar", _f, 0, 0);
    _app.set_prop(_tb, "name", "tbMain");
    var _buttons = [
        ["btnNew", "New", 50], ["btnOpen", "Open", 56], ["btnSave", "Save", 56], "-",
        ["btnUndo", "Undo", 56], ["btnRedo", "Redo", 56], "-",
        ["btnPaint", "Paint", 62], ["btnSelect", "Select", 72], "-",
        ["btnClear", "Clear", 62], ["btnMapProps", "Map props", 100],
    ];
    for (var _i = 0; _i < array_length(_buttons); _i++) {
        var _b = _buttons[_i];
        if (is_string(_b)) { _cv.create_control("ToolSeparator", _tb, 0, 0); continue; }
        var _btn = _cv.create_control("Button", _tb, 0, 0, _b[2], 26);
        _app.set_props(_btn, { name: _b[0], caption: _b[1] });
        _app.set_event(_btn, "onClick", _b[0] + "_Click");
    }

    var _status = _cv.create_control("Panel", _f, 0, 0);
    _app.set_props(_status, { name: "pnlStatus", align: "bottom", height: 26 });
    var _lbl = _cv.create_control("Label", _status, 4, 2, 1016, 22);
    _app.set_props(_lbl, { name: "lblStatus", caption: "", anchors: ["left", "top", "right"] });

    var _pal = _cv.create_control("Panel", _f, 0, 0);
    _app.set_props(_pal, { name: "pnlPalette", align: "left", width: 150, caption: "Tiles" });
    var _spl = _cv.create_control("Splitter", _f, 0, 0);
    _app.set_props(_spl, { name: "splPalette", min_size: 90 });

    var _insp = _cv.create_control("Panel", _f, 0, 0);
    _app.set_props(_insp, { name: "pnlInspector", align: "right", width: 300 });
    var _cap = _cv.create_control("Label", _insp, 0, 0);
    _app.set_props(_cap, { name: "lblInspector", caption: "", align: "top", height: 24 });
    var _grid = _cv.create_control("PropertyGrid", _insp, 0, 0);
    _app.set_props(_grid, { name: "gridProps", align: "client", name_width: 120, margin: { l: 4, t: 0, r: 4, b: 4 } });
    _app.set_event(_grid, "onChange", "gridProps_Change");
    var _spr = _cv.create_control("Splitter", _f, 0, 0);
    _app.set_props(_spr, { name: "splInspector", align: "right", min_size: 160 });

    var _vp = _cv.create_control("Viewport", _f, 0, 0);
    _app.set_props(_vp, { name: "vpMap", align: "client" });
    _app.set_event(_vp, "onDraw", "vpMap_Draw");
    _app.set_event(_vp, "onMouseDown", "vpMap_MouseDown");
    _app.set_event(_vp, "onMouseMove", "vpMap_MouseMove");
    _app.set_event(_vp, "onMouseUp", "vpMap_MouseUp");
    _app.set_event(_vp, "onWheel", "vpMap_Wheel");

    _cv.select(_f);
    return _f;
}

/// @func designer_capture_step(app, frame)
/// @desc Scripted visual check used when DESIGNER_CAPTURE is true.
function designer_capture_step(_app, _t) {
    var _f = _app.form;
    switch (_t) {
        case 5:
            _app.open_file("tile_editor.gmform.json");
            _app.canvas.offset_x = 12;
            _app.canvas.offset_y = 32;
            break;
        case 20:
            _app.canvas.select(_app.target.find("btnSave"));
            break;
        case 35: screen_save("designer_a_select.png"); break;
        case 36:
            _app.canvas.select(_app.target.find("vpMap"));
            _app.inspector_tabs.set_tab_index(1);
            break;
        case 50: screen_save("designer_b_events.png"); break;
        case 51:
            _app.inspector_tabs.set_tab_index(0);
            _app.canvas.select(_app.target.find("mbMain"));
            _app.props_grid.set_expanded("#Properties", true);
            _app.props_grid.set_expanded("menus", true);
            _app.props_grid.set_expanded("menus.0", true);
            _app.props_grid.select(_app.props_grid.find_row("menus.0"));
            break;
        case 65: screen_save("designer_c_menus.png"); break;
        case 66:
            _app.new_form({ name: "frmDemo", caption: "Designed form", width: 480, height: 320 });
            var _cv = _app.canvas;
            var _p = _cv.create_control("Panel", _app.target, 16, 16, 200, 120);
            _cv.create_control("Button", _p, 16, 40);
            _cv.create_control("CheckBox", _app.target, 240, 24);
            var _tc = _cv.create_control("TabControl", _app.target, 240, 64, 220, 160);
            _cv.create_control("Edit", _tc.get_page(), 12, 12);
            _cv.create_control("ListBox", _app.target, 16, 152, 200, 150);
            _cv.select(_p.children[0]);
            break;
        case 80: screen_save("designer_d_new_form.png"); break;
        case 81:
            show_debug_message("[GMForms] capture dir: " + game_save_id);
            game_end();
            break;
    }
}
