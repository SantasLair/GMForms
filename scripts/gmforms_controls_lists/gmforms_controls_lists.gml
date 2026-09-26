/// GMForms — list controls (M5): GMF_ListBox, GMF_TreeView, GMF_ComboBox, GMF_SpritePicker, the shared
/// GMF_ListBase, and GMF_DropDownList (the popup list used by ComboBox, SpritePicker and PropertyGrid).
///
/// Dropdown sources: anything that opens a GMF_DropDownList passes a *source* struct with
///   _dd_count()                  number of items
///   _dd_draw(i, x, y, w, h)      draws item i (selection/hover background is already drawn)
///   _dd_selected()               index to highlight when it opens (-1 = none)
///   _dd_pick(i)                  called after the list closes when item i is chosen
/// See gmforms_dropdown_open().

/// @func GMF_ListBase()
/// @desc Scrolling list of fixed-height rows with a selection, keyboard navigation and a scrollbar.
///       Subclasses override _item_count(), _item_text(i) / _draw_item(), and the optional hooks
///       _item_mouse_down() and _list_key(). Not registered: use GMF_ListBox or GMF_TreeView.
function GMF_ListBase() : GMF_Control() constructor {
    class_name = "ListBase";
    width = 160;
    height = 120;
    tab_stop = true;
    row_height = 20;
    item_index = -1;            // selected row, -1 = none
    border = true;
    on_activate = undefined;    // (sender, index) — double-click or Enter

    _scroll_y = 0;
    _hot = -1;
    _press_row = -1;
    _drag_scroll = false;
    _drag_off = 0;
    _sb_w = 10;
    _force_active = false;      // draw the selection as active even without focus (dropdown lists)
    _last_click_time = -100000;
    _last_click_index = -1;

    // ---- hooks ---------------------------------------------------------------
    static _item_count = function() { return 0; };
    static _item_text = function(_i) { return ""; };
    static _draw_item = function(_i, _x, _y, _w, _h) {
        var _th = gmforms_theme();
        gmforms_draw_text_in(_x, _y, _w, _h, _item_text(_i), is_enabled() ? _th.text : _th.text_disabled, fa_left, fa_middle, 4);
    };
    /// Return true to consume the press (e.g. a TreeView expander) before the row is selected.
    static _item_mouse_down = function(_i, _lx, _ly, _btn) { return false; };
    /// Return true to consume a key before the default navigation.
    static _list_key = function(_key) { return false; };
    static _changed = function() {
        if (is_callable(on_change)) on_change(self, item_index);
    };

    // ---- geometry --------------------------------------------------------------
    static _ins = function() { return border ? 1 : 0; };
    static _view_h = function() { return max(0, height - _ins() * 2); };
    static _content_h = function() { return _item_count() * row_height; };
    static _sb_visible = function() { return _content_h() > _view_h(); };
    static _clamp_scroll = function() { _scroll_y = clamp(_scroll_y, 0, max(0, _content_h() - _view_h())); };

    static _row_at = function(_ly) {
        var _i = floor((_ly - _ins() + _scroll_y) / row_height);
        return (_i >= 0 && _i < _item_count()) ? _i : -1;
    };

    static _thumb = function() {
        var _vh = _view_h();
        var _ch = _content_h();
        var _h = max(16, _vh * _vh / max(1, _ch));
        var _range = max(0, _ch - _vh);
        return { y: _ins() + ((_range > 0) ? (_scroll_y / _range) * (_vh - _h) : 0), h: _h, range: _range };
    };

    /// @func ensure_visible(index)
    static ensure_visible = function(_i) {
        var _top = _i * row_height;
        if (_top < _scroll_y) _scroll_y = _top;
        if (_top + row_height > _scroll_y + _view_h()) _scroll_y = _top + row_height - _view_h();
        _clamp_scroll();
    };

    /// @func set_item_index(index, [fire])
    /// @desc Selects a row (-1 clears) and scrolls it into view. Fires on_change(sender, index) if it changed.
    static set_item_index = function(_i, _fire = true) {
        var _n = _item_count();
        _i = (_n == 0) ? -1 : clamp(_i, -1, _n - 1);
        if (_i == item_index) return;
        item_index = _i;
        if (_i >= 0) ensure_visible(_i);
        if (_fire) _changed();
    };

    /// @func activate(index)
    /// @desc What double-click and Enter do. Fires on_activate(sender, index).
    static activate = function(_i) {
        if (is_callable(on_activate)) on_activate(self, _i);
    };

    // ---- input -----------------------------------------------------------------
    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        _press_row = -1;
        if (_btn == mb_left && _sb_visible() && _x >= width - _ins() - _sb_w) {
            var _t = _thumb();
            if (_y >= _t.y && _y < _t.y + _t.h) {
                _drag_scroll = true;
                _drag_off = _y - _t.y;
            } else {
                _scroll_y += (_y < _t.y) ? -_view_h() : _view_h();
                _clamp_scroll();
            }
            return;
        }
        var _i = _row_at(_y);
        if (_i < 0 || _btn == mb_middle) return;
        if (_item_mouse_down(_i, _x, _y, _btn)) return;
        _press_row = _i;
        set_item_index(_i);
        if (_btn != mb_left) return;
        if (_i == _last_click_index && current_time - _last_click_time < 400) {
            _last_click_time = -100000;
            activate(_i);
        } else {
            _last_click_time = current_time;
            _last_click_index = _i;
        }
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        var _f = get_form();
        if (_drag_scroll && _f != undefined && _f.capture == self) {
            var _t = _thumb();
            var _free = _view_h() - _t.h;
            _scroll_y = (_free > 0) ? ((_y - _drag_off - _ins()) / _free) * _t.range : 0;
            _clamp_scroll();
            return;
        }
        _hot = (_sb_visible() && _x >= width - _ins() - _sb_w) ? -1 : _row_at(_y);
    };

    static mouse_up = function(_x, _y, _btn) {
        if (is_callable(on_mouse_up)) on_mouse_up(self, _x, _y, _btn);
        _drag_scroll = false;
    };

    static mouse_leave = function() {
        _hot = -1;
        if (is_callable(on_mouse_leave)) on_mouse_leave(self);
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
        if (_list_key(_key)) return true;
        var _n = _item_count();
        if (_n == 0) return false;
        var _page = max(1, floor(_view_h() / row_height) - 1);
        switch (_key) {
            case vk_up:       set_item_index(max(0, item_index - 1)); return true;
            case vk_down:     set_item_index(item_index + 1); return true;
            case vk_home:     set_item_index(0); return true;
            case vk_end:      set_item_index(_n - 1); return true;
            case vk_pageup:   set_item_index(max(0, item_index - _page)); return true;
            case vk_pagedown: set_item_index(item_index + _page); return true;
            case vk_enter:    if (item_index >= 0) activate(item_index); return true;
        }
        return false;
    };

    // ---- drawing -----------------------------------------------------------------
    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, _th.list_bg);
        _clamp_scroll();
        var _n = _item_count();
        var _ins_px = _ins();
        var _sb = _sb_visible();
        var _w = width - _ins_px * 2 - (_sb ? _sb_w : 0);
        var _active = _force_active || is_focused();
        if (gmforms_scissor_push(_sx + _ins_px, _sy + _ins_px, _w, _view_h())) {
            var _first = max(0, floor(_scroll_y / row_height));
            var _last = min(_n - 1, floor((_scroll_y + _view_h()) / row_height));
            for (var _i = _first; _i <= _last; _i++) {
                var _x = _sx + _ins_px;
                var _y = _sy + _ins_px + _i * row_height - _scroll_y;
                if (_i == item_index) gmforms_draw_rect(_x, _y, _w, row_height, _active ? _th.grid_selection : _th.grid_selection_inactive);
                else if (_i == _hot) gmforms_draw_rect(_x, _y, _w, row_height, _th.list_hover);
                _draw_item(_i, _x, _y, _w, row_height);
            }
        }
        gmforms_scissor_pop();
        if (_sb) {
            var _t = _thumb();
            var _bx = _sx + width - _ins_px - _sb_w;
            gmforms_draw_rect(_bx, _sy + _ins_px, _sb_w, _view_h(), _th.scrollbar);
            gmforms_draw_rect(_bx + 2, _sy + _t.y + 2, _sb_w - 4, _t.h - 4, _th.scrollbar_thumb);
        }
    };

    static draw_overlay = function() {
        if (!border) return;
        var _th = gmforms_theme();
        gmforms_draw_frame(_sx, _sy, width, height, is_focused() ? _th.focus : _th.edit_border);
    };
}

