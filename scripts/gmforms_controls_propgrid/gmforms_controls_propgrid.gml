/// GMForms — GMF_PropertyGrid: edits a struct's fields with auto-generated editors (plan section 11).
///
///   grid.bind(struct)              infer editors from the value types
///   grid.bind(struct, metadata)    metadata-driven: an array of entries such as
///       { name: "hp", type: "int", min: 0, max: 999, step: 5, category: "Stats", label: "Hit points" }
///   grid.bind_control(control)     the control's published properties (the designer's Object Inspector)
///
/// Metadata entry fields (all optional except name):
///   type      string | int | real | bool | enum | color | sprite | font | anchors | struct | array
///   label     display name (default: name)
///   category  rows with a category are grouped under a collapsible header; rows without one come first
///   readonly  true = shown but not editable
///   values    enum: the stored values; labels: matching display names (default: string(value))
///   min, max, step   numbers (or range: { min, max, step })
///   fields    struct: metadata for the nested struct's fields (default: inferred)
///   set_fn    function(owner, field, value) used instead of a plain field write
///
/// Inferred types: bool, string, real (any number), struct and array (expandable). Fields that start
/// with "_" and function values are skipped.
///
/// Editing: click a value (or press Enter / start typing) to edit text and numbers in place; Enter
/// commits, Escape cancels, focus loss commits. Bools toggle on click/Space. Enums open a dropdown
/// on click (Enter / Left / Right / right-click cycle through the values instead). Colours open the
/// colour popup from the swatch (one undo step per drag) or take #RRGGBB text. Sprites open a
/// thumbnail dropdown (metadata `values` limits the list). Numbers have -/+ spin buttons and Left/Right steps.
///
/// Events: on_change(sender, key, old_value, new_value, owner) — owner is the struct (or array)
/// that was written, which differs from the bound target for nested rows. It also fires when an
/// edit is undone or redone. Set `undo` to a GMF_UndoStack and every edit is recorded there.

