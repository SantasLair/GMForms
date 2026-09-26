/// GMForms — serialization: registry-driven JSON load/save and event-name binding (plan section 5, 7, 8).
///
/// Only properties listed in a class's `published` array are ever read or written, so tree/input
/// fields (children, hover, capture, _*, ...) can never leak into a form file.
///
/// Anchored controls (align "none") drift away from their design rect as the window is resized
/// (plan / CLAUDE.md "Anchored controls" note). Serializing must use the captured design values
/// (_anc) once they exist, not the control's current left/top/width/height.

#macro GMF_FORM_FORMAT_VERSION 1

/// @func gmforms_form_to_json(form)
/// @desc Serializes a form (or any control tree) to a pretty-printed JSON string.
/// @param {Struct} form
/// @returns {String}
function gmforms_form_to_json(_form) {
    var _data = {
        format: "gmforms",
        version: GMF_FORM_FORMAT_VERSION,
        root: gmforms_control_to_struct(_form),
    };
    return json_stringify(_data, true);
}

/// @func gmforms_save_form(filename, form)
/// @desc Writes a form to a JSON file (see plan section 15: Included Files / datafiles).
/// @param {String} filename
/// @param {Struct} form
function gmforms_save_form(_filename, _form) {
    var _json = gmforms_form_to_json(_form);
    var _buf = buffer_create(string_byte_length(_json) + 1, buffer_grow, 1);
    buffer_write(_buf, buffer_string, _json);
    buffer_save(_buf, _filename);
    buffer_delete(_buf);
}

/// @func gmforms_load_form(filename, [handlers])
/// @desc Loads a form previously written by gmforms_save_form(). See gmforms_load_form_json() for
///       the handlers parameter and warning behaviour.
/// @param {String} filename
/// @param {Struct} [handlers]
/// @returns {Struct|Undefined} The root control, or undefined if the file is missing or invalid.
function gmforms_load_form(_filename, _handlers = undefined) {
    if (!file_exists(_filename)) {
        gmforms_log("load_form: file not found: " + string(_filename));
        return undefined;
    }
    var _buf = buffer_load(_filename);
    if (_buf < 0) {
        gmforms_log("load_form: could not read file: " + string(_filename));
        return undefined;
    }
    var _text = buffer_read(_buf, buffer_string);
    buffer_delete(_buf);
    return gmforms_load_form_json(_text, _handlers);
}

/// @func gmforms_load_form_json(json_text, [handlers])
/// @desc Parses a gmforms JSON document and builds a control tree from the registry.
///       Event properties ("onClick": "btnSave_Click") are resolved against `handlers` with
///       struct_get(); a name that isn't found on `handlers` logs one warning per distinct
///       missing name and leaves the control's handler unset (the name is kept for re-saving).
///       An unknown `class` logs a warning and that node (and its children) is skipped.
/// @param {String} json_text
/// @param {Struct} [handlers]
/// @returns {Struct|Undefined} The root control, or undefined if the document is invalid.
function gmforms_load_form_json(_json_text, _handlers = undefined) {
    var _data;
    try {
        _data = json_parse(_json_text);
    } catch (_e) {
        // The exception's shape isn't guaranteed here, so don't assume it has a .message field.
        var _reason = (is_struct(_e) && struct_exists(_e, "message")) ? _e[$ "message"] : string(_e);
        gmforms_log("load_form: invalid JSON (" + string(_reason) + ")");
        return undefined;
    }
    if (!is_struct(_data) || _data[$ "format"] != "gmforms") {
        gmforms_log("load_form: not a gmforms document");
        return undefined;
    }
    var _version = _data[$ "version"] ?? 1;
    if (_version != GMF_FORM_FORMAT_VERSION) {
        gmforms_log("load_form: unsupported format version " + string(_version));
        return undefined;
    }
    if (!struct_exists(_data, "root")) {
        gmforms_log("load_form: document has no root");
        return undefined;
    }
    return __gmforms_build_control(_data.root, _handlers, {});
}

// ---------------------------------------------------------------------------
// Save
// ---------------------------------------------------------------------------

/// @func gmforms_control_to_struct(control)
/// @desc Serializes one control (and its children) to a plain struct, ready for json_stringify().
///       Only non-default published properties are written.
/// @param {Struct} control
/// @returns {Struct}
function gmforms_control_to_struct(_ctrl) {
    var _out = { class: _ctrl.class_name };
    if (_ctrl.name != "") _out.name = _ctrl.name;

    var _props = __gmforms_effective_published(_ctrl);
    var _names = struct_get_names(_props);
    var _n = array_length(_names);
    for (var _i = 0; _i < _n; _i++) {
        var _key = _names[_i];
        var _meta = _props[$ _key];

        if (_meta.type == "event") {
            var _field = __gmforms_event_field(_key);
            var _ev_name = _ctrl._ev_names[$ _field];
            if (_ev_name != undefined) _out[$ _key] = _ev_name;
            continue;
        }

        var _field = _meta[$ "field"] ?? _key;
        var _val = __gmforms_geometry_value(_ctrl, _field);
        if (!gmforms_value_equals(_val, _meta.default_value)) {
            _out[$ _key] = _val;
        }
    }

    var _kids = _ctrl.children;
    var _kn = array_length(_kids);
    if (_kn > 0) {
        var _arr = array_create(_kn);
        for (var _i = 0; _i < _kn; _i++) _arr[_i] = gmforms_control_to_struct(_kids[_i]);
        _out.children = _arr;
    }
    return _out;
}