/// @func GMF_ListBox()
/// @desc List of items (strings, or structs with a `text` field). on_change(sender, index),
///       on_activate(sender, index) on double-click / Enter.
function GMF_ListBox() : GMF_ListBase() constructor {
    class_name = "ListBox";
    items = [];

    static published = array_concat(gmforms_base_published(), [
        { name: "width",      type: "int",   default_value: 160 },
        { name: "height",     type: "int",   default_value: 120 },
        { name: "tab_stop",   type: "bool",  default_value: true },
        { name: "items",      type: "array", default_value: [] },
        { name: "item_index", type: "int",   default_value: -1 },
        { name: "row_height", type: "int",   default_value: 20 },
        { name: "border",     type: "bool",  default_value: true },
        { name: "onActivate", type: "event" },
    ]);

    /// @func add_item(item)
    /// @returns {Real} The new item's index.
    static add_item = function(_item) {
        array_push(items, _item);
        return array_length(items) - 1;
    };

    /// @func remove_item(index)
    static remove_item = function(_i) {
        if (_i < 0 || _i >= array_length(items)) return;
        array_delete(items, _i, 1);
        if (_i < item_index) {
            item_index--;               // same item, new index: not a selection change
        } else if (_i == item_index) {
            item_index = min(item_index, array_length(items) - 1);
            _changed();
        }
    };

    /// @func clear()
    static clear = function() {
        items = [];
        set_item_index(-1);
        _scroll_y = 0;
    };

    /// @func get_text([index])
    /// @desc Text of an item (default: the selected one), or "".
    static get_text = function(_i = item_index) {
        return (_i >= 0 && _i < array_length(items)) ? _item_text(_i) : "";
    };

    static _item_count = function() { return array_length(items); };
    static _item_text = function(_i) {
        var _it = items[_i];
        return is_struct(_it) ? string(_it[$ "text"] ?? "") : string(_it);
    };
}