/// @func GMF_PropertyGrid()
function GMF_PropertyGrid() : GMF_Control() constructor {
    class_name = "PropertyGrid";
    width = 260;
    height = 300;
    tab_stop = true;
    name_width = 110;           // name column width in pixels (drag the divider to change it)
    row_height = 22;
    indent = 12;                // per nesting level
    readonly = false;           // true = the whole grid is read-only
    empty_text = "(nothing selected)";
    undo = undefined;           // optional GMF_UndoStack
    on_dbl_click = undefined;   // (sender, key, owner) — a row was double-clicked

    target = undefined;         // bound struct (or array)
    meta = undefined;           // bound metadata array, or undefined = inferred

    _rows = [];
    _rows_dirty = true;
    _expanded = {};             // row path -> true
    _collapsed_cats = {};       // category name -> true
    _sel = -1;
    _scroll_y = 0;
    _editing = false;
    _edit_path = "";
    _edit_orig = "";
    _edit_drag = false;
    _last_click_row = -1;
    _last_click_time = -100000;
    _drag_divider = false;
    _drag_scroll = false;
    _drag_off = 0;
    _sb_w = 10;                 // scrollbar width
    _spin_w = 14;               // width of each -/+ spin button
    _min_col = 40;              // minimum width of either column

    // In-place editor. It isn't a child (it would be serialized with the form); the grid positions,
    // draws and feeds it itself. parent is set so is_enabled()/get_form() work; _focus_proxy makes it
    // look focused whenever the grid is.
    _editor = new GMF_Edit();
    _editor.parent = self;
    _editor._focus_proxy = self;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",      type: "int",    default_value: 260 },
        { name: "height",     type: "int",    default_value: 300 },
        { name: "tab_stop",   type: "bool",   default_value: true },
        { name: "name_width", type: "int",    default_value: 110 },
        { name: "row_height", type: "int",    default_value: 22 },
        { name: "readonly",   type: "bool",   default_value: false },
        { name: "empty_text", type: "string", default_value: "(nothing selected)" },
    ]);

    // -----------------------------------------------------------------------
    // Binding
    // -----------------------------------------------------------------------

    /// @func bind(target, [metadata])
    /// @desc Shows target's fields. Without metadata the editors are inferred from the values.
    ///       A pending in-place edit is committed to the previous target first. Returns self.
    /// @param {Struct|Array|Undefined} target
    /// @param {Array} [metadata]
    static bind = function(_target, _meta = undefined) {
        if (_editing) commit_edit();
        if (_target != target) {
            _expanded = {};
            _sel = -1;
            _scroll_y = 0;
        }
        target = _target;
        meta = _meta;
        _rows_dirty = true;
        return self;
    };

    /// @func bind_control(control)
    /// @desc Shows a control's published (non-event) properties, written through control.set() so
    ///       layout updates. This is what the designer's Object Inspector does.
    static bind_control = function(_ctrl) {
        return bind(_ctrl, gmforms_control_grid_meta(_ctrl));
    };

    /// @func refresh()
    /// @desc Rebuilds the rows on the next frame. Call it after changing the bound struct's shape
    ///       from code (values are read live every frame, so plain value changes need no refresh).
    static refresh = function() { _rows_dirty = true; };

    /// @func row_count()
    static row_count = function() { _ensure_rows(); return array_length(_rows); };

    /// @func get_row(index)
    /// @desc Row struct { kind: "prop"|"category", label, path, depth, owner, meta, expandable }, or undefined.
    static get_row = function(_i) {
        _ensure_rows();
        return (_i >= 0 && _i < array_length(_rows)) ? _rows[_i] : undefined;
    };

    /// @func find_row(path)
    /// @desc Index of the row with this path, or -1. Paths are field names joined with ".", e.g.
    ///       "stats.hp" or "tags.0"; category headers are "#" + category.
    static find_row = function(_path) {
        _ensure_rows();
        var _n = array_length(_rows);
        for (var _i = 0; _i < _n; _i++) if (_rows[_i].path == _path) return _i;
        return -1;
    };

    /// @func get_selected()
    static get_selected = function() { return _sel; };

    /// @func select(index)
    /// @desc Selects a row and scrolls it into view.
    static select = function(_i) {
        _ensure_rows();
        var _n = array_length(_rows);
        if (_n == 0) { _sel = -1; return; }
        _sel = clamp(_i, 0, _n - 1);
        ensure_visible(_sel);
    };

    /// @func ensure_visible(index)
    static ensure_visible = function(_i) {
        var _top = _i * row_height;
        if (_top < _scroll_y) _scroll_y = _top;
        if (_top + row_height > _scroll_y + height) _scroll_y = _top + row_height - height;
        _clamp_scroll();
    };

    /// @func set_expanded(path, expanded)
    /// @desc Expands or collapses a struct/array row, or a category ("#Name").
    static set_expanded = function(_path, _open) {
        if (string_char_at(_path, 1) == "#") {
            var _cat = string_delete(_path, 1, 1);
            if (_open) struct_remove(_collapsed_cats, _cat); else _collapsed_cats[$ _cat] = true;
        } else {
            if (_open) _expanded[$ _path] = true; else struct_remove(_expanded, _path);
        }
        _rows_dirty = true;
    };

    /// @func toggle_expand(index)
    /// @desc Toggles a category or an expandable row. Returns false if the row can't expand.
    static toggle_expand = function(_i) {
        var _row = get_row(_i);
        if (_row == undefined) return false;
        if (_row.kind == "category") {
            set_expanded(_row.path, _collapsed_cats[$ _row.label] == true);
            return true;
        }
        if (!_row.expandable) return false;
        set_expanded(_row.path, _expanded[$ _row.path] != true);
        return true;
    };

    // -----------------------------------------------------------------------
    // Editing
    // -----------------------------------------------------------------------

    /// @func set_row_value(index, value)
    /// @desc Writes a value through the row (undo, on_change and set_fn all apply). Returns true if it changed.
    static set_row_value = function(_i, _value) {
        var _row = get_row(_i);
        if (_row == undefined) return false;
        return _commit(_row, _value);
    };

    /// @func get_row_value(index)
    static get_row_value = function(_i) {
        var _row = get_row(_i);
        return (_row == undefined || _row.kind != "prop") ? undefined : _row_value(_row);
    };

    /// @func activate(index)
    /// @desc What Enter does: expands/collapses, toggles a bool, cycles an enum, or starts a text edit.
    static activate = function(_i) {
        var _row = get_row(_i);
        if (_row == undefined) return;
        if (_row.kind == "category" || _row.expandable) { toggle_expand(_i); return; }
        if (_is_readonly(_row)) return;
        switch (_row.meta.type) {
            case "bool": _commit(_row, !(_row_value(_row) == true)); break;
            case "enum": _enum_step(_row, 1); break;
            default:     begin_edit(_i); break;
        }
    };

    /// @func begin_edit(index, [initial_text])
    /// @desc Opens the in-place editor on a text/number row. initial_text replaces the value (typing
    ///       starts an edit that way); without it the current value is shown selected.
    /// @returns {Bool} False if the row isn't text-editable.
    static begin_edit = function(_i, _initial = undefined) {
        if (_editing) commit_edit();
        var _row = get_row(_i);
        if (_row == undefined || _row.kind != "prop" || _is_readonly(_row) || !_is_text_type(_row.meta.type)) return false;
        _sel = _i;
        ensure_visible(_i);
        _editing = true;
        _edit_path = _row.path;
        _edit_orig = _edit_text(_row);
        _editor.text = _initial ?? _edit_orig;
        _editor._scroll_x = 0;
        _place_editor();
        if (_initial == undefined) _editor.select_all();
        else _editor._move_caret(string_length(_editor.text), false);
        return true;
    };

    /// @func commit_edit()
    /// @desc Parses the editor text and writes it. Invalid input is logged and discarded.
    /// @returns {Bool} True if a value changed.
    static commit_edit = function() {
        if (!_editing) return false;
        _editing = false;
        _edit_drag = false;
        var _text = _editor.text;
        if (_text == _edit_orig) return false;
        var _i = find_row(_edit_path);
        if (_i < 0) return false;
        var _row = _rows[_i];
        var _p = _parse(_row, _text);
        if (!_p.ok) {
            gmforms_log("PropertyGrid: invalid value '" + _text + "' for " + _row.meta.label);
            return false;
        }
        return _commit(_row, _p.value);
    };

    /// @func cancel_edit()
    static cancel_edit = function() {
        _editing = false;
        _edit_drag = false;
    };

    /// @func is_editing()
    static is_editing = function() { return _editing; };

    // -----------------------------------------------------------------------
    // Rows
    // -----------------------------------------------------------------------

    static _ensure_rows = function() {
        if (_rows_dirty) _build_rows();
    };

    static _build_rows = function() {
        _rows_dirty = false;
        _rows = [];
        if (target != undefined) {
            var _entries = _entries_for(target, meta);
            var _n = array_length(_entries);
            var _cats = [];
            var _by_cat = {};
            for (var _i = 0; _i < _n; _i++) {
                var _m = _entries[_i];
                if (_m.category == "") {
                    _add_rows(target, _m, 0, string(_m.name));
                } else {
                    if (!struct_exists(_by_cat, _m.category)) {
                        _by_cat[$ _m.category] = [];
                        array_push(_cats, _m.category);
                    }
                    array_push(_by_cat[$ _m.category], _m);
                }
            }
            var _cn = array_length(_cats);
            for (var _c = 0; _c < _cn; _c++) {
                var _cat = _cats[_c];
                array_push(_rows, { kind: "category", label: _cat, path: "#" + _cat, depth: 0,
                    owner: undefined, meta: undefined, expandable: true });
                if (_collapsed_cats[$ _cat] == true) continue;
                var _list = _by_cat[$ _cat];
                var _ln = array_length(_list);
                for (var _i = 0; _i < _ln; _i++) _add_rows(target, _list[_i], 0, string(_list[_i].name));
            }
        }
        var _rn = array_length(_rows);
        if (_sel >= _rn) _sel = _rn - 1;
        if (_editing && find_row(_edit_path) < 0) cancel_edit();
        _clamp_scroll();
    };

    static _add_rows = function(_owner, _m, _depth, _path, _parent_row = undefined) {
        var _v = gmforms_get_value(_owner, _m.field);
        var _exp = (_m.type == "struct" && is_struct(_v)) || (_m.type == "array" && is_array(_v) && array_length(_v) > 0);
        var _label = _m.label;
        // elements of an array with a label_field show it, e.g. "[0] File" for menu items
        var _lf = (_parent_row != undefined) ? _parent_row.meta.label_field : undefined;
        if (_lf != undefined && is_struct(_v)) _label += " " + string(_v[$ _lf] ?? "");
        var _row = { kind: "prop", label: _label, path: _path, depth: _depth,
            owner: _owner, meta: _m, expandable: _exp, parent_row: _parent_row };
        array_push(_rows, _row);
        if (!_exp || _expanded[$ _path] != true) return;
        var _sub = _entries_for(_v, _m.fields, _m.element);
        var _n = array_length(_sub);
        for (var _i = 0; _i < _n; _i++) _add_rows(_v, _sub[_i], _depth + 1, _path + "." + string(_sub[_i].name), _row);
    };

    /// Resolved metadata for every field shown for owner (explicit list, or inferred). For arrays,
    /// `element` (a metadata entry without a name) describes every item.
    static _entries_for = function(_owner, _list, _element = undefined) {
        if (is_array(_owner) && is_struct(_element)) {
            var _out_el = [];
            var _en = array_length(_owner);
            var _keys = struct_get_names(_element);
            for (var _i = 0; _i < _en; _i++) {
                var _e = {};
                for (var _k = 0; _k < array_length(_keys); _k++) _e[$ _keys[_k]] = _element[$ _keys[_k]];
                _e.name = _i;
                _e.label = "[" + string(_i) + "]";
                array_push(_out_el, _resolve(_e, _owner));
            }
            return _out_el;
        }
        var _out = [];
        if (is_array(_list)) {
            var _n = array_length(_list);
            for (var _i = 0; _i < _n; _i++) {
                var _e = _list[_i];
                if (!is_struct(_e) || (_e[$ "type"] ?? "") == "event") continue;
                var _m = _resolve(_e, _owner);
                if (_m.type != "") array_push(_out, _m);
            }
        } else if (is_struct(_owner)) {
            var _names = struct_get_names(_owner);
            array_sort(_names, true);
            var _n = array_length(_names);
            for (var _i = 0; _i < _n; _i++) {
                if (string_char_at(_names[_i], 1) == "_") continue;
                var _m = _resolve({ name: _names[_i] }, _owner);
                if (_m.type != "") array_push(_out, _m);
            }
        } else if (is_array(_owner)) {
            var _n = array_length(_owner);
            for (var _i = 0; _i < _n; _i++) {
                var _m = _resolve({ name: _i, label: "[" + string(_i) + "]" }, _owner);
                if (_m.type != "") array_push(_out, _m);
            }
        }
        return _out;
    };

    static _resolve = function(_e, _owner) {
        var _field = _e[$ "field"] ?? _e.name;
        var _type = _e[$ "type"] ?? gmforms_infer_type(gmforms_get_value(_owner, _field));
        var _values = _e[$ "values"];
        if (_type == "enum" && !is_array(_values)) _type = "string";
        var _range = _e[$ "range"];
        var _rmin = is_struct(_range) ? _range[$ "min"] : undefined;
        var _rmax = is_struct(_range) ? _range[$ "max"] : undefined;
        var _rstep = is_struct(_range) ? _range[$ "step"] : undefined;
        var _root = target;
        return {
            name: _e.name,
            field: _field,
            label: _e[$ "label"] ?? string(_e.name),
            type: _type,
            category: _e[$ "category"] ?? "",
            readonly: (_e[$ "readonly"] ?? false) == true,
            values: _values,
            labels: _e[$ "labels"],
            min: _e[$ "min"] ?? _rmin,
            max: _e[$ "max"] ?? _rmax,
            step: _e[$ "step"] ?? (_rstep ?? 1),
            fields: _e[$ "fields"],
            set_fn: _e[$ "set_fn"],
            element: _e[$ "element"],           // arrays: metadata for every item
            resizable: (_e[$ "resizable"] ?? false) == true,   // arrays: + / x buttons add and remove items
            new_element: _e[$ "new_element"],   // arrays: function() returning a new item
            label_field: _e[$ "label_field"],   // arrays of structs: field shown next to "[i]"
            root: _root,
        };
    };

    static _row_value = function(_row) {
        return gmforms_get_value(_row.owner, _row.meta.field);
    };

    static _is_readonly = function(_row) {
        return readonly || _row.kind != "prop" || _row.meta.readonly;
    };

    static _is_text_type = function(_type) {
        switch (_type) {
            case "string": case "int": case "real": case "color":
            case "sprite": case "font": case "anchors":
                return true;
        }
        return false;
    };

    static _is_number = function(_type) { return _type == "int" || _type == "real"; };

    // -----------------------------------------------------------------------
    // Values: display text, edit text, parsing, writing
    // -----------------------------------------------------------------------

    static _value_text = function(_row) {
        var _m = _row.meta;
        var _v = _row_value(_row);
        switch (_m.type) {
            case "string":  return is_string(_v) ? _v : string(_v);
            case "int":
            case "real":    return gmforms_format_number(_v);
            case "bool":    return (_v == true) ? "True" : "False";
            case "enum":    return _enum_label(_m, _v);
            case "color":   return is_numeric(_v) ? gmforms_color_to_hex(_v) : "(default)";
            case "sprite":  return gmforms_sprite_label(_v, _m.values, _m.labels);
            case "font":    return __gmforms_asset_name(_v, asset_font, "(default)");
            case "anchors": return is_array(_v) ? __gmforms_join(_v, ", ") : "";
            case "struct":  return is_struct(_v) ? "{...}" : "(none)";
            case "array":   return is_array(_v) ? ("[" + string(array_length(_v)) + " items]") : "(none)";
        }
        return string(_v);
    };

    static _edit_text = function(_row) {
        var _m = _row.meta;
        var _v = _row_value(_row);
        switch (_m.type) {
            case "color":   return is_numeric(_v) ? gmforms_color_to_hex(_v) : "";
            case "sprite":  return __gmforms_asset_name(_v, asset_sprite, "");
            case "font":    return __gmforms_asset_name(_v, asset_font, "");
            case "anchors": return is_array(_v) ? __gmforms_join(_v, ",") : "";
        }
        return _value_text(_row);
    };

    /// Returns { ok, value }.
    static _parse = function(_row, _text) {
        var _m = _row.meta;
        switch (_m.type) {
            case "int":
            case "real":
                var _v = __gmforms_parse_number(_text);
                if (_v == undefined) return { ok: false };
                return { ok: true, value: _clamp_number(_m, _v) };
            case "color":
                if (string_trim(_text) == "") return { ok: true, value: undefined };
                var _c = gmforms_color_from_hex(_text);
                return { ok: (_c != undefined), value: _c };
            case "sprite":
            case "font":
                var _name = string_trim(_text);
                if (_name == "") return { ok: true, value: -1 };
                var _kind = (_m.type == "sprite") ? asset_sprite : asset_font;
                if (asset_get_type(_name) != _kind) return { ok: false };
                return { ok: true, value: asset_get_index(_name) };
            case "anchors":
                var _parts = string_split(_text, ",", true);
                var _out = [];
                var _n = array_length(_parts);
                for (var _i = 0; _i < _n; _i++) {
                    var _p = string_lower(string_trim(_parts[_i]));
                    if (!array_contains(["left", "top", "right", "bottom"], _p)) return { ok: false };
                    if (!array_contains(_out, _p)) array_push(_out, _p);
                }
                return { ok: true, value: _out };
        }
        return { ok: true, value: _text };
    };

    static _clamp_number = function(_m, _v) {
        if (_m.type == "int") _v = round(_v);
        if (_m.min != undefined) _v = max(_v, _m.min);
        if (_m.max != undefined) _v = min(_v, _m.max);
        return _v;
    };

    static _step_value = function(_row, _dir) {
        var _v = _row_value(_row);
        if (!is_numeric(_v)) _v = 0;
        var _nv = round((_v + _dir * _row.meta.step) * 1000000) / 1000000;  // no float drift from e.g. 0.1 steps
        return _commit(_row, _clamp_number(_row.meta, _nv));
    };

    static _enum_index = function(_m, _v) {
        var _n = array_length(_m.values);
        for (var _i = 0; _i < _n; _i++) if (gmforms_value_equals(_m.values[_i], _v)) return _i;
        return -1;
    };

    static _enum_label = function(_m, _v) {
        var _i = _enum_index(_m, _v);
        if (_i < 0) return string(_v);
        if (is_array(_m.labels) && _i < array_length(_m.labels)) return string(_m.labels[_i]);
        return string(_m.values[_i]);
    };

    static _enum_step = function(_row, _dir) {
        var _m = _row.meta;
        var _n = array_length(_m.values);
        if (_n == 0) return false;
        var _i = _enum_index(_m, _row_value(_row));
        _i = (_i < 0) ? 0 : ((_i + _dir + _n) mod _n);
        return _commit(_row, _m.values[_i]);
    };

    /// Writes a value, records it on the undo stack and fires on_change. Returns true if it changed.
    static _commit = function(_row, _value) {
        if (_is_readonly(_row)) return false;
        var _m = _row.meta;
        var _old = gmforms_get_value(_row.owner, _m.field);
        if (gmforms_value_equals(_old, _value)) return false;
        _apply(_row.owner, _m, _value);
        if (undo != undefined) {
            var _grid = self;   // inside a struct literal, self is the new struct
            undo.push({
                label: "Set " + _m.label,
                grid: _grid,
                owner: _row.owner,
                meta: _m,
                old_value: _old,
                new_value: _value,
                do_fn: function() {
                    grid._apply(owner, meta, new_value);
                    grid._fire_change(owner, meta, old_value, new_value);
                },
                undo_fn: function() {
                    grid._apply(owner, meta, old_value);
                    grid._fire_change(owner, meta, new_value, old_value);
                },
            });
        }
        _fire_change(_row.owner, _m, _old, _value);
        return true;
    };

    static _apply = function(_owner, _m, _value) {
        if (is_callable(_m.set_fn)) _m.set_fn(_owner, _m.field, _value);
        else gmforms_put_value(_owner, _m.field, _value);
        // A nested write (e.g. margin.l) inside a bound control: let the control re-lay itself out.
        var _root = _m.root;
        if (_owner != _root && is_struct(_root) && is_callable(_root[$ "invalidate_layout"])) _root.set({});
        _rows_dirty = true;
    };

    static _fire_change = function(_owner, _m, _old, _new) {
        if (is_callable(on_change)) on_change(self, _m.name, _old, _new, _owner);
    };

    // -----------------------------------------------------------------------
    // Geometry (local coordinates)
    // -----------------------------------------------------------------------

    static _content_h = function() { return array_length(_rows) * row_height; };
    static _sb_visible = function() { return _content_h() > height; };
    static _value_w = function() { return max(0, width - name_width - (_sb_visible() ? _sb_w : 0)); };

    static _clamp_scroll = function() {
        _scroll_y = clamp(_scroll_y, 0, max(0, _content_h() - height));
    };

    static _row_at = function(_ly) {
        var _i = floor((_ly + _scroll_y) / row_height);
        return (_i >= 0 && _i < array_length(_rows)) ? _i : -1;
    };

    // -----------------------------------------------------------------------
    // Popup editors (M5): enum / sprite dropdowns and the colour popup
    // -----------------------------------------------------------------------

    static _value_rect_y = function(_i) { return _i * row_height - _scroll_y; };

    static _open_enum_dropdown = function(_i) {
        var _grid = self;   // inside a struct literal, self is the new struct
        var _row = _rows[_i];
        var _src = {
            grid: _grid,
            row: _row,
            _dd_count: function() { return array_length(row.meta.values); },
            _dd_selected: function() { return grid._enum_index(row.meta, grid._row_value(row)); },
            _dd_pick: function(_k) { grid._commit(row, row.meta.values[_k]); },
            _dd_draw: function(_k, _x, _y, _w, _h) {
                var _m = row.meta;
                var _label = (is_array(_m.labels) && _k < array_length(_m.labels)) ? _m.labels[_k] : _m.values[_k];
                gmforms_draw_text_in(_x, _y, _w, _h, string(_label), gmforms_theme().text, fa_left, fa_middle, 4);
            },
        };
        gmforms_dropdown_open(self, _src, name_width + 1, _value_rect_y(_i), _value_w() - 1, row_height, 20, 10);
    };

    static _open_sprite_dropdown = function(_i) {
        var _grid = self;
        var _row = _rows[_i];
        var _list = array_concat([-1], is_array(_row.meta.values) ? _row.meta.values : gmforms_sprite_list());
        var _src = {
            grid: _grid,
            row: _row,
            list: _list,
            _dd_count: function() { return array_length(list); },
            _dd_selected: function() { return array_get_index(list, grid._row_value(row)); },
            _dd_pick: function(_k) { grid._commit(row, list[_k]); },
            _dd_draw: function(_k, _x, _y, _w, _h) {
                gmforms_draw_sprite_fit(list[_k], _x + 3, _y + 2, _h - 4, _h - 4);
                gmforms_draw_text_in(_x + _h + 2, _y, _w - _h - 2, _h, gmforms_sprite_label(list[_k], row.meta.values, row.meta.labels),
                    gmforms_theme().text, fa_left, fa_middle, 2);
            },
        };
        gmforms_dropdown_open(self, _src, name_width + 1, _value_rect_y(_i), max(_value_w() - 1, 160), row_height, 32, 8);
    };

    /// Live preview while dragging (no undo, no on_change); one committed undo step per release.
    static _open_color_popup = function(_i) {
        var _grid = self;
        var _row = _rows[_i];
        var _src = {
            grid: _grid,
            row: _row,
            orig: _row_value(_row),
            _cp_get: function() { return grid._row_value(row) ?? c_white; },
            _cp_set: function(_c, _final) {
                if (!_final) { grid._apply(row.owner, row.meta, _c); return; }
                grid._apply(row.owner, row.meta, orig);
                grid._commit(row, _c);
                orig = _c;
            },
        };
        gmforms_color_popup_open(self, _src, name_width + 1, _value_rect_y(_i), _value_w() - 1, row_height);
    };

    static _has_spin = function(_row) {
        return _row.kind == "prop" && _is_number(_row.meta.type) && !_is_readonly(_row);
    };

    /// "add" for a resizable array row, "remove" for an item of one, else "".
    static _row_button = function(_row) {
        if (_row.kind != "prop" || readonly) return "";
        if (_row.meta.type == "array" && _row.meta.resizable && !_row.meta.readonly) return "add";
        var _p = _row.parent_row;
        if (_p != undefined && _p.meta.resizable && !_p.meta.readonly) return "remove";
        return "";
    };

    /// Local x where the value column's content ends (before the +/x button, if any).
    static _value_right = function(_row) {
        return name_width + _value_w() - ((_row_button(_row) != "") ? _spin_w : 0);
    };

    /// @func add_element(index)
    /// @desc On a resizable array row: appends meta.new_element() (or a copy of the last item) as one undo step.
    static add_element = function(_i) {
        var _row = get_row(_i);
        if (_row == undefined || _row_button(_row) != "add") return false;
        var _old = _row_value(_row);
        var _arr = is_array(_old) ? _old : [];
        var _el;
        if (is_callable(_row.meta.new_element)) _el = _row.meta.new_element();
        else if (array_length(_arr) > 0) _el = json_parse(json_stringify({ v: _arr[array_length(_arr) - 1] })).v;
        else _el = "";
        var _ok = _commit(_row, array_concat(_arr, [_el]));
        if (_ok) set_expanded(_row.path, true);
        return _ok;
    };

    /// @func remove_element(index)
    /// @desc On an item of a resizable array: removes it from the array as one undo step.
    static remove_element = function(_i) {
        var _row = get_row(_i);
        if (_row == undefined || _row_button(_row) != "remove") return false;
        var _parent = _row.parent_row;
        var _arr = array_concat([], _row.owner);
        array_delete(_arr, _row.meta.field, 1);
        return _commit(_parent, _arr);
    };

    /// Local rect of the in-place editor, or undefined when not editing.
    static _editor_rect = function() {
        if (!_editing) return undefined;
        var _i = find_row(_edit_path);
        if (_i < 0) return undefined;
        var _w = _value_right(_rows[_i]) - name_width - 1;
        if (_has_spin(_rows[_i])) _w -= _spin_w * 2;
        return { x: name_width + 1, y: _i * row_height - _scroll_y, w: max(0, _w), h: row_height };
    };

    static _place_editor = function() {
        var _r = _editor_rect();
        if (_r == undefined) return;
        _editor.left = _r.x;
        _editor.top = _r.y;
        _editor.width = _r.w;
        _editor.height = _r.h;
        _editor._sx = _sx + _r.x;
        _editor._sy = _sy + _r.y;
    };

    static _thumb = function() {
        var _ch = _content_h();
        var _h = max(16, height * height / max(1, _ch));
        var _range = max(0, _ch - height);
        var _y = (_range > 0) ? (_scroll_y / _range) * (height - _h) : 0;
        return { y: _y, h: _h, range: _range };
    };

    // -----------------------------------------------------------------------
    // Input
    // -----------------------------------------------------------------------

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        _ensure_rows();

        // double-click on a row -> on_dbl_click(sender, key, owner) (the designer's "default handler name")
        var _di = (_btn == mb_left && !(_sb_visible() && _x >= width - _sb_w)) ? _row_at(_y) : -1;
        if (_di >= 0 && _di == _last_click_row && current_time - _last_click_time < 400 && is_callable(on_dbl_click)
            && _rows[_di].kind == "prop") {
            _last_click_time = -100000;
            cancel_edit();
            select(_di);
            on_dbl_click(self, _rows[_di].meta.name, _rows[_di].owner);
            return;
        }
        _last_click_row = _di;
        _last_click_time = current_time;

        if (_editing) {
            var _er = _editor_rect();
            if (_er != undefined && _btn == mb_left
                && _x >= _er.x && _x < _er.x + _er.w && _y >= _er.y && _y < _er.y + _er.h) {
                _editor.mouse_down(_x - _er.x, _y - _er.y, _btn);
                _edit_drag = true;
                return;
            }
            commit_edit();
            _ensure_rows();
        }

        if (_btn == mb_left && _sb_visible() && _x >= width - _sb_w) {
            var _t = _thumb();
            if (_y >= _t.y && _y < _t.y + _t.h) {
                _drag_scroll = true;
                _drag_off = _y - _t.y;
            } else {
                _scroll_y += (_y < _t.y) ? -height : height;
                _clamp_scroll();
            }
            return;
        }
        if (_btn == mb_left && abs(_x - name_width) <= 3) {
            _drag_divider = true;
            return;
        }

        var _i = _row_at(_y);
        if (_i < 0) return;
        select(_i);
        var _row = _rows[_i];
        if (_row.kind == "category" || _x < name_width || _is_readonly(_row)) {
            if (_btn == mb_left && (_row.kind == "category" || _row.expandable)) toggle_expand(_i);
            return;
        }
        var _rb = _row_button(_row);
        if (_rb != "" && _btn == mb_left && _x >= _value_right(_row)) {
            if (_rb == "add") add_element(_i); else remove_element(_i);
            return;
        }
        switch (_row.meta.type) {
            case "bool":
                if (_btn == mb_left) _commit(_row, !(_row_value(_row) == true));
                break;
            case "enum":
                if (_btn == mb_left && get_form() != undefined) _open_enum_dropdown(_i);
                else _enum_step(_row, (_btn == mb_right) ? -1 : 1);
                break;
            case "color":
                // the swatch opens the colour popup; the hex text is edited in place
                if (_btn == mb_left && _x < name_width + 24 && get_form() != undefined) _open_color_popup(_i);
                else if (_btn == mb_left) begin_edit(_i);
                break;
            case "sprite":
                if (_btn == mb_left && get_form() != undefined) _open_sprite_dropdown(_i);
                else if (_btn == mb_left) begin_edit(_i);
                break;
            case "struct":
            case "array":
                if (_btn == mb_left && _row.expandable) toggle_expand(_i);
                break;
            case "int":
            case "real":
                if (_btn != mb_left) break;
                var _right = _value_right(_row);
                if (_x >= _right - _spin_w * 2) _step_value(_row, (_x >= _right - _spin_w) ? 1 : -1);
                else begin_edit(_i);
                break;
            default:
                if (_btn == mb_left) begin_edit(_i);
                break;
        }
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        var _f = get_form();
        if (_f == undefined || _f.capture != self) return;
        if (_drag_divider) {
            name_width = clamp(round(_x), _min_col, max(_min_col, width - _min_col));
        } else if (_drag_scroll) {
            var _t = _thumb();
            var _free = height - _t.h;
            _scroll_y = (_free > 0) ? ((_y - _drag_off) / _free) * _t.range : 0;
            _clamp_scroll();
        } else if (_edit_drag && _editing) {
            var _er = _editor_rect();
            if (_er != undefined) {
                _editor._caret = _editor._index_at_x(_x - _er.x);
                _editor._ensure_caret_visible();
            }
        }
    };

    static mouse_up = function(_x, _y, _btn) {
        if (is_callable(on_mouse_up)) on_mouse_up(self, _x, _y, _btn);
        _drag_divider = false;
        _drag_scroll = false;
        _edit_drag = false;
    };

    static mouse_wheel = function(_delta) {
        if (is_callable(on_mouse_wheel) && on_mouse_wheel(self, _delta) == true) return true;
        _scroll_y += _delta * row_height * 3;
        _clamp_scroll();
        return true;
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (!is_enabled()) return false;
        _ensure_rows();

        if (_editing) {
            switch (_key) {
                case vk_enter:  commit_edit(); return true;
                case vk_escape: cancel_edit(); return true;
                case vk_up:
                case vk_down:   commit_edit(); _ensure_rows(); break;   // then move the selection below
                default:        return _editor.key_down(_key);
            }
        }

        var _n = array_length(_rows);
        if (_n == 0) return false;
        var _page = max(1, floor(height / row_height) - 1);
        switch (_key) {
            case vk_up:       select((_sel < 0) ? 0 : _sel - 1); return true;
            case vk_down:     select(_sel + 1); return true;
            case vk_home:     select(0); return true;
            case vk_end:      select(_n - 1); return true;
            case vk_pageup:   select(_sel - _page); return true;
            case vk_pagedown: select(_sel + _page); return true;
            case vk_enter:    activate(_sel); return true;
            case vk_space:
                var _r = get_row(_sel);
                if (_r != undefined && _r.kind == "prop" && _r.meta.type == "bool") { activate(_sel); return true; }
                return false;
            case vk_left:
            case vk_right:
                return _key_side(_sel, (_key == vk_right) ? 1 : -1);
        }
        return false;
    };

    /// Left/Right: collapse/expand, cycle an enum, or step a number.
    static _key_side = function(_i, _dir) {
        var _row = get_row(_i);
        if (_row == undefined) return false;
        if (_row.kind == "category") { set_expanded(_row.path, _dir > 0); return true; }
        if (_row.expandable) { set_expanded(_row.path, _dir > 0); return true; }
        if (_is_readonly(_row)) return false;
        if (_row.meta.type == "enum") { _enum_step(_row, _dir); return true; }
        if (_is_number(_row.meta.type)) { _step_value(_row, _dir); return true; }
        return false;
    };

    static key_char = function(_ch) {
        if (!is_enabled()) return;
        if (_editing) { _editor.key_char(_ch); return; }
        if (_sel >= 0) begin_edit(_sel, _ch);   // typing on a selected text/number row starts an edit
    };

    static focus_lost = function() {
        commit_edit();
        if (is_callable(on_blur)) on_blur(self);
    };

    // -----------------------------------------------------------------------
    // Drawing
    // -----------------------------------------------------------------------

    static draw = function() {
        _ensure_rows();
        _clamp_scroll();
        var _th = gmforms_theme();
        var _en = is_enabled();
        gmforms_draw_rect(_sx, _sy, width, height, _th.grid_bg);

        var _n = array_length(_rows);
        if (_n == 0) {
            gmforms_draw_text_in(_sx, _sy, width, row_height, (target == undefined) ? empty_text : "(no properties)",
                _th.text_disabled, fa_left, fa_middle, _th.text_padding);
            return;
        }

        var _sb = _sb_visible();
        var _vw = _value_w();
        var _focused = is_focused();
        if (gmforms_scissor_push(_sx, _sy, width - (_sb ? _sb_w : 0), height)) {
            var _first = max(0, floor(_scroll_y / row_height));
            var _last = min(_n - 1, floor((_scroll_y + height) / row_height));
            for (var _i = _first; _i <= _last; _i++) {
                _draw_row(_i, _sx, _sy + _i * row_height - _scroll_y, _vw, _focused, _en);
            }
            if (_editing) {
                _place_editor();
                _editor.draw();
                _editor.draw_overlay();
            }
        }
        gmforms_scissor_pop();

        if (_sb) {
            var _t = _thumb();
            var _bx = _sx + width - _sb_w;
            gmforms_draw_rect(_bx, _sy, _sb_w, height, _th.scrollbar);
            gmforms_draw_rect(_bx + 2, _sy + _t.y + 2, _sb_w - 4, _t.h - 4, _th.scrollbar_thumb);
        }
    };

    static draw_overlay = function() {
        var _th = gmforms_theme();
        if (is_focused() && !_editing) gmforms_draw_frame(_sx, _sy, width, height, _th.focus, 1);
        else gmforms_draw_frame(_sx, _sy, width, height, _th.panel_border);
    };

    static _draw_row = function(_i, _x, _y, _vw, _focused, _en) {
        var _th = gmforms_theme();
        var _row = _rows[_i];
        var _rh = row_height;
        var _selc = _focused ? _th.grid_selection : _th.grid_selection_inactive;

        if (_row.kind == "category") {
            gmforms_draw_rect(_x, _y, width, _rh, (_i == _sel) ? _selc : _th.grid_category);
            _draw_expander(_x + 4, _y, _collapsed_cats[$ _row.label] != true, _th.grid_category_text);
            gmforms_draw_text_in(_x + 14, _y, width - 14, _rh, _row.label, _th.grid_category_text, fa_left, fa_middle, 2);
            return;
        }

        var _ind = 4 + _row.depth * indent;
        if (_i == _sel) gmforms_draw_rect(_x, _y, name_width, _rh, _selc);
        if (_row.expandable) _draw_expander(_x + _ind, _y, _expanded[$ _row.path] == true, _th.text);
        var _ro = !_en || _is_readonly(_row);
        var _tx = _ind + 10;
        gmforms_draw_text_in(_x + _tx, _y, name_width - _tx, _rh, _row.label,
            _ro ? _th.text_disabled : _th.text, fa_left, fa_middle, 2);

        _draw_value(_row, _x + name_width + 1, _y, _vw - 1, _rh, _ro);
        gmforms_draw_rect(_x, _y + _rh - 1, width, 1, _th.grid_line);
        gmforms_draw_rect(_x + name_width, _y, 1, _rh, _th.grid_line);
    };

    static _draw_expander = function(_x, _y, _open, _col) {
        var _cy = _y + row_height * 0.5;
        draw_set_colour(_col);
        if (_open) draw_triangle(_x, _cy - 2, _x + 8, _cy - 2, _x + 4, _cy + 3, false);
        else draw_triangle(_x + 2, _cy - 4, _x + 2, _cy + 4, _x + 7, _cy, false);
    };

    static _draw_value = function(_row, _x, _y, _w, _h, _ro) {
        var _th = gmforms_theme();
        var _tc = _ro ? _th.text_disabled : _th.text;
        var _m = _row.meta;
        var _v = _row_value(_row);
        var _pad = 4;
        var _rb = _row_button(_row);
        if (_rb != "") {
            // + (add item) / x (remove item) button at the right of the value column
            _w -= _spin_w;
            var _bx = _x + _w;
            gmforms_draw_rect(_bx, _y + 1, _spin_w, _h - 2, _th.button);
            gmforms_draw_frame(_bx, _y + 1, _spin_w, _h - 2, _th.button_border);
            var _mx = _bx + floor(_spin_w * 0.5);
            var _my = _y + floor(_h * 0.5);
            draw_set_colour(_th.text);
            if (_rb == "add") {
                gmforms_draw_rect(_mx - 3, _my, 7, 1, _th.text);
                gmforms_draw_rect(_mx, _my - 3, 1, 7, _th.text);
            } else {
                draw_line(_mx - 3, _my - 3, _mx + 3, _my + 3);
                draw_line(_mx + 3, _my - 3, _mx - 3, _my + 3);
            }
        }
        switch (_m.type) {
            case "bool":
                var _b = 12;
                var _by = _y + floor((_h - _b) * 0.5);
                gmforms_draw_rect(_x + _pad, _by, _b, _b, _th.edit_bg);
                gmforms_draw_frame(_x + _pad, _by, _b, _b, _th.button_border);
                if (_v == true) {
                    draw_set_colour(_ro ? _th.text_disabled : _th.checkbox_mark);
                    draw_line_width(_x + _pad + 2, _by + 6, _x + _pad + 5, _by + 9, 2);
                    draw_line_width(_x + _pad + 5, _by + 9, _x + _pad + 10, _by + 3, 2);
                }
                gmforms_draw_text_in(_x + _pad + _b + 2, _y, _w - _pad - _b - 2, _h, _value_text(_row), _tc, fa_left, fa_middle, 4);
                return;

            case "sprite":
                var _ts = _h - 4;
                gmforms_draw_sprite_fit(_v, _x + _pad, _y + 2, _ts, _ts);
                gmforms_draw_text_in(_x + _pad + _ts + 2, _y, _w - _pad - _ts - 2, _h, _value_text(_row), _tc, fa_left, fa_middle, 2);
                return;

            case "color":
                if (is_numeric(_v)) {
                    var _sw = 14;
                    gmforms_draw_rect(_x + _pad, _y + 4, _sw, _h - 8, _v);
                    gmforms_draw_frame(_x + _pad, _y + 4, _sw, _h - 8, _th.button_border);
                    gmforms_draw_text_in(_x + _pad + _sw + 2, _y, _w - _pad - _sw - 2, _h, _value_text(_row), _tc, fa_left, fa_middle, 4);
                } else {
                    gmforms_draw_text_in(_x, _y, _w, _h, _value_text(_row), _th.text_disabled, fa_left, fa_middle, _pad);
                }
                return;

            case "enum":
                gmforms_draw_text_in(_x, _y, _w - 14, _h, _value_text(_row), _tc, fa_left, fa_middle, _pad);
                if (!_ro) {
                    var _cx = _x + _w - 9;
                    var _cy = _y + _h * 0.5;
                    draw_set_colour(_th.text_disabled);
                    draw_triangle(_cx - 4, _cy - 2, _cx + 4, _cy - 2, _cx, _cy + 3, false);
                }
                return;

            case "int":
            case "real":
                var _spin = _has_spin(_row);
                var _tw = _spin ? (_w - _spin_w * 2) : _w;
                gmforms_draw_text_in(_x, _y, _tw, _h, _value_text(_row), _tc, fa_left, fa_middle, _pad);
                if (_spin) {
                    var _bx = _x + _w - _spin_w * 2;
                    for (var _k = 0; _k < 2; _k++) {
                        var _kx = _bx + _k * _spin_w;
                        gmforms_draw_rect(_kx, _y + 1, _spin_w, _h - 2, _th.button);
                        gmforms_draw_frame(_kx, _y + 1, _spin_w, _h - 2, _th.button_border);
                        var _mx = _kx + floor(_spin_w * 0.5);
                        var _my = _y + floor(_h * 0.5);
                        gmforms_draw_rect(_mx - 3, _my, 7, 1, _th.text);                 // minus
                        if (_k == 1) gmforms_draw_rect(_mx, _my - 3, 1, 7, _th.text);     // plus
                    }
                }
                return;
        }
        gmforms_draw_text_in(_x, _y, _w, _h, _value_text(_row), _tc, fa_left, fa_middle, _pad);
    };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// @func gmforms_infer_type(value)
