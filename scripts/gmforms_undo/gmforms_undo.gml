/// GMForms — GMF_UndoStack: public command-based undo/redo helper (plan section 13).
///
/// A command is a struct with do_fn, undo_fn and an optional label. Put the data the command needs
/// on the command struct itself: a function written inside a struct literal is bound to that struct,
/// so it can read the struct's own fields.
///
///   undo.execute({
///       label: "Paint", cell: _cell, old_value: _cell.t, new_value: 3,
///       do_fn:   function() { cell.t = new_value; },
///       undo_fn: function() { cell.t = old_value; },
///   });
///
/// Commands pushed while an undo()/redo() is running are ignored. That makes it safe for an
/// on_change handler to record undo steps even though undo/redo also fire it.

/// @func GMF_UndoStack([limit])
/// @param {Real} [limit] Maximum number of undo steps kept (0 = unlimited). Default 200.
/// @desc Command-based undo/redo with grouping. See also push_snapshot() for JSON-snapshot style undo.
function GMF_UndoStack(_limit = 200) constructor {
    limit = _limit;
    on_change = undefined;      // (sender) fired after push, undo, redo and clear — refresh Undo/Redo buttons here

    _undo = [];
    _redo = [];
    _group = undefined;         // { label, cmds } while a group is open
    _group_depth = 0;
    _busy = false;              // true while a command's do_fn/undo_fn runs

    /// @func push(cmd)
    /// @desc Records a command whose change has already been made. Clears the redo list.
    /// @param {Struct} cmd { do_fn, undo_fn, [label] }
    static push = function(_cmd) {
        if (_busy) return;
        var _ok = is_struct(_cmd) && (is_array(_cmd[$ "cmds"])
            || (is_callable(_cmd[$ "do_fn"]) && is_callable(_cmd[$ "undo_fn"])));
        if (!_ok) {
            gmforms_log("undo: push() needs a struct with do_fn and undo_fn");
            return;
        }
        if (_group != undefined) {
            array_push(_group.cmds, _cmd);
            return;
        }
        array_push(_undo, _cmd);
        if (limit > 0 && array_length(_undo) > limit) array_delete(_undo, 0, array_length(_undo) - limit);
        _redo = [];
        _changed();
    };

    /// @func execute(cmd)
    /// @desc Runs cmd.do_fn(), then records the command. Returns the command.
    /// @param {Struct} cmd { do_fn, undo_fn, [label] }
    static execute = function(_cmd) {
        if (_busy) return _cmd;
        _busy = true;
        _cmd.do_fn();
        _busy = false;
        push(_cmd);
        return _cmd;
    };

    /// @func set_value(target, key, value, [label], [after_fn])
    /// @desc Sets target[key] (a struct field or array index) and records it as one undo step.
    ///       after_fn(), if given, runs after the change and after each undo/redo of it.
    /// @returns {Struct} The command.
    static set_value = function(_target, _key, _value, _label = undefined, _after = undefined) {
        return execute({
            label: _label ?? ("Set " + string(_key)),
            target: _target,
            key: _key,
            old_value: gmforms_get_value(_target, _key),
            new_value: _value,
            after: _after,
            do_fn: function() {
                gmforms_put_value(target, key, new_value);
                if (is_callable(after)) after();
            },
            undo_fn: function() {
                gmforms_put_value(target, key, old_value);
                if (is_callable(after)) after();
            },
        });
    };

    /// @func push_snapshot(label, before, after, restore_fn)
    /// @desc Snapshot-style undo (the plan's "simple fallback mode"): records a step that calls
    ///       restore_fn(before) to undo and restore_fn(after) to redo. before/after are typically
    ///       JSON strings of the whole document. The change itself must already have been made.
    static push_snapshot = function(_label, _before, _after, _restore_fn) {
        push({
            label: _label,
            before: _before,
            after: _after,
            restore: _restore_fn,
            do_fn: function() { restore(after); },
            undo_fn: function() { restore(before); },
        });
    };

    /// @func begin_group(label)
    /// @desc Starts collecting pushed commands into one undo step (e.g. for a mouse drag).
    ///       Groups nest; only the outermost label is used.
    static begin_group = function(_label = "") {
        if (_group_depth == 0) _group = { label: _label, cmds: [] };
        _group_depth++;
    };

    /// @func end_group()
    /// @desc Closes the group opened by begin_group(). An empty group records nothing.
    static end_group = function() {
        if (_group_depth <= 0) return;
        _group_depth--;
        if (_group_depth > 0) return;
        var _g = _group;
        _group = undefined;
        if (array_length(_g.cmds) == 0) return;
        push(_g);
    };

    /// @func in_group()
    static in_group = function() { return _group_depth > 0; };

    /// @func can_undo()
    static can_undo = function() { return array_length(_undo) > 0; };

    /// @func can_redo()
    static can_redo = function() { return array_length(_redo) > 0; };

    /// @func undo_label()
    /// @desc Label of the step undo() would revert, or "" if there is none.
    static undo_label = function() {
        var _n = array_length(_undo);
        return (_n > 0) ? (_undo[_n - 1][$ "label"] ?? "") : "";
    };

    /// @func redo_label()
    static redo_label = function() {
        var _n = array_length(_redo);
        return (_n > 0) ? (_redo[_n - 1][$ "label"] ?? "") : "";
    };

    /// @func undo()
    /// @desc Reverts the most recent step. An open group is closed first. Returns true if something was undone.
    static undo = function() {
        while (_group_depth > 0) end_group();
        if (array_length(_undo) == 0 || _busy) return false;
        var _cmd = array_pop(_undo);
        _busy = true;
        _run(_cmd, false);
        _busy = false;
        array_push(_redo, _cmd);
        _changed();
        return true;
    };

    /// @func redo()
    /// @desc Re-applies the most recently undone step. Returns true if something was redone.
    static redo = function() {
        while (_group_depth > 0) end_group();
        if (array_length(_redo) == 0 || _busy) return false;
        var _cmd = array_pop(_redo);
        _busy = true;
        _run(_cmd, true);
        _busy = false;
        array_push(_undo, _cmd);
        _changed();
        return true;
    };

    /// @func clear()
    /// @desc Forgets all undo and redo steps (e.g. after loading a new document).
    static clear = function() {
        _undo = [];
        _redo = [];
        _group = undefined;
        _group_depth = 0;
        _changed();
    };

    /// Groups run their commands forwards to redo and backwards to undo.
    static _run = function(_cmd, _forward) {
        var _cmds = _cmd[$ "cmds"];
        if (is_array(_cmds)) {
            var _n = array_length(_cmds);
            if (_forward) for (var _i = 0; _i < _n; _i++) _run(_cmds[_i], true);
            else for (var _i = _n - 1; _i >= 0; _i--) _run(_cmds[_i], false);
            return;
        }
        if (_forward) _cmd.do_fn(); else _cmd.undo_fn();
    };

    static _changed = function() {
        if (is_callable(on_change)) on_change(self);
    };
}

/// @func gmforms_get_value(target, key)
/// @desc Reads target[key]: an array index when target is an array, otherwise a struct field.
function gmforms_get_value(_target, _key) {
    if (is_array(_target)) return _target[_key];
    return _target[$ _key];
}

/// @func gmforms_put_value(target, key, value)
/// @desc Writes target[key]: an array index when target is an array, otherwise a struct field.
function gmforms_put_value(_target, _key, _value) {
    if (is_array(_target)) _target[@ _key] = _value;
    else _target[$ _key] = _value;
}