/// @func GMF_TreeView()
/// @desc Expandable tree. A node is { text, nodes: [], expanded, data }. Only the rows that are
///       visible on screen are drawn. on_change(sender, node), on_activate(sender, node),
///       on_expand(sender, node, expanded).
function GMF_TreeView() : GMF_ListBase() constructor {
    class_name = "TreeView";
    nodes = [];                 // root nodes
    indent = 16;
    selected_node = undefined;
    on_expand = undefined;      // (sender, node, expanded)
    _rows = [];                 // flattened visible rows: { node, depth, parent }
    _rows_dirty = true;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",      type: "int",   default_value: 160 },
        { name: "height",     type: "int",   default_value: 120 },
        { name: "tab_stop",   type: "bool",  default_value: true },
        { name: "nodes",      type: "array", default_value: [] },
        { name: "indent",     type: "int",   default_value: 16 },
        { name: "row_height", type: "int",   default_value: 20 },
        { name: "border",     type: "bool",  default_value: true },
        { name: "onActivate", type: "event" },
        { name: "onExpand",   type: "event" },
    ]);

    /// @func add_node(parent, text, [data])
    /// @desc Adds a node under parent (undefined = a root node). Returns the node.
    static add_node = function(_parent, _text, _data = undefined) {
        var _node = { text: _text, nodes: [], expanded: false, data: _data };
        array_push((_parent == undefined) ? nodes : _parent.nodes, _node);
        _rows_dirty = true;
        return _node;
    };

    /// @func remove_node(node)
    /// @desc Removes a node and its subtree. Clears the selection if it was inside.
    static remove_node = function(_node) {
        if (selected_node != undefined && (selected_node == _node || _contains(_node, selected_node))) {
            selected_node = undefined;
            item_index = -1;
            _changed_node();
        }
        _remove_from(nodes, _node);
        _rows_dirty = true;
    };

    static _remove_from = function(_list, _node) {
        var _i = array_get_index(_list, _node);
        if (_i >= 0) { array_delete(_list, _i, 1); return true; }
        var _n = array_length(_list);
        for (var _k = 0; _k < _n; _k++) {
            if (is_array(_list[_k][$ "nodes"]) && _remove_from(_list[_k].nodes, _node)) return true;
        }
        return false;
    };

    static _contains = function(_root, _node) {
        var _kids = _root[$ "nodes"];
        if (!is_array(_kids)) return false;
        var _n = array_length(_kids);
        for (var _i = 0; _i < _n; _i++) if (_kids[_i] == _node || _contains(_kids[_i], _node)) return true;
        return false;
    };

    /// @func clear()
    static clear = function() {
        nodes = [];
        selected_node = undefined;
        item_index = -1;
        _scroll_y = 0;
        _rows_dirty = true;
    };

    /// @func refresh()
    /// @desc Call after changing nodes directly (text/children) so the rows are rebuilt.
    static refresh = function() { _rows_dirty = true; };

    /// @func node_parent(node)
    /// @desc Parent node, or undefined for a root (or unknown) node.
    static node_parent = function(_node) { return _find_parent(nodes, undefined, _node); };

    static _find_parent = function(_list, _parent, _node) {
        var _n = array_length(_list);
        for (var _i = 0; _i < _n; _i++) {
            var _c = _list[_i];
            if (_c == _node) return _parent;
            if (is_array(_c[$ "nodes"])) {
                var _r = _find_parent(_c.nodes, _c, _node);
                if (_r != undefined) return _r;
            }
        }
        return undefined;
    };

    static _has_children = function(_node) {
        return is_array(_node[$ "nodes"]) && array_length(_node.nodes) > 0;
    };

    /// @func set_expanded(node, expanded)
    static set_expanded = function(_node, _open) {
        if ((_node[$ "expanded"] == true) == _open) return;
        _node.expanded = _open;
        _rows_dirty = true;
        if (is_callable(on_expand)) on_expand(self, _node, _open);
    };

    /// @func expand_all([expanded])
    static expand_all = function(_open = true) {
        _expand_list(nodes, _open);
        _rows_dirty = true;
    };

    static _expand_list = function(_list, _open) {
        var _n = array_length(_list);
        for (var _i = 0; _i < _n; _i++) {
            if (!_has_children(_list[_i])) continue;
            _list[_i].expanded = _open;
            _expand_list(_list[_i].nodes, _open);
        }
    };

    /// @func select_node(node, [fire])
    /// @desc Selects a node, expanding its ancestors so it is visible.
    static select_node = function(_node, _fire = true) {
        if (_node == undefined) { set_item_index(-1, _fire); return; }
        var _p = node_parent(_node);
        while (_p != undefined) {
            if (_p[$ "expanded"] != true) set_expanded(_p, true);
            _p = node_parent(_p);
        }
        _ensure_rows();
        var _n = array_length(_rows);
        for (var _i = 0; _i < _n; _i++) {
            if (_rows[_i].node == _node) { set_item_index(_i, _fire); return; }
        }
    };

    /// @func get_row_node(index)
    static get_row_node = function(_i) {
        _ensure_rows();
        return (_i >= 0 && _i < array_length(_rows)) ? _rows[_i].node : undefined;
    };

    static _ensure_rows = function() {
        if (!_rows_dirty) return;
        _rows_dirty = false;
        _rows = [];
        _flatten(nodes, 0, undefined);
        item_index = -1;
        var _n = array_length(_rows);
        for (var _i = 0; _i < _n; _i++) if (_rows[_i].node == selected_node) { item_index = _i; break; }
        _clamp_scroll();
    };

    static _flatten = function(_list, _depth, _parent) {
        var _n = array_length(_list);
        for (var _i = 0; _i < _n; _i++) {
            var _node = _list[_i];
            array_push(_rows, { node: _node, depth: _depth, parent: _parent });
            if (_node[$ "expanded"] == true && _has_children(_node)) _flatten(_node.nodes, _depth + 1, _node);
        }
    };

    static _item_count = function() { _ensure_rows(); return array_length(_rows); };
    static _item_text = function(_i) { return string(_rows[_i].node[$ "text"] ?? ""); };

    static _expander_x = function(_depth) { return _ins() + 4 + _depth * indent; };

    static _draw_item = function(_i, _x, _y, _w, _h) {
        var _th = gmforms_theme();
        var _row = _rows[_i];
        var _ex = _sx + _expander_x(_row.depth);
        if (_has_children(_row.node)) {
            var _cy = _y + _h * 0.5;
            draw_set_colour(_th.text_disabled);
            if (_row.node[$ "expanded"] == true) draw_triangle(_ex, _cy - 2, _ex + 8, _cy - 2, _ex + 4, _cy + 3, false);
            else draw_triangle(_ex + 2, _cy - 4, _ex + 2, _cy + 4, _ex + 7, _cy, false);
        }
        var _tx = _ex + 12;
        gmforms_draw_text_in(_tx, _y, _x + _w - _tx, _h, _item_text(_i),
            is_enabled() ? _th.text : _th.text_disabled, fa_left, fa_middle, 2);
    };

    static _item_mouse_down = function(_i, _lx, _ly, _btn) {
        var _row = _rows[_i];
        var _ex = _expander_x(_row.depth);
        if (_btn == mb_left && _has_children(_row.node) && _lx >= _ex - 3 && _lx < _ex + 11) {
            set_expanded(_row.node, _row.node[$ "expanded"] != true);
            return true;
        }
        return false;
    };

    static _changed = function() {
        _ensure_rows();
        selected_node = (item_index >= 0) ? _rows[item_index].node : undefined;
        _changed_node();
    };

    static _changed_node = function() {
        if (is_callable(on_change)) on_change(self, selected_node);
    };

    /// Double-click / Enter: toggles a node with children, then fires on_activate(sender, node).
    static activate = function(_i) {
        var _node = get_row_node(_i);
        if (_node == undefined) return;
        if (_has_children(_node)) set_expanded(_node, _node[$ "expanded"] != true);
        if (is_callable(on_activate)) on_activate(self, _node);
    };

    /// Left collapses (or moves to the parent); Right expands (or moves to the first child).
    static _list_key = function(_key) {
        if (_key != vk_left && _key != vk_right) return false;
        var _node = get_row_node(item_index);
        if (_node == undefined) return true;
        var _open = _node[$ "expanded"] == true;
        if (_key == vk_left) {
            if (_open && _has_children(_node)) set_expanded(_node, false);
            else {
                var _p = _rows[item_index].parent;
                if (_p != undefined) select_node(_p);
            }
        } else if (_has_children(_node)) {
            if (!_open) set_expanded(_node, true);
            else select_node(_node.nodes[0]);
        }
        return true;
    };
}

