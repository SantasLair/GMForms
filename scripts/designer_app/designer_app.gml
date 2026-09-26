/// GMForms designer (M6 MVP, plan section 14) — built with the runtime library itself (decision D9).
///
///   MenuBar / Toolbar
///   ┌──────────┬───────────────────────────────┬──────────────┐
///   │ Palette  │ Design canvas (form preview)  │ Properties / │
///   ├──────────┤                               │ Events       │
///   │ Structure│                               │ (PropertyGrid)│
///   └──────────┴───────────────────────────────┴──────────────┘
///   Status bar
///
/// Undo uses JSON snapshots of the whole designed form (GMF_UndoStack.push_snapshot): every
/// committed change — create, move, resize, reparent, delete, inspector edit — is one step.
///
/// Scripting: the same operations the UI uses are public — new_form(), canvas.create_control(),
/// set_prop(), set_event(), save_file()... designer_scripts shows the tile editor's form being
/// rebuilt that way.

#macro DESIGNER_EXPORT_TILES false   // true: rebuild the tile editor form with the designer, save it to the save area, quit

/// @func DesignerApp()
function DesignerApp() constructor {
    target = undefined;         // the GMF_Form being designed
    path = "";                  // current file ("" = not saved yet)
    dirty = false;
    undo = new GMF_UndoStack(200);
    _snap_json = "";
    _syncing = false;
    _tree_collapsed = {};

    // ---- designer UI -------------------------------------------------------------
    form = gmforms_create(GMF_Form, { name: "frmDesigner", caption: "GMForms Designer", width: 1024, height: 700 });
    menu = form.add(gmforms_create(GMF_MenuBar, { name: "mbDesigner" }));

    var _tb = form.add(gmforms_create(GMF_Toolbar, { name: "tbDesigner" }));
    _tb.add_button("New",    undefined, { name: "tbNew" });
    _tb.add_button("Open",   undefined, { name: "tbOpen" });
    _tb.add_button("Save",   undefined, { name: "tbSave" });
    _tb.add_separator();
    _tb.add_button("Undo",   undefined, { name: "tbUndo" });
    _tb.add_button("Redo",   undefined, { name: "tbRedo" });
    _tb.add_separator();
    _tb.add_button("Delete", undefined, { name: "tbDelete" });
    _tb.add_button("Front",  undefined, { name: "tbFront" });
    _tb.add_button("Back",   undefined, { name: "tbBack" });
    _tb.add_separator();
    _tb.add_button("Snap",   undefined, { name: "tbSnap", down: true });

    var _sb = form.add(gmforms_create(GMF_Panel, { name: "pnlStatus", align: "bottom", height: 26 }));
    status = _sb.add(gmforms_create(GMF_Label, { name: "lblStatus", caption: "", left: 4, top: 2, width: 1016, height: 22,
        anchors: ["left", "top", "right"] }));

    var _left = form.add(gmforms_create(GMF_Panel, { name: "pnlLeft", align: "left", width: 200 }));
    _left.add(gmforms_create(GMF_Label, { name: "lblPalette", caption: "Palette", align: "top", height: 22 }));
    palette = _left.add(gmforms_create(GMF_ListBox, { name: "lbPalette", align: "top", height: 250,
        margin: { l: 4, t: 0, r: 4, b: 4 } }));
    _left.add(gmforms_create(GMF_Splitter, { name: "splLeft", align: "top", height: 4, min_size: 80 }));
    _left.add(gmforms_create(GMF_Label, { name: "lblStructure", caption: "Structure", align: "top", height: 22 }));
    tree = _left.add(gmforms_create(GMF_TreeView, { name: "tvStructure", align: "client", margin: { l: 4, t: 0, r: 4, b: 4 } }));
    form.add(gmforms_create(GMF_Splitter, { name: "splPalette", align: "left", width: 4, min_size: 140 }));

    var _right = form.add(gmforms_create(GMF_Panel, { name: "pnlRight", align: "right", width: 320 }));
    inspector_caption = _right.add(gmforms_create(GMF_Label, { name: "lblSelected", caption: "", align: "top", height: 24 }));
    inspector_tabs = _right.add(gmforms_create(GMF_TabControl, { name: "tabInspector", align: "client", margin: { l: 4, t: 0, r: 4, b: 4 } }));
    var _pp = inspector_tabs.add_page("Properties");
    var _pe = inspector_tabs.add_page("Events");
    props_grid = _pp.add(gmforms_create(GMF_PropertyGrid, { name: "gridProps", align: "client", name_width: 130 }));
    _pe.add(gmforms_create(GMF_Label, { name: "lblEventsHint", align: "top", height: 22,
        caption: "Double-click: default handler name" }));
    events_grid = _pe.add(gmforms_create(GMF_PropertyGrid, { name: "gridEvents", align: "client", name_width: 130 }));
    form.add(gmforms_create(GMF_Splitter, { name: "splInspector", align: "right", width: 4, min_size: 200 }));

    canvas = form.add(gmforms_create(GMF_DesignCanvas, { name: "canvasDesign", align: "client" }));

    // palette: every registered class except the ones that only exist inside another control
    var _classes = struct_get_names(gmforms_init().registry);
    array_sort(_classes, true);
    for (var _i = 0; _i < array_length(_classes); _i++) {
        if (_classes[_i] == "Form" || _classes[_i] == "TabSheet") continue;
        palette.add_item(_classes[_i]);
    }

    // -----------------------------------------------------------------------
    // Document
    // -----------------------------------------------------------------------

    static set_status = function(_t) { status.caption = _t; };

    static _update_caption = function() {
        var _file = (path != "") ? filename_name(path) : "untitled";
        form.caption = "GMForms Designer - " + _file + (dirty ? " *" : "");
    };

    /// @func new_form([props])
    /// @desc Starts a new, empty form (clears undo).
    static new_form = function(_props = undefined) {
        var _f = gmforms_create(GMF_Form, { name: "frmMain", caption: "New form", width: 640, height: 480 });
        if (is_struct(_props)) _f.set(_props);
        path = "";
        _set_target(_f);
        set_status("New form. Pick a control in the palette, then click or drag on the form.");
        return _f;
    };

    static _set_target = function(_f) {
        target = _f;
        canvas.set_target(_f);
        undo.clear();
        _snap_json = gmforms_form_to_json(_f);
        dirty = false;
        rebuild_tree();
        _bind_inspector(canvas.selected);
        _update_caption();
    };

    /// @func commit(label)
    /// @desc Records the current form as one undo step (if it changed since the last one).
    static commit = function(_label) {
        if (target == undefined) return;
        var _after = gmforms_form_to_json(target);
        if (_after == _snap_json) return;
        undo.push_snapshot(_label, _snap_json, _after, method(self, function(_json) { _restore(_json); }));
        _snap_json = _after;
        dirty = true;
        _update_caption();
        rebuild_tree();
    };

    /// Undo/redo: rebuild the form from a snapshot, keeping the selection by name.
    static _restore = function(_json) {
        var _sel = (canvas.selected != undefined) ? canvas.selected.name : "";
        var _f = gmforms_load_form_json(_json);
        if (_f == undefined) return;
        target = _f;
        canvas.set_target(_f);
        var _c = (_sel != "") ? _f.find(_sel) : undefined;
        if (_c != undefined) canvas.select(_c);
        _snap_json = _json;
        dirty = true;
        _update_caption();
        rebuild_tree();
    };

    /// @func do_undo() / do_redo()
    static do_undo = function() {
        props_grid.cancel_edit();
        events_grid.cancel_edit();
        var _l = undo.undo_label();
        set_status(undo.undo() ? ("Undid: " + _l) : "Nothing to undo");
    };
    static do_redo = function() {
        props_grid.cancel_edit();
        events_grid.cancel_edit();
        var _l = undo.redo_label();
        set_status(undo.redo() ? ("Redid: " + _l) : "Nothing to redo");
    };

    /// @func set_prop(control, key, value)
    /// @desc Sets a published property the way the inspector does (through set()) and commits.
    static set_prop = function(_c, _key, _value) {
        var _s = {};
        _s[$ _key] = _value;
        _c.set(_s);
        commit("Set " + _key);
        if (_c == canvas.selected) props_grid.refresh();
    };

    /// @func set_props(control, props, [label])
    /// @desc Sets several published properties at once (one undo step).
    static set_props = function(_c, _props, _label = "Set properties") {
        _c.set(_props);
        commit(_label);
        if (_c == canvas.selected) props_grid.refresh();
    };

    /// @func set_event(control, event, handler_name)
    /// @desc Binds an event ("onClick") to a handler name ("" removes it) and commits.
    static set_event = function(_c, _event, _name) {
        var _field = __gmforms_event_field(_event);
        if (_name == "") struct_remove(_c._ev_names, _field); else _c._ev_names[$ _field] = _name;
        commit("Set " + _event);
        if (_c == canvas.selected) _bind_inspector(_c);
    };

    // -----------------------------------------------------------------------
    // Files
    // -----------------------------------------------------------------------

    /// @func open_file(path)
    static open_file = function(_path) {
        var _before = gmforms_init().log_count;
        var _f = gmforms_load_form(_path);
        if (_f == undefined) {
            set_status("Could not open " + _path + " (see the Output log). With the file system sandbox on, only the save area, Included Files and files picked in the dialog are readable.");
            return false;
        }
        path = _path;
        _set_target(_f);
        set_status("Opened " + _path + ((gmforms_init().log_count > _before) ? "  (with warnings, see the Output log)" : ""));
        return true;
    };

    /// @func save_file(path)
    static save_file = function(_path) {
        props_grid.commit_edit();
        events_grid.commit_edit();
        gmforms_save_form(_path, target);
        if (!file_exists(_path)) {
            set_status("Could not save " + _path);
            return false;
        }
        path = _path;
        dirty = false;
        _update_caption();
        set_status("Saved " + _path);
        return true;
    };

    static open_dialog = function() {
        var _p = get_open_filename_ext("GMForms form (*.json)|*.json", "", "", "Open form");
        if (_p != "") open_file(_p);
    };

    static save = function() {
        if (path == "") save_as(); else save_file(path);
    };

    static save_as = function() {
        var _p = get_save_filename_ext("GMForms form (*.json)|*.json", target.name + ".gmform.json", "", "Save form as");
        if (_p != "") save_file(_p);
    };

    /// @func handlers_source([existing])
    static handlers_source = function(_existing = "") {
        return gmforms_design_handlers_source(target, _existing);
    };

    static generate_handlers = function() {
        var _p = get_save_filename_ext("GML script (*.gml)|*.gml", gmforms_design_handlers_name(target) + ".gml", "", "Generate handlers");
        if (_p == "") return;
        var _old = file_exists(_p) ? (gmforms_read_text_file(_p) ?? "") : "";
        var _src = handlers_source(_old);
        gmforms_write_text_file(_p, _src);
        set_status((_src == _old) ? ("All handlers already exist in " + _p) : ("Wrote " + _p));
    };

    static copy_handlers = function() {
        try {
            clipboard_set_text(handlers_source());
            set_status("Copied " + string(array_length(gmforms_design_collect_handlers(target))) + " handler stubs to the clipboard");
        } catch (_e) {
            set_status("Clipboard not available");
        }
    };

    // -----------------------------------------------------------------------
    // Structure tree and inspector
    // -----------------------------------------------------------------------

    /// @func rebuild_tree()
    static rebuild_tree = function() {
        tree.clear();
        if (target == undefined) return;
        tree.nodes = [_tree_node(target)];
        tree.refresh();
        _sync_tree_selection();
    };

    static _tree_node = function(_c) {
        var _n = { text: ((_c.name != "") ? _c.name : "(unnamed)") + " : " + _c.class_name, nodes: [],
            expanded: (_tree_collapsed[$ _c.name] != true), data: _c };
        for (var _i = 0; _i < array_length(_c.children); _i++) array_push(_n.nodes, _tree_node(_c.children[_i]));
        return _n;
    };

    static _find_node = function(_list, _c) {
        for (var _i = 0; _i < array_length(_list); _i++) {
            if (_list[_i].data == _c) return _list[_i];
            var _r = _find_node(_list[_i].nodes, _c);
            if (_r != undefined) return _r;
        }
        return undefined;
    };

    static _sync_tree_selection = function() {
        _syncing = true;
        tree.select_node(_find_node(tree.nodes, canvas.selected), false);
        _syncing = false;
    };

    static _bind_inspector = function(_c) {
        props_grid.cancel_edit();
        events_grid.cancel_edit();
        if (_c == undefined) {
            props_grid.bind(undefined);
            events_grid.bind(undefined);
            inspector_caption.caption = "";
            return;
        }
        inspector_caption.caption = _c.name + " : " + _c.class_name;
        props_grid.bind_control(_c);
        // Events: a proxy struct of handler names; writing one updates the control's _ev_names.
        var _proxy = {};
        var _meta = [];
        var _pub = designer_published_list(_c);
        for (var _i = 0; _i < array_length(_pub); _i++) {
            var _p = _pub[_i];
            if (_p.type != "event") continue;
            _proxy[$ _p.name] = _c._ev_names[$ __gmforms_event_field(_p.name)] ?? "";
            array_push(_meta, {
                name: _p.name,
                type: "string",
                ctrl: _c,
                set_fn: function(_owner, _field, _value) {
                    _owner[$ _field] = _value;
                    var _f = __gmforms_event_field(_field);
                    if (_value == "") struct_remove(ctrl._ev_names, _f); else ctrl._ev_names[$ _f] = _value;
                },
            });
        }
        events_grid.bind(_proxy, _meta);
    };

    /// Default handler name for a double-clicked event row: <control>_<Event>, e.g. btnSave_Click.
    static default_handler = function(_c, _event) {
        return _c.name + "_" + string_delete(_event, 1, 2);
    };

    // -----------------------------------------------------------------------
    // Menus and wiring
    // -----------------------------------------------------------------------

    static set_snap = function(_on) {
        canvas.snap = _on;
        form.find("tbSnap").down = _on;
        menu.find_item("Snap to grid").checked = _on;
    };

    static set_grid_size = function(_n) {
        canvas.grid_size = _n;
        menu.find_item("4 px").checked = (_n == 4);
        menu.find_item("8 px").checked = (_n == 8);
        menu.find_item("16 px").checked = (_n == 16);
    };

    mi_undo = gmforms_menu_item("Undo", method(self, function(_s, _it) { do_undo(); }), { shortcut: "Ctrl+Z" });
    mi_redo = gmforms_menu_item("Redo", method(self, function(_s, _it) { do_redo(); }), { shortcut: "Ctrl+Y", alt_shortcut: "Ctrl+Shift+Z" });
    menu.add_menu("File", [
        gmforms_menu_item("New",      method(self, function(_s, _it) { new_form(); }), { shortcut: "Ctrl+N" }),
        gmforms_menu_item("Open...",  method(self, function(_s, _it) { open_dialog(); }), { shortcut: "Ctrl+O" }),
        gmforms_menu_item("Open the tile editor's form", method(self, function(_s, _it) { open_file("tile_editor.gmform.json"); })),
        gmforms_menu_separator(),
        gmforms_menu_item("Save",     method(self, function(_s, _it) { save(); }), { shortcut: "Ctrl+S" }),
        gmforms_menu_item("Save as...", method(self, function(_s, _it) { save_as(); }), { shortcut: "Ctrl+Shift+S" }),
        gmforms_menu_item("Save to the save area", method(self, function(_s, _it) { save_file(target.name + ".gmform.json"); })),
        gmforms_menu_separator(),
        gmforms_menu_item("Generate handlers...", method(self, function(_s, _it) { generate_handlers(); }), { shortcut: "Ctrl+G" }),
        gmforms_menu_item("Copy handler stubs",   method(self, function(_s, _it) { copy_handlers(); })),
        gmforms_menu_separator(),
        gmforms_menu_item("Back to the tile editor", function(_s, _it) { room_goto(rm_demo_tiles); }),
        gmforms_menu_item("Exit", function(_s, _it) { game_end(); }, { shortcut: "Ctrl+Q" }),
    ]);
    menu.add_menu("Edit", [
        mi_undo,
        mi_redo,
        gmforms_menu_separator(),
        gmforms_menu_item("Delete",         method(self, function(_s, _it) { canvas.delete_selected(); }), { shortcut: "Del" }),
        gmforms_menu_item("Bring to front", method(self, function(_s, _it) { canvas.bring_to_front(); })),
        gmforms_menu_item("Send to back",   method(self, function(_s, _it) { canvas.send_to_back(); })),
        gmforms_menu_item("Select parent",  method(self, function(_s, _it) { canvas.select_parent(); }), { shortcut: "Esc" }),
        gmforms_menu_separator(),
        gmforms_menu_item("Add tab page",   method(self, function(_s, _it) { canvas.add_tab_page(); })),
    ]);
    menu.add_menu("View", [
        gmforms_menu_item("Snap to grid", method(self, function(_s, _it) { set_snap(!canvas.snap); }), { checked: true }),
        gmforms_menu_item("Show grid", method(self, function(_s, _it) { canvas.show_grid = !canvas.show_grid; _it.checked = canvas.show_grid; }), { checked: true }),
        gmforms_submenu("Grid size", [
            gmforms_menu_item("4 px",  method(self, function(_s, _it) { set_grid_size(4); })),
            gmforms_menu_item("8 px",  method(self, function(_s, _it) { set_grid_size(8); }), { checked: true }),
            gmforms_menu_item("16 px", method(self, function(_s, _it) { set_grid_size(16); })),
        ]),
    ]);

    canvas.popup_menu = gmforms_create(GMF_PopupMenu, { items: [
        gmforms_menu_item("Delete",         method(self, function(_s, _it) { canvas.delete_selected(); })),
        gmforms_menu_item("Bring to front", method(self, function(_s, _it) { canvas.bring_to_front(); })),
        gmforms_menu_item("Send to back",   method(self, function(_s, _it) { canvas.send_to_back(); })),
        gmforms_menu_item("Select parent",  method(self, function(_s, _it) { canvas.select_parent(); })),
        gmforms_menu_separator(),
        gmforms_menu_item("Add tab page",   method(self, function(_s, _it) { canvas.add_tab_page(); })),
    ] });

    form.find("tbNew").on_click    = method(self, function(_s) { new_form(); });
    form.find("tbOpen").on_click   = method(self, function(_s) { open_dialog(); });
    form.find("tbSave").on_click   = method(self, function(_s) { save(); });
    form.find("tbUndo").on_click   = method(self, function(_s) { do_undo(); });
    form.find("tbRedo").on_click   = method(self, function(_s) { do_redo(); });
    form.find("tbDelete").on_click = method(self, function(_s) { canvas.delete_selected(); });
    form.find("tbFront").on_click  = method(self, function(_s) { canvas.bring_to_front(); });
    form.find("tbBack").on_click   = method(self, function(_s) { canvas.send_to_back(); });
    form.find("tbSnap").on_click   = method(self, function(_s) { set_snap(!canvas.snap); });

    undo.on_change = method(self, function(_u) {
        form.find("tbUndo").set_enabled(_u.can_undo());
        form.find("tbRedo").set_enabled(_u.can_redo());
        mi_undo.enabled = _u.can_undo();
        mi_redo.enabled = _u.can_redo();
        mi_undo.caption = _u.can_undo() ? ("Undo " + _u.undo_label()) : "Undo";
        mi_redo.caption = _u.can_redo() ? ("Redo " + _u.redo_label()) : "Redo";
    });

    palette.on_change = method(self, function(_s, _i) {
        canvas.place_class = _s.get_text();
        if (canvas.place_class != "") {
            set_status("Click on the form to place a " + canvas.place_class + ", or drag out its size. Shift keeps it armed; Esc cancels.");
        }
    });
    canvas.on_placed = method(self, function(_s, _c) {
        if (canvas.place_class == "") palette.set_item_index(-1, false);
        if (_c != undefined) set_status("Placed " + _c.name);
    });
    canvas.on_select = method(self, function(_s, _c) {
        _bind_inspector(_c);
        if (!_syncing) _sync_tree_selection();
    });
    canvas.on_modified = method(self, function(_s, _label) {
        commit(_label);
        props_grid.refresh();
    });

    tree.on_change = method(self, function(_s, _node) {
        if (_syncing || _node == undefined) return;
        _syncing = true;
        canvas.select(_node.data);
        _syncing = false;
    });
    tree.on_expand = method(self, function(_s, _node, _open) {
        if (_open) struct_remove(_tree_collapsed, _node.data.name); else _tree_collapsed[$ _node.data.name] = true;
    });

    props_grid.on_change = method(self, function(_s, _key, _old, _new, _owner) {
        if (_key == "name" && _owner == canvas.selected) {
            var _other = target.find(_new);
            if (_new == "" || (_other != undefined && _other != _owner)) {
                _owner.set({ name: _old });
                set_status("Name '" + string(_new) + "' is empty or already used");
                return;
            }
            inspector_caption.caption = _owner.name + " : " + _owner.class_name;
        }
        commit("Set " + string(_key));
    });
    // double-click a menu item's onClick row: <menubar>_<Caption>_Click
    props_grid.on_dbl_click = method(self, function(_s, _key, _owner) {
        if (_key != "onClick" || !is_struct(_owner) || (_owner[$ "on_click_name"] ?? "") != "") return;
        _s.set_row_value(_s.get_selected(), canvas.selected.name + "_" + gmforms_design_ident(_owner.caption) + "_Click");
    });
    events_grid.on_change = method(self, function(_s, _key, _old, _new, _owner) { commit("Set " + string(_key)); });
    events_grid.on_dbl_click = method(self, function(_s, _key, _owner) {
        if ((_owner[$ _key] ?? "") != "") return;
        _s.set_row_value(_s.get_selected(), default_handler(canvas.selected, _key));
        set_status("Handler name set; File > Generate handlers writes the stubs");
    });

    new_form();
}

/// @func designer_published_list(control)
/// @desc A control's published entries in order, deduplicated (the last entry for a name wins).
function designer_published_list(_c) {
    var _order = [];
    var _map = {};
    var _list = _c.published;
    for (var _i = 0; _i < array_length(_list); _i++) {
        if (!struct_exists(_map, _list[_i].name)) array_push(_order, _list[_i].name);
        _map[$ _list[_i].name] = _list[_i];
    }
    var _out = [];
    for (var _i = 0; _i < array_length(_order); _i++) array_push(_out, _map[$ _order[_i]]);
    return _out;
}
