/// GMForms — menus (M5): GMF_MenuBar, GMF_PopupMenu (context menus and submenus), menu item helpers.
///
/// A menu item is a plain struct:
///   { caption, on_click, shortcut, items, enabled, checked, visible, separator, data }
/// Build them with gmforms_menu_item(), gmforms_menu_separator() and gmforms_submenu().
///   on_click(sender, item)   sender = the GMF_MenuBar or GMF_PopupMenu that owns the menu
///   shortcut                 display text *and* key binding, e.g. "Ctrl+S", "Ctrl+Shift+Z", "F5", "Del"
///                            (a GMF_MenuBar handles its items' shortcuts through GMF_Form.dispatch_shortcut)
///   alt_shortcut             optional second binding, not displayed (e.g. Ctrl+Shift+Z next to Ctrl+Y)
///   items                    array of items = a submenu
///
/// Menus are code-only for now: item structs hold functions, so they are not serialized.

/// @func gmforms_menu_item(caption, [on_click], [props])
/// @desc A menu item. props can set shortcut, enabled, checked, visible, data, items.
function gmforms_menu_item(_caption, _on_click = undefined, _props = undefined) {
    var _it = {
        caption: _caption,
        on_click: _on_click,
        shortcut: "",
        items: undefined,
        enabled: true,
        checked: false,
        visible: true,
        separator: false,
        data: undefined,
    };
    if (is_struct(_props)) {
        var _keys = struct_get_names(_props);
        for (var _i = 0; _i < array_length(_keys); _i++) _it[$ _keys[_i]] = _props[$ _keys[_i]];
    }
    return _it;
}

/// @func gmforms_menu_separator()
function gmforms_menu_separator() {
    return gmforms_menu_item("-", undefined, { separator: true });
}

/// @func gmforms_submenu(caption, items, [props])
function gmforms_submenu(_caption, _items, _props = undefined) {
    var _it = gmforms_menu_item(_caption, undefined, _props);
    _it.items = _items;
    return _it;
}

/// @func gmforms_parse_shortcut(text)
/// @desc "Ctrl+Shift+S" -> { key, ctrl, shift, alt }, or undefined if it can't be parsed.
function gmforms_parse_shortcut(_text) {
    if (!is_string(_text) || _text == "") return undefined;
    var _parts = string_split(_text, "+", true);
    var _n = array_length(_parts);
    if (_n == 0) return undefined;
    var _sc = { key: -1, ctrl: false, shift: false, alt: false };
    for (var _i = 0; _i < _n - 1; _i++) {
        switch (string_lower(string_trim(_parts[_i]))) {
            case "ctrl": case "control": _sc.ctrl = true; break;
            case "shift": _sc.shift = true; break;
            case "alt": _sc.alt = true; break;
            default: return undefined;
        }
    }
    var _k = string_upper(string_trim(_parts[_n - 1]));
    if (string_length(_k) == 1) _sc.key = ord(_k);
    else if (string_char_at(_k, 1) == "F" && string_digits(_k) == string_delete(_k, 1, 1)) {
        var _fn = real(string_delete(_k, 1, 1));
        if (_fn >= 1 && _fn <= 12) _sc.key = vk_f1 + _fn - 1;
    } else {
        switch (_k) {
            case "DEL": case "DELETE": _sc.key = vk_delete; break;
            case "INS": case "INSERT": _sc.key = vk_insert; break;
            case "ENTER": case "RETURN": _sc.key = vk_enter; break;
            case "ESC": case "ESCAPE": _sc.key = vk_escape; break;
            case "SPACE": _sc.key = vk_space; break;
            case "TAB": _sc.key = vk_tab; break;
            case "BACKSPACE": _sc.key = vk_backspace; break;
            case "HOME": _sc.key = vk_home; break;
            case "END": _sc.key = vk_end; break;
            case "PGUP": case "PAGEUP": _sc.key = vk_pageup; break;
            case "PGDN": case "PAGEDOWN": _sc.key = vk_pagedown; break;
            case "UP": _sc.key = vk_up; break;
            case "DOWN": _sc.key = vk_down; break;
            case "LEFT": _sc.key = vk_left; break;
            case "RIGHT": _sc.key = vk_right; break;
            case "PLUS": _sc.key = ord("+"); break;
            case "MINUS": _sc.key = ord("-"); break;
        }
    }
    return (_sc.key >= 0) ? _sc : undefined;
}