/// @func GMF_DropDownList()
/// @desc Popup list opened by gmforms_dropdown_open(). Hover highlights, click or Enter picks, Escape
///       or a click outside closes (handled by the form's popup layer).
function GMF_DropDownList() : GMF_ListBase() constructor {
    class_name = "DropDownList";
    source = undefined;
    tab_stop = false;
    _force_active = true;

    static _item_count = function() { return (source == undefined) ? 0 : source._dd_count(); };
    static _draw_item = function(_i, _x, _y, _w, _h) { source._dd_draw(_i, _x, _y, _w, _h); };
    static _changed = function() {};

    static mouse_move = function(_x, _y) {
        gmforms_inherited(self, GMF_ListBase, "mouse_move")(_x, _y);
        if (_hot >= 0) item_index = _hot;
    };

    static click = function() {
        if (_press_row >= 0) _pick(item_index);
    };

    static activate = function(_i) { _pick(_i); };

    static _pick = function(_i) {
        var _src = source;
        var _f = get_form();
        if (_f != undefined) _f.close_popup(self);
        if (_i >= 0 && _src != undefined) _src._dd_pick(_i);
    };
}

/// @func gmforms_dropdown_open(owner, source, lx, ly, w, h, [row_height], [max_rows])
/// @desc Opens a GMF_DropDownList just below the owner-local rect (lx, ly, w, h), or above it when
///       there is no room below. See the top of this script for what `source` must provide.
/// @returns {Struct|Undefined} The list, or undefined if owner isn't in a form.
function gmforms_dropdown_open(_owner, _source, _lx, _ly, _w, _h, _row_h = 20, _max_rows = 8) {
    var _f = _owner.get_form();
    if (_f == undefined) {
        gmforms_log("dropdown: owner is not in a form");
        return undefined;
    }
    var _list = new GMF_DropDownList();
    _list.source = _source;
    _list.row_height = _row_h;
    var _n = _source._dd_count();
    _list.width = max(_w, 40);
    _list.height = max(1, min(_n, _max_rows)) * _row_h + 2;
    var _x = _owner._sx - _f._sx + _lx;
    var _top = _owner._sy - _f._sy + _ly;
    var _y = _top + _h;
    if (_y + _list.height > _f.height && _top - _list.height >= 0) _y = _top - _list.height;
    _list.item_index = _source._dd_selected();
    _f.show_popup(_list, _x, _y, _owner);
    if (_list.item_index >= 0) _list.ensure_visible(_list.item_index);
    return _list;
}