/// left/top/width/height on an anchored (align "none") control drift away from their design value
/// as the window is resized. Once anchors have been captured, save the design rect (_anc), not the
/// live one, so re-loading a file saved after a resize reproduces the original design (CLAUDE.md
/// "Anchored controls" note).
function __gmforms_geometry_value(_ctrl, _field) {
    if (_ctrl.align == "none" && _ctrl._anchor_captured) {
        switch (_field) {
            case "left":   return _ctrl._anc.l;
            case "top":    return _ctrl._anc.t;
            case "width":  return _ctrl._anc.w;
            case "height": return _ctrl._anc.h;
        }
    }
    return _ctrl[$ _field];
}

/// Flattens a control's `published` array to name -> metadata, last entry for a name wins. This is
/// how a subclass overrides a base default (e.g. GMF_Button changing "width"'s default to 80).
function __gmforms_effective_published(_ctrl) {
    var _list = _ctrl.published;
    var _n = array_length(_list);
    var _order = [];
    var _map = {};
    for (var _i = 0; _i < _n; _i++) {
        var _meta = _list[_i];
        if (!struct_exists(_map, _meta.name)) array_push(_order, _meta.name);
        _map[$ _meta.name] = _meta;
    }
    var _out = {};
    var _on = array_length(_order);
    for (var _i = 0; _i < _on; _i++) _out[$ _order[_i]] = _map[$ _order[_i]];
    return _out;
}

// ---------------------------------------------------------------------------
// Load
// ---------------------------------------------------------------------------

function __gmforms_build_control(_node, _handlers, _warned) {
    var _cls = _node[$ "class"];
    var _registry = gmforms_init().registry;
    if (!struct_exists(_registry, _cls)) {
        gmforms_log("load_form: unknown class '" + string(_cls) + "'" + (struct_exists(_node, "name") ? (" (name '" + string(_node.name) + "')") : ""));
        return undefined;
    }

    var _ctor = _registry[$ _cls];
    var _ctrl = new _ctor();
    if (struct_exists(_node, "name")) _ctrl.name = _node.name;

    var _map = __gmforms_effective_published(_ctrl);
    var _keys = struct_get_names(_node);
    var _kn = array_length(_keys);
    for (var _i = 0; _i < _kn; _i++) {
        var _key = _keys[_i];
        if (_key == "class" || _key == "name" || _key == "children") continue;

        if (!struct_exists(_map, _key)) {
            gmforms_log("load_form: unknown property '" + _key + "' on " + _cls + " '" + _ctrl.name + "'");
            continue;
        }
        var _meta = _map[$ _key];
        var _raw = _node[$ _key];

        if (_meta.type == "event") {
            var _field = __gmforms_event_field(_key);
            var _handler = (is_struct(_handlers) && struct_exists(_handlers, _raw)) ? struct_get(_handlers, _raw) : undefined;
            if (_handler == undefined) {
                if (!struct_exists(_warned, _raw)) {
                    _warned[$ _raw] = true;
                    gmforms_log("load_form: missing handler '" + string(_raw) + "' for " + _key);
                }
            } else {
                _ctrl[$ _field] = _handler;
            }
            _ctrl._ev_names[$ _field] = _raw; // keep the name even if unresolved, so re-saving doesn't lose it
        } else {
            var _field = _meta[$ "field"] ?? _key;
            _ctrl[$ _field] = _raw;
        }
    }
    _ctrl._anchor_captured = false; // re-capture anchors against whatever size this tree is next laid out at
    _ctrl._layout_dirty = true;

    if (struct_exists(_node, "children")) {
        var _kids = _node.children;
        var _cn = array_length(_kids);
        for (var _i = 0; _i < _cn; _i++) {
            var _child = __gmforms_build_control(_kids[_i], _handlers, _warned);
            if (_child != undefined) _ctrl.add(_child);
        }
    }
    return _ctrl;
}

/// "onMouseDown" -> "on_mouse_down". Generic so a custom control's own "on*" published entries
/// don't need to spell out their field name.
function __gmforms_event_field(_name) {
    var _rest = string_copy(_name, 3, string_length(_name) - 2); // drop leading "on"
    var _out = "on";
    var _n = string_length(_rest);
    for (var _i = 1; _i <= _n; _i++) {
        var _ch = string_char_at(_rest, _i);
        _out += (_ch != string_lower(_ch)) ? ("_" + string_lower(_ch)) : _ch;
    }
    return _out;
}

// ---------------------------------------------------------------------------
// Deep equality, used to decide whether a property differs from its default.
// ---------------------------------------------------------------------------

/// @func gmforms_value_equals(a, b)
/// @desc Deep equality for the value types published properties can hold (primitives, arrays of
///       primitives, and flat structs like margin/padding).
function gmforms_value_equals(_a, _b) {
    if (is_array(_a) || is_array(_b)) {
        if (!is_array(_a) || !is_array(_b)) return false;
        var _n = array_length(_a);
        if (_n != array_length(_b)) return false;
        for (var _i = 0; _i < _n; _i++) {
            if (!gmforms_value_equals(_a[_i], _b[_i])) return false;
        }
        return true;
    }
    if (is_struct(_a) || is_struct(_b)) {
        if (!is_struct(_a) || !is_struct(_b)) return false;
        var _ka = struct_get_names(_a);
        if (array_length(_ka) != array_length(struct_get_names(_b))) return false;
        var _n = array_length(_ka);
        for (var _i = 0; _i < _n; _i++) {
            var _k = _ka[_i];
            if (!struct_exists(_b, _k) || !gmforms_value_equals(_a[$ _k], _b[$ _k])) return false;
        }
        return true;
    }
    return _a == _b;
}