/// @desc Property type the PropertyGrid uses for a value without metadata: "bool", "string", "real",
///       "struct", "array", "none" (shown read-only), or "" for values it skips (methods).
///       (is_callable() can't be used here: it is also true for numbers that are valid script indices.)
function gmforms_infer_type(_v) {
    if (is_method(_v)) return "";
    if (is_bool(_v)) return "bool";
    if (is_string(_v)) return "string";
    if (is_array(_v)) return "array";
    if (is_struct(_v)) return "struct";
    if (is_numeric(_v)) return "real";
    return "none";
}

/// @func gmforms_control_grid_meta(control)
/// @desc PropertyGrid metadata for a control's published properties (events skipped), grouped into
///       categories and written through control.set() so layout updates.
/// @returns {Array}
function gmforms_control_grid_meta(_ctrl) {
    var _list = _ctrl.published;
    var _order = [];
    var _map = {};
    var _n = array_length(_list);
    for (var _i = 0; _i < _n; _i++) {
        var _p = _list[_i];
        if (!struct_exists(_map, _p.name)) array_push(_order, _p.name);
        _map[$ _p.name] = _p;
    }
    var _out = [{ name: "name", type: "string", category: "Identity", set_fn: __gmforms_grid_set_control }];
    var _on = array_length(_order);
    for (var _i = 0; _i < _on; _i++) {
        var _p = _map[$ _order[_i]];
        if (_p.type == "event") continue;
        var _e = { name: _p.name, type: _p.type, set_fn: __gmforms_grid_set_control };
        switch (_p.name) {
            case "left": case "top": case "width": case "height": case "align": case "anchors":
            case "margin": case "padding": case "min_width": case "min_height": case "max_width": case "max_height":
                _e.category = "Layout";
                break;
            case "visible": case "enabled": case "tab_stop": case "tab_order": case "hint":
                _e.category = "Behavior";
                break;
            default:
                _e.category = "Properties";
                break;
        }
        if (struct_exists(_p, "values")) _e.values = _p.values;
        if (_p.type == "menus") {
            // menu bar items: an editable list (+ / x), each item a struct with a nested submenu list
            var _ml = gmforms_menu_list_meta(_p.name);
            _e.type = "array";
            _e.resizable = true;
            _e.label_field = _ml.label_field;
            _e.element = _ml.element;
            _e.new_element = _ml.new_element;
        }
        array_push(_out, _e);
    }
    return _out;
}