/// @func gmforms_menu_find_shortcut(items, key, ctrl, shift, alt)
/// @desc Depth-first search for an enabled, visible item whose shortcut matches. Returns it or undefined.
function gmforms_menu_find_shortcut(_items, _key, _ctrl, _shift, _alt) {
    if (!is_array(_items)) return undefined;
    var _n = array_length(_items);
    for (var _i = 0; _i < _n; _i++) {
        var _it = _items[_i];
        if (_it.separator || !_it.visible || !_it.enabled) continue;
        if (is_array(_it.items)) {
            var _r = gmforms_menu_find_shortcut(_it.items, _key, _ctrl, _shift, _alt);
            if (_r != undefined) return _r;
            continue;
        }
        if (__gmforms_shortcut_matches(_it.shortcut, _key, _ctrl, _shift, _alt)
            || __gmforms_shortcut_matches(_it[$ "alt_shortcut"], _key, _ctrl, _shift, _alt)) return _it;
    }
    return undefined;
}

function __gmforms_shortcut_matches(_text, _key, _ctrl, _shift, _alt) {
    var _sc = gmforms_parse_shortcut(_text);
    return _sc != undefined && _sc.key == _key && _sc.ctrl == _ctrl && _sc.shift == _shift && _sc.alt == _alt;
}

