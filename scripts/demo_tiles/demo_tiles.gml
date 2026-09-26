/// M4 sample: a tiny tile editor built by hand with GMForms (plan section 16, the key checkpoint).
/// Tile palette, pannable/zoomable map viewport, property grid, JSON save/load, undo/redo.
///
///   Paint tool:  left-drag paints the selected tile, right-drag erases (one undo step per stroke)
///   Select tool: left-click a cell to inspect it, right-click picks its tile
///   Pan:         middle-drag or Space+left-drag; wheel zooms toward the cursor
///   Keys:        menu shortcuts - Ctrl+N/O/S, Ctrl+Z, Ctrl+Y (or Ctrl+Shift+Z), Ctrl+1/2 tools,
///                Ctrl+Up/Down/0 zoom, F4 map properties. Right-click the inspector for a context menu.

#macro DEMO_TILES_FILE "tilemap.json"   // written to the save area (%LOCALAPPDATA%/GMForms on Windows; no backslash here, it continues a macro)
#macro DEMO_TILES_CAPTURE false          // true: saves m4_*.png screenshots of a scripted session, then quits

// ---------------------------------------------------------------------------
// Document model (plain structs, so it saves as JSON and the PropertyGrid can edit it directly)
// ---------------------------------------------------------------------------

/// @func demo_tiles_new_doc([cols], [rows])
/// @desc A new map: grass with a stone border and a small pond.
function demo_tiles_new_doc(_cols = 24, _rows = 16) {
    var _cells = array_create(_cols * _rows);
    for (var _y = 0; _y < _rows; _y++) {
        for (var _x = 0; _x < _cols; _x++) {
            var _t = 0;
            if (_x == 0 || _y == 0 || _x == _cols - 1 || _y == _rows - 1) _t = 2;
            else if (point_distance(_x, _y, _cols * 0.6, _rows * 0.45) < 3) _t = 1;
            _cells[_y * _cols + _x] = { t: _t, tag: "", spawn: false };
        }
    }
    return {
        format: "gmforms-tilemap",
        version: 1,
        cols: _cols,
        rows: _rows,
        tile_size: 32,
        info: {
            title: "Untitled map",
            author: "",
            wrap_edges: false,
            gravity: 9.8,
            camera: { start_x: 0, start_y: 0, zoom: 1 },
            tags: ["outdoor", "day"],
        },
        tiles: [
            { name: "Grass", color: make_colour_rgb(86, 160, 72),  solid: false, friction: 1,   damage: 0 },
            { name: "Water", color: make_colour_rgb(50, 110, 200), solid: false, friction: 0.4, damage: 0 },
            { name: "Stone", color: make_colour_rgb(120, 120, 128), solid: true, friction: 1,   damage: 0 },
            { name: "Sand",  color: make_colour_rgb(214, 190, 120), solid: false, friction: 0.7, damage: 0 },
            { name: "Lava",  color: make_colour_rgb(220, 80, 30),  solid: false, friction: 1,   damage: 25 },
            { name: "Wood",  color: make_colour_rgb(140, 96, 56),  solid: true,  friction: 1,   damage: 0 },
        ],
        cells: _cells,
    };
}

/// @func demo_tiles_to_json(doc)
function demo_tiles_to_json(_doc) {
    return json_stringify(_doc, true);
}

/// @func demo_tiles_from_json(text)
/// @desc Parses and validates a map. Returns the doc, or undefined (with a log line) if it's invalid.
function demo_tiles_from_json(_text) {
    var _doc;
    try {
        _doc = json_parse(_text);
    } catch (_e) {
        gmforms_log("tile map: invalid JSON");
        return undefined;
    }
    if (!is_struct(_doc) || _doc[$ "format"] != "gmforms-tilemap" || (_doc[$ "version"] ?? 0) != 1) {
        gmforms_log("tile map: not a gmforms-tilemap v1 document");
        return undefined;
    }
    if (!is_array(_doc[$ "cells"]) || !is_array(_doc[$ "tiles"])
        || array_length(_doc.cells) != (_doc[$ "cols"] ?? 0) * (_doc[$ "rows"] ?? 0)) {
        gmforms_log("tile map: cells don't match cols x rows");
        return undefined;
    }
    return _doc;
}