function __gmforms_grid_set_control(_owner, _field, _value) {
    var _s = {};
    _s[$ _field] = _value;
    _owner.set(_s);
}

/// @func gmforms_format_number(value)
/// @desc Short display text for a number: no trailing zeros, up to 6 decimals.
function gmforms_format_number(_v) {
    if (!is_numeric(_v)) return string(_v);
    if (frac(_v) == 0) return string(_v);
    var _s = string_trim(string_format(_v, 0, 6));
    while (string_length(_s) > 1 && string_char_at(_s, string_length(_s)) == "0") _s = string_delete(_s, string_length(_s), 1);
    if (string_char_at(_s, string_length(_s)) == ".") _s = string_delete(_s, string_length(_s), 1);
    return _s;
}

/// @func gmforms_color_to_hex(colour)
/// @desc GameMaker colour -> "#RRGGBB".
function gmforms_color_to_hex(_c) {
    return "#" + __gmforms_hex2(colour_get_red(_c)) + __gmforms_hex2(colour_get_green(_c)) + __gmforms_hex2(colour_get_blue(_c));
}

/// @func gmforms_color_from_hex(text)
/// @desc "#RRGGBB" or "RRGGBB" -> GameMaker colour, or undefined if the text isn't valid.
function gmforms_color_from_hex(_s) {
    _s = string_upper(string_trim(_s));
    if (string_char_at(_s, 1) == "#") _s = string_delete(_s, 1, 1);
    if (string_length(_s) != 6) return undefined;
    var _v = 0;
    for (var _i = 1; _i <= 6; _i++) {
        var _d = string_pos(string_char_at(_s, _i), "0123456789ABCDEF");
        if (_d == 0) return undefined;
        _v = _v * 16 + (_d - 1);
    }
    return make_colour_rgb((_v >> 16) & 255, (_v >> 8) & 255, _v & 255);
}

function __gmforms_hex2(_v) {
    _v = clamp(floor(_v), 0, 255);
    return string_char_at("0123456789ABCDEF", (_v div 16) + 1) + string_char_at("0123456789ABCDEF", (_v mod 16) + 1);
}

function __gmforms_parse_number(_s) {
    _s = string_trim(_s);
    if (_s == "") return undefined;
    try {
        return real(_s);
    } catch (_e) {
        return undefined;
    }
}

function __gmforms_join(_arr, _sep) {
    var _s = "";
    var _n = array_length(_arr);
    for (var _i = 0; _i < _n; _i++) _s += ((_i > 0) ? _sep : "") + string(_arr[_i]);
    return _s;
}

/// Name of a sprite/font asset, or the fallback text when the value isn't one.
function __gmforms_asset_name(_v, _kind, _fallback) {
    if (_v == undefined || (is_numeric(_v) && _v < 0)) return _fallback;
    if (_kind == asset_sprite) return sprite_exists(_v) ? sprite_get_name(_v) : _fallback;
    return font_exists(_v) ? font_get_name(_v) : _fallback;
}