/// @func GMF_PopupMenu()
/// @desc A popup menu. Use it as a context menu (control.popup_menu = menu, opens on right-click) or
///       open it yourself with popup(x, y). Hovering an item with `items` opens its submenu.
///       Keys while open: Up/Down, Right (open submenu / next menu-bar menu), Left (close submenu /
///       previous menu-bar menu), Enter/Space (activate); Escape is handled by the form.
function GMF_PopupMenu() : GMF_Control() constructor {
    class_name = "PopupMenu";
    items = [];
    tab_stop = false;
    popup_component = undefined;    // control that was right-clicked (context menus)
    sender = undefined;             // what on_click receives as sender; default: the root menu
    item_height = 22;
    separator_height = 7;
    _hot = -1;
    _submenu = undefined;
    _parent_menu = undefined;
    _menubar = undefined;
    _menubar_index = -1;

    /// @func popup(x, y, [component], [form])
    /// @desc Opens the menu at form-local (x, y). component is the control it is for (right-clicked).
    static popup = function(_x, _y, _component = undefined, _form = undefined) {
        popup_component = _component;
        var _f = _form ?? ((_component != undefined) ? _component.get_form() : undefined);
        if (_f == undefined) {
            gmforms_log("PopupMenu.popup: no form (pass the form or a component that is in one)");
            return;
        }
        _measure();
        _hot = -1;
        _f.show_popup(self, _x, _y, _component);
    };

    /// @func close()
    static close = function() {
        var _f = get_form();
        if (_f != undefined) _f.close_popup(self);
    };

    static _root = function() {
        var _m = self;
        while (_m._parent_menu != undefined) _m = _m._parent_menu;
        return _m;
    };

    static _measure = function() {
        var _th = gmforms_theme();
        if (_th.font != -1) draw_set_font(_th.font);
        var _cw = 40;
        var _sw = 0;
        var _h = 4;
        var _n = array_length(items);
        for (var _i = 0; _i < _n; _i++) {
            var _it = items[_i];
            if (!_it.visible) continue;
            if (_it.separator) { _h += separator_height; continue; }
            _cw = max(_cw, string_width(_it.caption));
            if (_it.shortcut != "") _sw = max(_sw, string_width(_it.shortcut));
            _h += item_height;
        }
        width = 24 + _cw + ((_sw > 0) ? 24 + _sw : 0) + 24;
        height = _h;
    };

    /// Local y of item i (hidden items have no row). Returns -1 for hidden items.
    static _item_y = function(_i) {
        if (!items[_i].visible) return -1;
        var _y = 2;
        for (var _k = 0; _k < _i; _k++) {
            var _it = items[_k];
            if (!_it.visible) continue;
            _y += _it.separator ? separator_height : item_height;
        }
        return _y;
    };

    static _item_at = function(_ly) {
        var _y = 2;
        var _n = array_length(items);
        for (var _i = 0; _i < _n; _i++) {
            var _it = items[_i];
            if (!_it.visible) continue;
            var _h = _it.separator ? separator_height : item_height;
            if (_ly >= _y && _ly < _y + _h) return _it.separator ? -1 : _i;
            _y += _h;
        }
        return -1;
    };

    static _selectable = function(_i) {
        var _it = items[_i];
        return _it.visible && !_it.separator && _it.enabled;
    };

    static _open_submenu = function(_i) {
        var _it = items[_i];
        if (!is_array(_it.items) || !_it.enabled) return;
        var _f = get_form();
        if (_f == undefined) return;
        if (_submenu != undefined && _f.is_popup_open(_submenu) && _submenu.items == _it.items) return;
        _close_submenu();
        var _sub = new GMF_PopupMenu();
        _sub.items = _it.items;
        _sub._parent_menu = self;
        _sub.popup_component = popup_component;
        _sub._measure();
        var _x = left + width - 2;
        if (_x + _sub.width > _f.width) _x = left - _sub.width + 2;
        _submenu = _sub;
        _f.show_popup(_sub, _x, top + _item_y(_i) - 2, self);
    };

    static _close_submenu = function() {
        if (_submenu == undefined) return;
        var _f = get_form();
        if (_f != undefined) _f.close_popup(_submenu);
        _submenu = undefined;
    };

    /// Runs an item: closes every popup, toggles nothing by itself, then calls item.on_click(sender, item).
    static _activate = function(_i) {
        var _it = items[_i];
        if (!_selectable(_i)) return;
        if (is_array(_it.items)) {
            _open_submenu(_i);
            if (_submenu != undefined) _submenu._hot = _submenu._next(-1, 1);
            return;
        }
        var _root_menu = _root();
        var _snd = _root_menu.sender ?? (_root_menu._menubar ?? _root_menu);
        var _f = get_form();
        if (_f != undefined) _f.close_popups();
        if (is_callable(_it.on_click)) _it.on_click(_snd, _it);
    };

    /// Next selectable item after i in direction dir (wraps), or -1.
    static _next = function(_i, _dir) {
        var _n = array_length(items);
        for (var _k = 1; _k <= _n; _k++) {
            var _j = ((_i + _dir * _k) mod _n + _n) mod _n;
            if (_selectable(_j)) return _j;
        }
        return -1;
    };

    static mouse_move = function(_x, _y) {
        var _i = _item_at(_y);
        if (_x < 0 || _x >= width) _i = -1;
        if (_i == _hot) return;
        _hot = _i;
        if (_i >= 0 && is_array(items[_i].items)) _open_submenu(_i);
        else if (_i >= 0) _close_submenu();
    };

    static mouse_leave = function() {
        // keep the highlight on an item whose submenu is open
        if (_submenu == undefined) _hot = -1;
    };

    static click = function() {
        if (_hot >= 0) _activate(_hot);
    };

    static key_down = function(_key) {
        switch (_key) {
            case vk_up:   _hot = _next(_hot, -1); return true;
            case vk_down: _hot = _next(_hot, 1); return true;
            case vk_home: _hot = _next(-1, 1); return true;
            case vk_end:  _hot = _next(0, -1); return true;
            case vk_enter:
            case vk_space:
                if (_hot >= 0) _activate(_hot);
                return true;
            case vk_right:
                if (_hot >= 0 && is_array(items[_hot].items)) {
                    _activate(_hot);
                } else {
                    var _root_menu = _root();
                    if (_root_menu._menubar != undefined) _root_menu._menubar.open_menu(_root_menu._menubar_index + 1, true);
                }
                return true;
            case vk_left:
                if (_parent_menu != undefined) {
                    close();
                } else if (_menubar != undefined) {
                    _menubar.open_menu(_menubar_index - 1, true);
                }
                return true;
        }
        return false;
    };

    static popup_closed = function() {
        if (_parent_menu != undefined && _parent_menu._submenu == self) _parent_menu._submenu = undefined;
        if (_menubar != undefined && _menubar._open_menu == self) {
            _menubar._open_menu = undefined;
            _menubar._open_index = -1;
        }
        _submenu = undefined;
    };

    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, _th.menu_bg);
        var _n = array_length(items);
        for (var _i = 0; _i < _n; _i++) {
            var _it = items[_i];
            if (!_it.visible) continue;
            var _y = _sy + _item_y(_i);
            if (_it.separator) {
                gmforms_draw_rect(_sx + 6, _y + floor(separator_height / 2), width - 12, 1, _th.menu_separator);
                continue;
            }
            var _en = _it.enabled;
            if (_i == _hot && _en) gmforms_draw_rect(_sx + 2, _y, width - 4, item_height, _th.menu_hover);
            var _col = _en ? _th.text : _th.text_disabled;
            if (_it.checked) {
                draw_set_colour(_col);
                draw_line_width(_sx + 7, _y + 11, _sx + 10, _y + 14, 2);
                draw_line_width(_sx + 10, _y + 14, _sx + 16, _y + 7, 2);
            }
            gmforms_draw_text_in(_sx + 24, _y, width - 24, item_height, _it.caption, _col, fa_left, fa_middle, 0);
            if (_it.shortcut != "") {
                gmforms_draw_text_in(_sx, _y, width - 22, item_height, _it.shortcut, _th.text_disabled, fa_right, fa_middle, 0);
            }
            if (is_array(_it.items)) {
                var _ax = _sx + width - 12;
                var _ay = _y + item_height * 0.5;
                draw_set_colour(_col);
                draw_triangle(_ax - 2, _ay - 4, _ax - 2, _ay + 4, _ax + 3, _ay, false);
            }
        }
    };

    static draw_overlay = function() {
        gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().menu_border);
    };
}