/// @func demo_tiles_save(doc, filename)
/// @returns {Bool}
function demo_tiles_save(_doc, _filename) {
    var _json = demo_tiles_to_json(_doc);
    var _buf = buffer_create(string_byte_length(_json) + 1, buffer_grow, 1);
    buffer_write(_buf, buffer_string, _json);
    buffer_save(_buf, _filename);
    buffer_delete(_buf);
    return file_exists(_filename);
}

/// @func demo_tiles_load(filename)
/// @returns {Struct|Undefined}
function demo_tiles_load(_filename) {
    if (!file_exists(_filename)) return undefined;
    var _buf = buffer_load(_filename);
    if (_buf < 0) return undefined;
    var _text = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    return demo_tiles_from_json(_text);
}

/// @func demo_tiles_paint(doc, undo, cx, cy, tile)
/// @desc Sets one cell's tile as an undoable step. Returns false if out of range or unchanged.
function demo_tiles_paint(_doc, _undo, _cx, _cy, _t) {
    if (_cx < 0 || _cy < 0 || _cx >= _doc.cols || _cy >= _doc.rows) return false;
    var _cell = _doc.cells[_cy * _doc.cols + _cx];
    if (_cell.t == _t) return false;
    _undo.set_value(_cell, "t", _t, (_t < 0) ? "Erase" : "Paint");
    return true;
}

/// @func demo_tiles_clear(doc, undo)
/// @desc Empties every cell, recorded as one JSON-snapshot undo step (the plan's fallback undo mode).
///       The restore writes into the existing cell structs, so other undo steps that reference them stay valid.
function demo_tiles_clear(_doc, _undo) {
    var _before = json_stringify(_doc.cells);
    var _n = array_length(_doc.cells);
    for (var _i = 0; _i < _n; _i++) {
        var _c = _doc.cells[_i];
        _c.t = -1;
        _c.tag = "";
        _c.spawn = false;
    }
    var _restore = method({ doc: _doc }, function(_json) {
        var _snap = json_parse(_json);
        var _n = array_length(_snap);
        for (var _i = 0; _i < _n; _i++) {
            var _c = doc.cells[_i];
            _c.t = _snap[_i].t;
            _c.tag = _snap[_i].tag;
            _c.spawn = _snap[_i].spawn;
        }
    });
    _undo.push_snapshot("Clear map", _before, json_stringify(_doc.cells), _restore);
}

// ---------------------------------------------------------------------------
// Palette entry: a tiny custom control (subclassing GMF_Control is all it takes)
// ---------------------------------------------------------------------------

/// @func DemoTileSwatch()
/// @desc Colour swatch + tile name. tile_index -1 is the eraser. Reads the tile live from app.doc.
function DemoTileSwatch() : GMF_Control() constructor {
    class_name = "DemoTileSwatch";
    app = undefined;
    tile_index = 0;
    height = 26;

    static draw = function() {
        var _th = gmforms_theme();
        var _selected = (app.cur_tile == tile_index);
        gmforms_draw_rect(_sx, _sy, width, height, _selected ? _th.grid_selection : (is_hot() ? _th.button_hover : _th.button));
        var _s = height - 8;
        var _name = "Eraser";
        if (tile_index >= 0) {
            var _tile = app.doc.tiles[tile_index];
            _name = _tile.name;
            gmforms_draw_rect(_sx + 4, _sy + 4, _s, _s, _tile.color);
        } else {
            draw_set_colour(_th.text_disabled);
            draw_line(_sx + 4, _sy + 4, _sx + 4 + _s, _sy + 4 + _s);
            draw_line(_sx + 4 + _s, _sy + 4, _sx + 4, _sy + 4 + _s);
        }
        gmforms_draw_frame(_sx + 4, _sy + 4, _s, _s, _th.button_border);
        gmforms_draw_text_in(_sx + height, _sy, width - height, height, _name, _th.text, fa_left, fa_middle, 4);
    };

    static draw_overlay = function() {
        gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().button_border);
    };
}