/// @func GMF_ComboBox()
/// @desc Drop-down list (not editable). Click, Enter or Space opens it; Up/Down change the selection
///       while closed. on_change(sender, index).
function GMF_ComboBox() : GMF_Control() constructor {
    class_name = "ComboBox";
    width = 140;
    height = 24;
    tab_stop = true;
    items = [];                 // strings, or structs with a `text` field
    item_index = -1;
    dropdown_rows = 8;
    row_height = 20;            // dropdown row height
    _dropdown = undefined;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",         type: "int",   default_value: 140 },
        { name: "height",        type: "int",   default_value: 24 },
        { name: "tab_stop",      type: "bool",  default_value: true },
        { name: "items",         type: "array", default_value: [] },
        { name: "item_index",    type: "int",   default_value: -1 },
        { name: "dropdown_rows", type: "int",   default_value: 8 },
    ]);

    /// @func get_text()
    /// @desc Text of the selected item, or "".
    static get_text = function() {
        return (item_index >= 0 && item_index < _dd_count()) ? _item_text(item_index) : "";
    };

    /// @func set_item_index(index, [fire])
    static set_item_index = function(_i, _fire = true) {
        var _n = _dd_count();
        _i = (_n == 0) ? -1 : clamp(_i, -1, _n - 1);
        if (_i == item_index) return;
        item_index = _i;
        if (_fire && is_callable(on_change)) on_change(self, item_index);
    };

    /// @func is_dropped_down()
    static is_dropped_down = function() {
        var _f = get_form();
        return _f != undefined && _f.is_popup_open(_dropdown);
    };

    /// @func drop_down()
    static drop_down = function() {
        if (!is_enabled() || is_dropped_down()) return;
        _dropdown = gmforms_dropdown_open(self, self, 0, 0, width, height, row_height, dropdown_rows);
    };

    /// @func close_up()
    static close_up = function() {
        var _f = get_form();
        if (_f != undefined && _dropdown != undefined) _f.close_popup(_dropdown);
    };

    static _item_text = function(_i) {
        var _it = items[_i];
        return is_struct(_it) ? string(_it[$ "text"] ?? "") : string(_it);
    };

    // dropdown source
    static _dd_count = function() { return array_length(items); };
    static _dd_selected = function() { return item_index; };
    static _dd_pick = function(_i) { set_item_index(_i); };
    static _dd_draw = function(_i, _x, _y, _w, _h) {
        gmforms_draw_text_in(_x, _y, _w, _h, _item_text(_i), gmforms_theme().text, fa_left, fa_middle, 4);
    };

    static click = function() {
        if (is_dropped_down()) close_up(); else drop_down();
        if (is_callable(on_click)) on_click(self);
    };

    static key_down = function(_key) {
        if (is_callable(on_key_down) && on_key_down(self, _key) == true) return true;
        if (!is_enabled()) return false;
        switch (_key) {
            case vk_up:    set_item_index(max(0, _dd_selected() - 1)); return true;
            case vk_down:  set_item_index(_dd_selected() + 1); return true;
            case vk_home:  set_item_index(0); return true;
            case vk_end:   set_item_index(_dd_count() - 1); return true;
            case vk_enter:
            case vk_space: drop_down(); return true;
        }
        return false;
    };

    /// Draws the current value inside the box. Overridden by GMF_SpritePicker.
    static _draw_value = function(_x, _y, _w, _h, _col) {
        gmforms_draw_text_in(_x, _y, _w, _h, get_text(), _col, fa_left, fa_middle, 4);
    };

    static draw = function() {
        var _th = gmforms_theme();
        var _en = is_enabled();
        var _col = _th.button;
        if (!_en) _col = _th.button_disabled;
        else if (is_dropped_down() || is_pressed()) _col = _th.button_pressed;
        else if (is_hot()) _col = _th.button_hover;
        gmforms_draw_rect(_sx, _sy, width, height, _col);
        _draw_value(_sx, _sy, width - 18, height, _en ? _th.text : _th.text_disabled);
        var _cx = _sx + width - 10;
        var _cy = _sy + height * 0.5;
        draw_set_colour(_en ? _th.text : _th.text_disabled);
        draw_triangle(_cx - 4, _cy - 2, _cx + 4, _cy - 2, _cx, _cy + 3, false);
    };

    static draw_overlay = function() {
        var _th = gmforms_theme();
        if (is_focused()) gmforms_draw_frame(_sx, _sy, width, height, _th.focus, 2);
        else gmforms_draw_frame(_sx, _sy, width, height, _th.button_border);
    };
}

