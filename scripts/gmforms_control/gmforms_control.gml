/// GMForms — GMF_Control: base class for every control (decision D1: constructor structs, not objects).
///
/// Coordinates
///   left/top are relative to the parent's top-left corner. The parent's padding shrinks the
///   area used by *aligned* children only; anchored children are positioned against the parent's
///   full size (distances to each edge are kept, as in Delphi).
///
/// Changing layout from code
///   Use set_bounds(), set(), set_align(), set_anchors(), set_visible() or set_enabled(). They
///   invalidate layout and, for set_bounds()/set(), re-capture the anchor distances. Assigning
///   left/top/width/height directly on an anchored control is overwritten by the next layout.

/// @func gmforms_base_published()
/// @desc Fresh copy of GMF_Control's published property list. Subclasses build their own list with
///       array_concat(gmforms_base_published(), [ ...own entries... ]); gmforms_serialize dedupes by
///       name, so an entry placed after a base one (e.g. to change a default) wins.
function gmforms_base_published() {
    return [
        { name: "left",   type: "int",  default_value: 0 },
        { name: "top",    type: "int",  default_value: 0 },
        { name: "width",  type: "int",  default_value: 100 },
        { name: "height", type: "int",  default_value: 30 },
        { name: "align",  type: "enum", values: ["none", "top", "bottom", "left", "right", "client"], default_value: "none" },
        { name: "anchors", type: "anchors", default_value: ["left", "top"] },
        { name: "visible",    type: "bool", default_value: true },
        { name: "enabled",    type: "bool", default_value: true },
        { name: "tab_stop",   type: "bool", default_value: false },
        { name: "tab_order",  type: "int",  default_value: -1 },
        { name: "hint",       type: "string", default_value: "" },
        { name: "min_width",  type: "int", default_value: 0 },
        { name: "min_height", type: "int", default_value: 0 },
        { name: "max_width",  type: "int", default_value: 0 },
        { name: "max_height", type: "int", default_value: 0 },
        { name: "margin",  type: "struct", default_value: { l: 0, t: 0, r: 0, b: 0 } },
        { name: "padding", type: "struct", default_value: { l: 0, t: 0, r: 0, b: 0 } },
        { name: "onClick",      type: "event" },
        { name: "onMouseDown",  type: "event" },
        { name: "onMouseUp",    type: "event" },
        { name: "onMouseMove",  type: "event" },
        { name: "onMouseEnter", type: "event" },
        { name: "onMouseLeave", type: "event" },
        { name: "onMouseWheel", type: "event" },
        { name: "onKeyDown",    type: "event" },
        { name: "onKeyUp",      type: "event" },
        { name: "onFocus",      type: "event" },
        { name: "onBlur",       type: "event" },
        { name: "onChange",     type: "event" },
        { name: "onResize",     type: "event" },
    ];
}