// ---------------------------------------------------------------------------
// The editor
// ---------------------------------------------------------------------------

/// @func DemoTilesApp()
/// @desc Builds the tile editor form and wires every event in code (event style B).
function DemoTilesApp() constructor {
    doc = demo_tiles_new_doc();
    undo = new GMF_UndoStack(500);
    tool = "paint";
    cur_tile = 0;           // palette selection (-1 = eraser)
    sel_cell = -1;          // cell index shown in the inspector, -1 = none
    hover_cell = -1;
    painting = false;
    paint_value = 0;
    _last_wx = 0;
    _last_wy = 0;

    static tile_meta = [
        { name: "name",     type: "string", category: "Appearance" },
        { name: "color",    type: "color",  category: "Appearance" },
        { name: "solid",    type: "bool",   category: "Physics" },
        { name: "friction", type: "real",   category: "Physics", range: { min: 0, max: 2, step: 0.1 } },
        { name: "damage",   type: "int",    category: "Physics", min: 0, max: 100, step: 5, label: "damage/sec" },
    ];

    // ---- form ----------------------------------------------------------------
    form = gmforms_create(GMF_Form, { name: "frmTiles", caption: "GMForms - tile editor sample", width: 1024, height: 700 });

    menu = form.add(gmforms_create(GMF_MenuBar, { name: "mbMain" }));
    var _bar = form.add(gmforms_create(GMF_Toolbar, { name: "tbMain" }));
    var _buttons = [
        ["btnNew", "New"], ["btnOpen", "Open"], ["btnSave", "Save"], "-",
        ["btnUndo", "Undo"], ["btnRedo", "Redo"], "-",
        ["btnPaint", "Paint"], ["btnSelect", "Select"], "-",
        ["btnClear", "Clear"], ["btnMapProps", "Map props"],
    ];
    for (var _i = 0; _i < array_length(_buttons); _i++) {
        var _b = _buttons[_i];
        if (is_string(_b)) _bar.add_separator();
        else _bar.add_button(_b[1], undefined, { name: _b[0] });
    }
    show_grid = true;

    var _status_bar = form.add(gmforms_create(GMF_Panel, { name: "pnlStatus", align: "bottom", height: 26 }));
    status = _status_bar.add(gmforms_create(GMF_Label, { name: "lblStatus", caption: "",
        left: 4, top: 2, width: 1024 - 8, height: 22, anchors: ["left", "top", "right"] }));

    palette = form.add(gmforms_create(GMF_Panel, { name: "pnlPalette", align: "left", width: 150, caption: "Tiles" }));
    form.add(gmforms_create(GMF_Splitter, { name: "splPalette", align: "left", width: 4, min_size: 90 }));

    var _insp = form.add(gmforms_create(GMF_Panel, { name: "pnlInspector", align: "right", width: 300 }));
    inspector_caption = _insp.add(gmforms_create(GMF_Label, { name: "lblInspector", align: "top", height: 24, caption: "" }));
    grid = _insp.add(gmforms_create(GMF_PropertyGrid, { name: "gridProps", align: "client", name_width: 120,
        margin: { l: 4, t: 0, r: 4, b: 4 } }));
    form.add(gmforms_create(GMF_Splitter, { name: "splInspector", align: "right", width: 4, min_size: 160 }));

    vp = form.add(gmforms_create(GMF_Viewport, { name: "vpMap", align: "client" }));
    vp.cam = { x: -16, y: -16, zoom: 0.7 };

    // ---- behaviour -------------------------------------------------------------

    static set_status = function(_text) { status.caption = _text; };

    static rebuild_palette = function() {
        while (array_length(palette.children) > 0) palette.remove(palette.children[0]);
        var _n = array_length(doc.tiles);
        for (var _i = -1; _i < _n; _i++) {
            var _sw = palette.add(gmforms_create(DemoTileSwatch, { name: "swatch" + string(_i + 1),
                left: 6, top: 26 + (_i + 1) * 30, width: 138, anchors: ["left", "top", "right"] }));
            _sw.app = self;
            _sw.tile_index = _i;
            _sw.on_click = method(self, function(_s) {
                cur_tile = _s.tile_index;
                set_tool("paint");
                if (cur_tile >= 0) inspect_tile(cur_tile);
            });
        }
    };

    static set_tool = function(_tool) {
        tool = _tool;
        form.find("btnPaint").down = (_tool == "paint");
        form.find("btnSelect").down = (_tool == "select");
        menu.find_item("Paint").checked = (_tool == "paint");
        menu.find_item("Select").checked = (_tool == "select");
    };

    /// Zooms around the centre of the viewport.
    static zoom_by = function(_factor) {
        vp.zoom_at(vp.width * 0.5, vp.height * 0.5, _factor);
        update_status();
    };

    static inspect_tile = function(_i) {
        sel_cell = -1;
        grid.bind(doc.tiles[_i], tile_meta);
        inspector_caption.caption = "Tile type " + string(_i) + " (metadata)";
    };

    static inspect_cell = function(_index) {
        sel_cell = _index;
        var _values = [-1];
        var _labels = ["(empty)"];
        for (var _i = 0; _i < array_length(doc.tiles); _i++) {
            array_push(_values, _i);
            array_push(_labels, doc.tiles[_i].name);
        }
        grid.bind(doc.cells[_index], [
            { name: "t",     label: "tile", type: "enum", values: _values, labels: _labels },
            { name: "tag",   type: "string" },
            { name: "spawn", type: "bool", label: "spawn point" },
        ]);
        inspector_caption.caption = "Cell " + string(_index mod doc.cols) + ", " + string(_index div doc.cols);
    };

    static inspect_map = function() {
        sel_cell = -1;
        grid.bind(doc.info);
        inspector_caption.caption = "Map properties (inferred)";
    };

    static load_doc = function(_doc, _message) {
        grid.cancel_edit();
        doc = _doc;
        undo.clear();      // history refers to the old document's structs
        cur_tile = min(cur_tile, array_length(doc.tiles) - 1);
        painting = false;
        hover_cell = -1;
        rebuild_palette();
        if (cur_tile >= 0) inspect_tile(cur_tile); else inspect_map();
        set_status(_message);
    };

    static do_undo = function() {
        grid.cancel_edit();
        var _label = undo.undo_label();
        set_status(undo.undo() ? ("Undid: " + _label) : "Nothing to undo");
    };

    static do_redo = function() {
        grid.cancel_edit();
        var _label = undo.redo_label();
        set_status(undo.redo() ? ("Redid: " + _label) : "Nothing to redo");
    };

    static save_doc = function() {
        grid.commit_edit();
        var _ok = demo_tiles_save(doc, DEMO_TILES_FILE);
        set_status(_ok ? ("Saved " + DEMO_TILES_FILE + " to the save area") : ("Could not save " + DEMO_TILES_FILE));
    };

    static open_doc = function() {
        var _d = demo_tiles_load(DEMO_TILES_FILE);
        if (_d == undefined) set_status("No valid " + DEMO_TILES_FILE + " in the save area yet - press Save first");
        else load_doc(_d, "Opened " + DEMO_TILES_FILE);
    };

    static cell_at = function(_wx, _wy) {
        var _cx = floor(_wx / doc.tile_size);
        var _cy = floor(_wy / doc.tile_size);
        if (_cx < 0 || _cy < 0 || _cx >= doc.cols || _cy >= doc.rows) return -1;
        return _cy * doc.cols + _cx;
    };

    /// Paints along the line from the last mouse position, so fast strokes don't skip cells.
    static paint_to = function(_wx, _wy) {
        var _ts = doc.tile_size;
        var _steps = max(1, ceil(point_distance(_last_wx, _last_wy, _wx, _wy) / (_ts * 0.5)));
        for (var _i = 1; _i <= _steps; _i++) {
            var _px = lerp(_last_wx, _wx, _i / _steps);
            var _py = lerp(_last_wy, _wy, _i / _steps);
            demo_tiles_paint(doc, undo, floor(_px / _ts), floor(_py / _ts), paint_value);
        }
        _last_wx = _wx;
        _last_wy = _wy;
    };

    static update_status = function() {
        var _s = (tool == "paint") ? "Paint" : "Select";
        _s += "  |  tile: " + ((cur_tile >= 0) ? doc.tiles[cur_tile].name : "Eraser");
        if (hover_cell >= 0) {
            var _c = doc.cells[hover_cell];
            _s += "  |  cell " + string(hover_cell mod doc.cols) + "," + string(hover_cell div doc.cols)
                + " = " + ((_c.t >= 0) ? doc.tiles[_c.t].name : "empty");
        }
        _s += "  |  zoom " + string(round(vp.cam.zoom * 100)) + "%";
        set_status(_s);
    };

    static draw_map = function() {
        var _ts = doc.tile_size;
        var _w = doc.cols * _ts;
        var _h = doc.rows * _ts;
        var _n = array_length(doc.cells);
        for (var _i = 0; _i < _n; _i++) {
            var _c = doc.cells[_i];
            if (_c.t < 0 || _c.t >= array_length(doc.tiles)) continue;
            var _x = (_i mod doc.cols) * _ts;
            var _y = (_i div doc.cols) * _ts;
            var _tile = doc.tiles[_c.t];
            gmforms_draw_rect(_x, _y, _ts, _ts, _tile.color);
            if (_tile.solid) gmforms_draw_frame(_x + 2, _y + 2, _ts - 4, _ts - 4, merge_colour(_tile.color, c_black, 0.35), 2);
            if (_c.tag != "") gmforms_draw_rect(_x + _ts - 8, _y + 3, 5, 5, c_white);
            if (_c.spawn) {
                draw_set_colour(c_yellow);
                draw_circle(_x + _ts * 0.5, _y + _ts * 0.5, _ts * 0.25, false);
            }
        }
        if (show_grid) {
            draw_set_alpha(0.25);
            draw_set_colour(c_black);
            for (var _gx = 0; _gx <= _w; _gx += _ts) draw_line(_gx, 0, _gx, _h);
            for (var _gy = 0; _gy <= _h; _gy += _ts) draw_line(0, _gy, _w, _gy);
            draw_set_alpha(1);
        }
        gmforms_draw_frame(-1, -1, _w + 2, _h + 2, c_gray);

        var _th = gmforms_theme();
        if (hover_cell >= 0) {
            gmforms_draw_frame((hover_cell mod doc.cols) * _ts, (hover_cell div doc.cols) * _ts, _ts, _ts, c_white);
        }
        if (sel_cell >= 0) {
            gmforms_draw_frame((sel_cell mod doc.cols) * _ts - 1, (sel_cell div doc.cols) * _ts - 1, _ts + 2, _ts + 2, _th.focus, 3);
        }
    };

    // ---- wiring ----------------------------------------------------------------

    // Menus: their shortcuts work from anywhere in the form (GMF_MenuBar.handle_shortcut).
    menu.add_menu("File", [
        gmforms_menu_item("New",  method(self, function(_s, _it) { load_doc(demo_tiles_new_doc(), "New map"); }), { shortcut: "Ctrl+N" }),
        gmforms_menu_item("Open", method(self, function(_s, _it) { open_doc(); }), { shortcut: "Ctrl+O" }),
        gmforms_menu_item("Save", method(self, function(_s, _it) { save_doc(); }), { shortcut: "Ctrl+S" }),
        gmforms_menu_separator(),
        gmforms_submenu("Other demos", [
            gmforms_menu_item("M1 layout demo",     function(_s, _it) { room_goto(rm_demo_m1); }),
            gmforms_menu_item("M5 controls gallery", function(_s, _it) { room_goto(rm_demo_m5); }),
        ]),
        gmforms_menu_separator(),
        gmforms_menu_item("Exit", function(_s, _it) { game_end(); }),
    ]);
    mi_undo = gmforms_menu_item("Undo", method(self, function(_s, _it) { do_undo(); }), { shortcut: "Ctrl+Z" });
    mi_redo = gmforms_menu_item("Redo", method(self, function(_s, _it) { do_redo(); }), { shortcut: "Ctrl+Y", alt_shortcut: "Ctrl+Shift+Z" });
    menu.add_menu("Edit", [
        mi_undo,
        mi_redo,
        gmforms_menu_separator(),
        gmforms_menu_item("Clear map", method(self, function(_s, _it) { form.find("btnClear").click(); }), { shortcut: "Ctrl+Delete" }),
    ]);
    menu.add_menu("Tools", [
        gmforms_menu_item("Paint",  method(self, function(_s, _it) { set_tool("paint"); update_status(); }), { shortcut: "Ctrl+1" }),
        gmforms_menu_item("Select", method(self, function(_s, _it) { set_tool("select"); update_status(); }), { shortcut: "Ctrl+2" }),
    ]);
    menu.add_menu("View", [
        gmforms_menu_item("Zoom in",    method(self, function(_s, _it) { zoom_by(1.25); }), { shortcut: "Ctrl+Up" }),
        gmforms_menu_item("Zoom out",   method(self, function(_s, _it) { zoom_by(0.8); }), { shortcut: "Ctrl+Down" }),
        gmforms_menu_item("Reset view", method(self, function(_s, _it) { vp.cam = { x: -16, y: -16, zoom: 0.7 }; update_status(); }), { shortcut: "Ctrl+0" }),
        gmforms_menu_separator(),
        gmforms_menu_item("Show grid", method(self, function(_s, _it) { show_grid = !show_grid; _it.checked = show_grid; }), { checked: true }),
        gmforms_menu_item("Map properties", method(self, function(_s, _it) { inspect_map(); }), { shortcut: "F4" }),
    ]);

    // Right-click on the inspector: a context menu.
    grid.popup_menu = gmforms_create(GMF_PopupMenu, { items: [
        gmforms_menu_item("Inspect map properties", method(self, function(_s, _it) { inspect_map(); })),
        gmforms_menu_item("Inspect current tile",   method(self, function(_s, _it) { if (cur_tile >= 0) inspect_tile(cur_tile); })),
    ] });

    form.find("btnNew").on_click      = method(self, function(_s) { load_doc(demo_tiles_new_doc(), "New map"); });
    form.find("btnOpen").on_click     = method(self, function(_s) { open_doc(); });
    form.find("btnSave").on_click     = method(self, function(_s) { save_doc(); });
    form.find("btnUndo").on_click     = method(self, function(_s) { do_undo(); });
    form.find("btnRedo").on_click     = method(self, function(_s) { do_redo(); });
    form.find("btnPaint").on_click    = method(self, function(_s) { set_tool("paint"); update_status(); });
    form.find("btnSelect").on_click   = method(self, function(_s) { set_tool("select"); update_status(); });
    form.find("btnClear").on_click    = method(self, function(_s) {
        demo_tiles_clear(doc, undo);
        set_status("Cleared the map (Undo restores it from a JSON snapshot)");
    });
    form.find("btnMapProps").on_click = method(self, function(_s) { inspect_map(); });
    undo.on_change = method(self, function(_u) {
        form.find("btnUndo").set_enabled(_u.can_undo());
        form.find("btnRedo").set_enabled(_u.can_redo());
        mi_undo.enabled = _u.can_undo();
        mi_redo.enabled = _u.can_redo();
        mi_undo.caption = _u.can_undo() ? ("Undo " + _u.undo_label()) : "Undo";
        mi_redo.caption = _u.can_redo() ? ("Redo " + _u.redo_label()) : "Redo";
    });

    grid.undo = undo;
    grid.on_change = method(self, function(_s, _key, _old, _new, _owner) {
        set_status("Set " + string(_key) + " = " + string(_new));
    });

    vp.on_draw = method(self, function(_s, _cam) { draw_map(); });
    vp.on_mouse_down = method(self, function(_s, _wx, _wy, _btn) {
        if (tool == "paint" && (_btn == mb_left || _btn == mb_right)) {
            painting = true;
            paint_value = (_btn == mb_left) ? cur_tile : -1;
            undo.begin_group((paint_value < 0) ? "Erase stroke" : "Paint stroke");
            _last_wx = _wx;
            _last_wy = _wy;
            paint_to(_wx, _wy);
            return;
        }
        var _i = cell_at(_wx, _wy);
        if (tool == "select" && _i >= 0) {
            if (_btn == mb_left) inspect_cell(_i);
            else if (_btn == mb_right && doc.cells[_i].t >= 0) { cur_tile = doc.cells[_i].t; update_status(); }
        }
    });
    vp.on_mouse_move = method(self, function(_s, _wx, _wy) {
        hover_cell = cell_at(_wx, _wy);
        if (painting) paint_to(_wx, _wy);
        update_status();
    });
    vp.on_mouse_up = method(self, function(_s, _wx, _wy, _btn) {
        if (!painting) return;
        painting = false;
        undo.end_group();
    });
    vp.on_wheel = method(self, function(_s, _d) { update_status(); });

    set_tool("paint");
    load_doc(doc, "Paint with the left mouse button, erase with the right. Middle-drag pans, wheel zooms.");
}