/// @func GMF_SpritePicker()
/// @desc ComboBox listing sprites with thumbnails. By default it lists every sprite in the project;
///       set `sprites` (and optionally matching `labels`) to use your own list — e.g. sprites made at
///       runtime. on_change(sender, sprite). `sprite` is -1 for "(none)".
///       `sprite` is a runtime asset reference, so it isn't published for JSON.
function GMF_SpritePicker() : GMF_ComboBox() constructor {
    class_name = "SpritePicker";
    width = 160;
    height = 28;
    row_height = 36;
    sprite = -1;
    sprites = undefined;        // undefined = all project sprites
    labels = undefined;         // optional display names, same order as `sprites`
    include_none = true;
    _list = [];

    static published = array_concat(gmforms_base_published(), [
        { name: "width",         type: "int",  default_value: 160 },
        { name: "height",        type: "int",  default_value: 28 },
        { name: "tab_stop",      type: "bool", default_value: true },
        { name: "dropdown_rows", type: "int",  default_value: 8 },
        { name: "include_none",  type: "bool", default_value: true },
    ]);

    static _refresh_list = function() {
        var _src = sprites ?? gmforms_sprite_list();
        _list = include_none ? array_concat([-1], _src) : array_concat([], _src);
    };

    /// @func set_sprite(sprite, [fire])
    static set_sprite = function(_spr, _fire = true) {
        if (_spr == sprite) return;
        sprite = _spr;
        if (_fire && is_callable(on_change)) on_change(self, sprite);
    };

    static set_item_index = function(_i, _fire = true) {
        _refresh_list();
        var _n = array_length(_list);
        if (_n == 0) return;
        set_sprite(_list[clamp(_i, 0, _n - 1)], _fire);
    };

    static get_text = function() { return gmforms_sprite_label(sprite, sprites, labels); };

    static drop_down = function() {
        if (!is_enabled() || is_dropped_down()) return;
        _refresh_list();
        _dropdown = gmforms_dropdown_open(self, self, 0, 0, max(width, 180), height, row_height, dropdown_rows);
    };

    static _dd_count = function() {
        if (array_length(_list) == 0) _refresh_list();
        return array_length(_list);
    };
    static _dd_selected = function() {
        if (array_length(_list) == 0) _refresh_list();
        return array_get_index(_list, sprite);
    };
    static _dd_pick = function(_i) { set_sprite(_list[_i]); };
    static _dd_draw = function(_i, _x, _y, _w, _h) {
        var _spr = _list[_i];
        gmforms_draw_sprite_fit(_spr, _x + 3, _y + 2, _h - 4, _h - 4);
        gmforms_draw_text_in(_x + _h + 2, _y, _w - _h - 2, _h, gmforms_sprite_label(_spr, sprites, labels),
            gmforms_theme().text, fa_left, fa_middle, 2);
    };

    static _draw_value = function(_x, _y, _w, _h, _col) {
        var _s = _h - 6;
        gmforms_draw_sprite_fit(sprite, _x + 3, _y + 3, _s, _s);
        gmforms_draw_text_in(_x + _s + 6, _y, _w - _s - 6, _h, get_text(), _col, fa_left, fa_middle, 2);
    };
}