/// @func GMF_MenuBar()
/// @desc Top-of-form menu bar (align "top"). add_menu(caption, items). Pressing a caption opens its
///       menu; while one is open, hovering another caption switches to it. Item shortcuts
///       ("Ctrl+S") work from anywhere in the form.
function GMF_MenuBar() : GMF_Control() constructor {
    class_name = "MenuBar";
    align = "top";
    height = 24;
    menus = [];                 // menu items whose `items` are the dropdown menus
    _hot = -1;
    _open_index = -1;
    _open_menu = undefined;

    static published = array_concat(gmforms_base_published(), [
        { name: "align",  type: "enum", values: ["none", "top", "bottom", "left", "right", "client"], default_value: "top" },
        { name: "height", type: "int",  default_value: 24 },
    ]);

    /// @func add_menu(caption, items)
    /// @returns {Struct} The top-level menu item.
    static add_menu = function(_caption, _items) {
        var _m = gmforms_submenu(_caption, _items);
        array_push(menus, _m);
        return _m;
    };

    /// @func find_item(caption)
    /// @desc First item with this caption anywhere in the menus (handy for enabling/checking items).
    static find_item = function(_caption) { return _find(menus, _caption); };

    static _find = function(_list, _caption) {
        var _n = array_length(_list);
        for (var _i = 0; _i < _n; _i++) {
            if (_list[_i].caption == _caption) return _list[_i];
            if (is_array(_list[_i].items)) {
                var _r = _find(_list[_i].items, _caption);
                if (_r != undefined) return _r;
            }
        }
        return undefined;
    };

    /// @func is_open()
    static is_open = function() {
        var _f = get_form();
        return _f != undefined && _open_menu != undefined && _f.is_popup_open(_open_menu);
    };

    static _caption_rects = function() {
        var _th = gmforms_theme();
        if (_th.font != -1) draw_set_font(_th.font);
        var _out = [];
        var _x = 4;
        var _n = array_length(menus);
        for (var _i = 0; _i < _n; _i++) {
            var _w = (menus[_i].visible ? string_width(menus[_i].caption) + 16 : 0);
            array_push(_out, { x: _x, w: _w });
            _x += _w;
        }
        return _out;
    };

    static _caption_at = function(_lx, _ly) {
        if (_ly < 0 || _ly >= height) return -1;
        var _r = _caption_rects();
        var _n = array_length(_r);
        for (var _i = 0; _i < _n; _i++) {
            if (_r[_i].w > 0 && _lx >= _r[_i].x && _lx < _r[_i].x + _r[_i].w) return _i;
        }
        return -1;
    };

    /// @func open_menu(index, [select_first])
    /// @desc Opens top-level menu `index` (wraps around), closing any other popup.
    static open_menu = function(_i, _select_first = false) {
        var _f = get_form();
        var _n = array_length(menus);
        if (_f == undefined || _n == 0) return;
        _i = ((_i mod _n) + _n) mod _n;
        var _tries = 0;
        while ((!menus[_i].visible || !menus[_i].enabled) && _tries < _n) { _i = (_i + 1) mod _n; _tries++; }
        _f.close_popups();
        var _pm = new GMF_PopupMenu();
        _pm.items = menus[_i].items;
        _pm._menubar = self;
        _pm._menubar_index = _i;
        _pm._measure();
        var _r = _caption_rects()[_i];
        _open_menu = _pm;
        _open_index = _i;
        _f.show_popup(_pm, _sx - _f._sx + _r.x, _sy - _f._sy + height, self);
        if (_select_first) _pm._hot = _pm._next(-1, 1);
    };

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
        if (_btn != mb_left) return;
        var _i = _caption_at(_x, _y);
        if (_i >= 0) open_menu(_i);
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
        _hot = _caption_at(_x, _y);
        if (_hot >= 0 && _hot != _open_index && is_open()) open_menu(_hot);
    };

    static mouse_leave = function() {
        _hot = -1;
        if (is_callable(on_mouse_leave)) on_mouse_leave(self);
    };

    static handle_shortcut = function(_key, _ctrl, _shift, _alt) {
        if (!is_enabled()) return false;
        var _it = gmforms_menu_find_shortcut(menus, _key, _ctrl, _shift, _alt);
        if (_it == undefined) return false;
        var _f = get_form();
        if (_f != undefined) _f.close_popups();
        if (is_callable(_it.on_click)) _it.on_click(self, _it);
        return true;
    };

    static draw = function() {
        var _th = gmforms_theme();
        gmforms_draw_rect(_sx, _sy, width, height, _th.panel);
        gmforms_draw_rect(_sx, _sy + height - 1, width, 1, _th.panel_border);
        var _r = _caption_rects();
        var _open = is_open();
        var _n = array_length(menus);
        for (var _i = 0; _i < _n; _i++) {
            if (_r[_i].w == 0) continue;
            if (_open && _i == _open_index) gmforms_draw_rect(_sx + _r[_i].x, _sy + 1, _r[_i].w, height - 2, _th.menu_hover);
            else if (_i == _hot && menus[_i].enabled) gmforms_draw_rect(_sx + _r[_i].x, _sy + 1, _r[_i].w, height - 2, _th.button_hover);
            gmforms_draw_text_in(_sx + _r[_i].x, _sy, _r[_i].w, height, menus[_i].caption,
                menus[_i].enabled ? _th.text : _th.text_disabled, fa_center, fa_middle, 0);
        }
    };
}