/// @func demo_tiles_capture_step(app, frame)
/// @desc Scripted visual check used when DEMO_TILES_CAPTURE is true: screenshots go to the save area.
function demo_tiles_capture_step(_app, _t) {
    switch (_t) {
        case 30:
            screen_save("m4_a_start.png");
            break;
        case 31:
            _app.set_tool("select");
            _app.inspect_cell(5 * _app.doc.cols + 6);
            _app.grid.focus();
            _app.grid.begin_edit(_app.grid.find_row("tag"), "chest");
            break;
        case 45:
            screen_save("m4_b_cell_edit.png");
            break;
        case 46:
            _app.grid.commit_edit();
            _app.inspect_map();
            _app.grid.set_expanded("camera", true);
            _app.grid.set_expanded("tags", true);
            _app.grid.select(_app.grid.find_row("gravity"));
            break;
        case 60:
            screen_save("m4_c_map_props.png");
            break;
        case 61:
            _app.undo.begin_group("capture strokes");
            for (var _i = 3; _i < 12; _i++) demo_tiles_paint(_app.doc, _app.undo, _i, 10, 4);
            _app.undo.end_group();
            _app.cur_tile = 4;
            _app.set_tool("paint");
            _app.inspect_tile(4);
            _app.grid.select(_app.grid.find_row("damage"));
            _app.update_status();
            break;
        case 75:
            screen_save("m4_d_tile.png");
            break;
        case 76:
            _app.menu.open_menu(1, true);         // Edit menu, first item selected
            break;
        case 90:
            screen_save("m4_e_menu.png");
            break;
        case 91:
            _app.form.close_popups();
            _app.set_tool("select");
            _app.inspect_cell(10 * _app.doc.cols + 5);
            _app.grid._open_enum_dropdown(_app.grid.find_row("t"));
            break;
        case 105:
            screen_save("m4_f_dropdown.png");
            show_debug_message("[GMForms] capture dir: " + game_save_id);
            break;
        case 106:
            game_end();
            break;
    }
}