/// @func gmforms_sprite_list()
/// @desc Every sprite asset in the project (an empty array if the runtime can't list them).
function gmforms_sprite_list() {
    try {
        return asset_get_ids(asset_sprite);
    } catch (_e) {
        return [];
    }
}

/// @func gmforms_sprite_label(sprite, [sprites], [labels])
/// @desc Display name: labels[i] if the sprite is sprites[i], else its asset name; "(none)" for -1.
function gmforms_sprite_label(_spr, _sprites = undefined, _labels = undefined) {
    if (is_array(_sprites) && is_array(_labels)) {
        var _i = array_get_index(_sprites, _spr);
        if (_i >= 0 && _i < array_length(_labels)) return string(_labels[_i]);
    }
    return __gmforms_asset_name(_spr, asset_sprite, "(none)");
}

/// @func gmforms_draw_sprite_fit(sprite, x, y, w, h)
/// @desc Draws frame 0 of a sprite scaled to fit (and centred in) the rect. Does nothing for -1.
function gmforms_draw_sprite_fit(_spr, _x, _y, _w, _h) {
    if (_spr == undefined || (is_numeric(_spr) && _spr < 0) || !sprite_exists(_spr)) return;
    var _sw = sprite_get_width(_spr);
    var _sh = sprite_get_height(_spr);
    if (_sw <= 0 || _sh <= 0) return;
    var _sc = min(_w / _sw, _h / _sh);
    if (_sc > 1) _sc = floor(_sc);          // whole-number upscaling keeps pixel art crisp
    var _dx = _x + (_w - _sw * _sc) * 0.5 + sprite_get_xoffset(_spr) * _sc;
    var _dy = _y + (_h - _sh * _sc) * 0.5 + sprite_get_yoffset(_spr) * _sc;
    draw_sprite_ext(_spr, 0, _dx, _dy, _sc, _sc, 0, c_white, draw_get_alpha());
}