/// @func GMF_Control()
/// @desc Base control. Subclasses override draw(), draw_overlay() and the input hooks.
function GMF_Control() constructor {
    class_name = "Control";

    // identity / tree
    name = "";
    parent = undefined;
    children = [];

    // bounds (relative to parent)
    left = 0;
    top = 0;
    width = 100;
    height = 30;

    // layout
    align = "none";                     // none, top, bottom, left, right, client
    anchors = ["left", "top"];          // any of left, top, right, bottom
    margin = { l: 0, t: 0, r: 0, b: 0 };
    padding = { l: 0, t: 0, r: 0, b: 0 };
    min_width = 0;                      // constraints; 0 = no limit
    min_height = 0;
    max_width = 0;
    max_height = 0;

    // state
    visible = true;
    enabled = true;
    tab_stop = false;
    tab_order = -1;                     // -1 = use child order
    hint = "";

    // events: set directly in code, or bound by name from JSON (M2).
    // Handler signature: first argument is always the sender control.
    on_click = undefined;               // (sender)
    on_mouse_down = undefined;          // (sender, x, y, button)   x/y local to the control
    on_mouse_up = undefined;            // (sender, x, y, button)
    on_mouse_move = undefined;          // (sender, x, y)
    on_mouse_enter = undefined;         // (sender)
    on_mouse_leave = undefined;         // (sender)
    on_mouse_wheel = undefined;         // (sender, delta)  delta: +1 = down, -1 = up. Return true to stop bubbling.
    on_key_down = undefined;            // (sender, key)    Return true to mark handled.
    on_key_up = undefined;              // (sender, key)
    on_focus = undefined;               // (sender)
    on_blur = undefined;                // (sender)
    on_change = undefined;              // (sender, ...)    control specific
    on_resize = undefined;              // (sender)

    // internal state
    _sx = 0;                            // absolute GUI position, refreshed every layout pass
    _sy = 0;
    _layout_dirty = true;
    _anchor_captured = false;
    _anc = { l: 0, t: 0, w: 0, h: 0, pw: 0, ph: 0 };
    _ev_names = {};                     // field name (e.g. "on_click") -> handler name last bound by the loader

    // Published property metadata (plan section 7 / M2). Subclasses build their own list with
    // array_concat(gmforms_base_published(), [...]); gmforms_serialize dedupes by name, so a later
    // entry (e.g. a subclass changing a default) overrides an earlier one.
    static published = gmforms_base_published();

    // -----------------------------------------------------------------------
    // Tree
    // -----------------------------------------------------------------------

    /// @func add(child)
    /// @desc Adds a child control (removing it from any previous parent). Returns the child.
    static add = function(_child) {
        if (_child.parent != undefined) _child.parent.remove(_child);
        _child.parent = self;
        _child._anchor_captured = false;
        _child._layout_dirty = true;
        array_push(children, _child);
        invalidate_layout();
        return _child;
    };

    /// @func remove(child)
    /// @desc Removes a direct child. Hover, capture and focus inside it are cleared.
    static remove = function(_child) {
        var _i = array_get_index(children, _child);
        if (_i < 0) return;
        var _form = get_form();
        if (_form != undefined) _form._forget_subtree(_child);
        array_delete(children, _i, 1);
        _child.parent = undefined;
        invalidate_layout();
    };

    /// @func find(name)
    /// @desc Depth-first search for a control by name (self included). Returns undefined if not found.
    static find = function(_name) {
        if (name == _name) return self;
        var _n = array_length(children);
        for (var _i = 0; _i < _n; _i++) {
            var _r = children[_i].find(_name);
            if (_r != undefined) return _r;
        }
        return undefined;
    };

    /// @func walk(callback)
    /// @desc Calls callback(control) for self and every descendant, depth first.
    static walk = function(_fn) {
        _fn(self);
        var _n = array_length(children);
        for (var _i = 0; _i < _n; _i++) children[_i].walk(_fn);
    };

    /// @func get_form()
    /// @desc Returns the root GMF_Form this control belongs to, or undefined if it isn't in a form.
    static get_form = function() {
        var _c = self;
        while (_c.parent != undefined) _c = _c.parent;
        return (_c[$ "is_form"] == true) ? _c : undefined;
    };

    /// @func is_ancestor_of(control)
    /// @desc True if control is self or a descendant of self.
    static is_ancestor_of = function(_ctrl) {
        var _c = _ctrl;
        while (_c != undefined) {
            if (_c == self) return true;
            _c = _c.parent;
        }
        return false;
    };

    // -----------------------------------------------------------------------
    // Property setters (all invalidate layout)
    // -----------------------------------------------------------------------

    /// @func set(props)
    /// @desc Copies every field of the struct onto the control, then re-captures anchors. Returns self.
    static set = function(_props) {
        var _keys = struct_get_names(_props);
        var _n = array_length(_keys);
        for (var _i = 0; _i < _n; _i++) {
            var _k = _keys[_i];
            self[$ _k] = _props[$ _k];
        }
        _anchor_captured = false;
        invalidate_layout();
        return self;
    };

    /// @func set_bounds(left, top, width, height)
    /// @desc Moves/resizes the control and re-captures its anchor distances against the parent's current size.
    static set_bounds = function(_l, _t, _w, _h) {
        left = _l;
        top = _t;
        width = _w;
        height = _h;
        _anchor_captured = false;
        invalidate_layout();
        return self;
    };

    /// @func set_align(align)
    /// @desc "none" | "top" | "bottom" | "left" | "right" | "client"
    static set_align = function(_a) {
        align = _a;
        _anchor_captured = false;
        invalidate_layout();
        return self;
    };

    /// @func set_anchors(anchors)
    /// @desc Array of "left", "top", "right", "bottom".
    static set_anchors = function(_arr) {
        anchors = _arr;
        _anchor_captured = false;
        invalidate_layout();
        return self;
    };

    /// @func set_visible(visible)
    static set_visible = function(_v) {
        if (visible == _v) return self;
        visible = _v;
        invalidate_layout();
        if (!_v) {
            var _form = get_form();
            if (_form != undefined) _form._forget_subtree(self);
        }
        return self;
    };

    /// @func set_enabled(enabled)
    static set_enabled = function(_e) {
        if (enabled == _e) return self;
        enabled = _e;
        if (!_e) {
            var _form = get_form();
            if (_form != undefined) _form._forget_subtree(self);
        }
        return self;
    };

    /// @func focus()
    /// @desc Gives this control keyboard focus.
    static focus = function() {
        var _form = get_form();
        if (_form != undefined) _form.set_focus(self);
    };

    // -----------------------------------------------------------------------
    // State queries
    // -----------------------------------------------------------------------

    /// @func is_enabled()
    /// @desc True if this control and all of its ancestors are enabled.
    static is_enabled = function() {
        var _c = self;
        while (_c != undefined) {
            if (!_c.enabled) return false;
            _c = _c.parent;
        }
        return true;
    };

    /// @func is_showing()
    /// @desc True if this control and all of its ancestors are visible.
    static is_showing = function() {
        var _c = self;
        while (_c != undefined) {
            if (!_c.visible) return false;
            _c = _c.parent;
        }
        return true;
    };

    /// @func is_hot()
    /// @desc Mouse is over this control (and no other control holds the mouse capture).
    static is_hot = function() {
        var _f = get_form();
        return (_f != undefined && _f.hover == self && (_f.capture == undefined || _f.capture == self));
    };

    /// @func is_pressed()
    /// @desc Mouse button went down on this control and is still held over it.
    static is_pressed = function() {
        var _f = get_form();
        return (_f != undefined && _f.capture == self && _f.hover == self);
    };

    /// @func is_focused()
    static is_focused = function() {
        var _f = get_form();
        return (_f != undefined && _f.focused == self);
    };

    /// @func screen_rect()
    /// @desc Absolute GUI rect {x, y, w, h} as of the last layout pass.
    static screen_rect = function() {
        return { x: _sx, y: _sy, w: width, h: height };
    };

    /// @func client_rect()
    /// @desc Local rect inside the padding, used for aligned children.
    static client_rect = function() {
        return {
            x: padding.l,
            y: padding.t,
            w: max(0, width - padding.l - padding.r),
            h: max(0, height - padding.t - padding.b),
        };
    };

    // -----------------------------------------------------------------------
    // Layout engine (plan section 6)
    // -----------------------------------------------------------------------

    /// @func invalidate_layout()
    /// @desc Marks this control and its parent as needing layout. Layout runs once per frame.
    static invalidate_layout = function() {
        _layout_dirty = true;
        if (parent != undefined) parent._layout_dirty = true;
    };

    static _clamp_w = function(_w) {
        if (max_width > 0) _w = min(_w, max_width);
        return max(_w, min_width, 0);
    };

    static _clamp_h = function(_h) {
        if (max_height > 0) _h = min(_h, max_height);
        return max(_h, min_height, 0);
    };

    /// Sets the laid-out rect. A size change marks the control dirty so its own children re-arrange.
    static _place = function(_x, _y, _w, _h) {
        _x = round(_x);
        _y = round(_y);
        _w = round(_w);
        _h = round(_h);
        left = _x;
        top = _y;
        if (_w != width || _h != height) {
            width = _w;
            height = _h;
            _layout_dirty = true;
            if (is_callable(on_resize)) on_resize(self);
        }
    };

    /// Anchors: keep distances captured at design size (Delphi semantics).
    static _layout_anchored = function(_pw, _ph) {
        if (!_anchor_captured) {
            _anc.l = left;
            _anc.t = top;
            _anc.w = width;
            _anc.h = height;
            _anc.pw = _pw;
            _anc.ph = _ph;
            _anchor_captured = true;
        }
        var _dw = _pw - _anc.pw;
        var _dh = _ph - _anc.ph;

        var _al = array_contains(anchors, "left");
        var _ar = array_contains(anchors, "right");
        var _at = array_contains(anchors, "top");
        var _ab = array_contains(anchors, "bottom");

        var _x, _y, _w, _h;

        if (_al && _ar)      { _x = _anc.l;       _w = _anc.w + _dw; }
        else if (_ar)        { _x = _anc.l + _dw; _w = _anc.w; }
        else if (_al)        { _x = _anc.l;       _w = _anc.w; }
        else {
            // neither: keep the control's centre at the same relative position (Q3: Delphi behaviour)
            _w = _anc.w;
            _x = (_anc.pw > 0) ? ((_anc.l + _anc.w * 0.5) * _pw / _anc.pw - _w * 0.5) : _anc.l;
        }

        if (_at && _ab)      { _y = _anc.t;       _h = _anc.h + _dh; }
        else if (_ab)        { _y = _anc.t + _dh; _h = _anc.h; }
        else if (_at)        { _y = _anc.t;       _h = _anc.h; }
        else {
            _h = _anc.h;
            _y = (_anc.ph > 0) ? ((_anc.t + _anc.h * 0.5) * _ph / _anc.ph - _h * 0.5) : _anc.t;
        }

        _place(_x, _y, _clamp_w(_w), _clamp_h(_h));
    };

    /// @func arrange_children()
    /// @desc Positions direct children: aligned ones (top, bottom, left, right, client — each group in
    ///       child order), then anchored ones. Invisible children are skipped.
    static arrange_children = function() {
        var _cr = client_rect();
        var _rx = _cr.x, _ry = _cr.y, _rw = _cr.w, _rh = _cr.h;
        var _n = array_length(children);
        var _i, _c, _m, _x, _y, _w, _h, _used;

        // top
        for (_i = 0; _i < _n; _i++) {
            _c = children[_i];
            if (!_c.visible || _c.align != "top") continue;
            _m = _c.margin;
            _h = _c._clamp_h(_c.height);
            _w = _c._clamp_w(_rw - _m.l - _m.r);
            _c._place(_rx + _m.l, _ry + _m.t, _w, _h);
            _used = min(_rh, _h + _m.t + _m.b);
            _ry += _used;
            _rh = max(0, _rh - _used);
        }
        // bottom
        for (_i = 0; _i < _n; _i++) {
            _c = children[_i];
            if (!_c.visible || _c.align != "bottom") continue;
            _m = _c.margin;
            _h = _c._clamp_h(_c.height);
            _w = _c._clamp_w(_rw - _m.l - _m.r);
            _c._place(_rx + _m.l, _ry + _rh - _m.b - _h, _w, _h);
            _used = min(_rh, _h + _m.t + _m.b);
            _rh = max(0, _rh - _used);
        }
        // left
        for (_i = 0; _i < _n; _i++) {
            _c = children[_i];
            if (!_c.visible || _c.align != "left") continue;
            _m = _c.margin;
            _w = _c._clamp_w(_c.width);
            _h = _c._clamp_h(_rh - _m.t - _m.b);
            _c._place(_rx + _m.l, _ry + _m.t, _w, _h);
            _used = min(_rw, _w + _m.l + _m.r);
            _rx += _used;
            _rw = max(0, _rw - _used);
        }
        // right
        for (_i = 0; _i < _n; _i++) {
            _c = children[_i];
            if (!_c.visible || _c.align != "right") continue;
            _m = _c.margin;
            _w = _c._clamp_w(_c.width);
            _h = _c._clamp_h(_rh - _m.t - _m.b);
            _c._place(_rx + _rw - _m.r - _w, _ry + _m.t, _w, _h);
            _used = min(_rw, _w + _m.l + _m.r);
            _rw = max(0, _rw - _used);
        }
        // client: each gets the remaining rect
        for (_i = 0; _i < _n; _i++) {
            _c = children[_i];
            if (!_c.visible || _c.align != "client") continue;
            _m = _c.margin;
            _w = _c._clamp_w(_rw - _m.l - _m.r);
            _h = _c._clamp_h(_rh - _m.t - _m.b);
            _c._place(_rx + _m.l, _ry + _m.t, _w, _h);
        }
        // anchored (align = none)
        for (_i = 0; _i < _n; _i++) {
            _c = children[_i];
            if (!_c.visible || _c.align != "none") continue;
            _c._layout_anchored(width, height);
        }
    };

    /// @func layout_tree()
    /// @desc Re-arranges dirty subtrees and refreshes absolute positions. Called by the form each frame.
    static layout_tree = function() {
        if (_layout_dirty) {
            _layout_dirty = false;
            arrange_children();
        }
        var _n = array_length(children);
        for (var _i = 0; _i < _n; _i++) {
            var _c = children[_i];
            _c._sx = _sx + _c.left;
            _c._sy = _sy + _c.top;
            if (_c.visible) _c.layout_tree();
        }
    };

    // -----------------------------------------------------------------------
    // Hit testing and drawing
    // -----------------------------------------------------------------------

    /// @func hit_test(gui_x, gui_y)
    /// @desc Deepest visible control under the point (children are clipped to their parent), or undefined.
    static hit_test = function(_gx, _gy) {
        if (!visible || width <= 0 || height <= 0) return undefined;
        if (_gx < _sx || _gy < _sy || _gx >= _sx + width || _gy >= _sy + height) return undefined;
        for (var _i = array_length(children) - 1; _i >= 0; _i--) {
            var _h = children[_i].hit_test(_gx, _gy);
            if (_h != undefined) return _h;
        }
        return self;
    };

    /// @func draw()
    /// @desc Paints the control itself (before its children). Override in subclasses. Use _sx/_sy for position.
    static draw = function() {};

    /// @func draw_overlay()
    /// @desc Paints on top of the children (borders, focus rectangles). Override in subclasses.
    static draw_overlay = function() {};

    /// @func draw_tree()
    /// @desc Draws self, then children clipped to this control's rect, then the overlay.
    static draw_tree = function() {
        if (!visible || width <= 0 || height <= 0) return;
        draw();
        var _n = array_length(children);
        if (_n > 0) {
            if (gmforms_scissor_push(_sx, _sy, width, height)) {
                for (var _i = 0; _i < _n; _i++) children[_i].draw_tree();
            }
            gmforms_scissor_pop();
        }
        draw_overlay();
    };

    // -----------------------------------------------------------------------
    // Input hooks. The form calls these; subclasses may override and should
    // still fire the user events (or call the base behaviour they replace).
    // -----------------------------------------------------------------------

    static mouse_down = function(_x, _y, _btn) {
        if (is_callable(on_mouse_down)) on_mouse_down(self, _x, _y, _btn);
    };

    static mouse_up = function(_x, _y, _btn) {
        if (is_callable(on_mouse_up)) on_mouse_up(self, _x, _y, _btn);
    };

    static mouse_move = function(_x, _y) {
        if (is_callable(on_mouse_move)) on_mouse_move(self, _x, _y);
    };

    static mouse_enter = function() {
        if (is_callable(on_mouse_enter)) on_mouse_enter(self);
    };

    static mouse_leave = function() {
        if (is_callable(on_mouse_leave)) on_mouse_leave(self);
    };

    /// Returns true if handled (stops bubbling to the parent).
    static mouse_wheel = function(_delta) {
        if (is_callable(on_mouse_wheel)) return (on_mouse_wheel(self, _delta) == true);
        return false;
    };

    /// @func click()
    /// @desc Performs a click (mouse release over the control, or keyboard activation).
    static click = function() {
        if (is_callable(on_click)) on_click(self);
    };

    /// Returns true if handled.
    static key_down = function(_key) {
        if (is_callable(on_key_down)) return (on_key_down(self, _key) == true);
        return false;
    };

    static key_up = function(_key) {
        if (is_callable(on_key_up)) on_key_up(self, _key);
    };

    static focus_gained = function() {
        if (is_callable(on_focus)) on_focus(self);
    };

    static focus_lost = function() {
        if (is_callable(on_blur)) on_blur(self);
    };
}
