/// GMForms — headless layout/input tests. Results go to the Output log.
/// They build the M1 demo form in memory (no host, no window needed) and check the reflowed rects.

#macro GMF_RUN_TESTS true      // set to false to skip the tests at demo start-up

/// @func gmforms_run_tests()
/// @desc Runs the M1 test suite and logs "[GMForms tests] N passed, M failed".
/// @returns {Bool} True if every check passed.
function gmforms_run_tests() {
    var _t = {
        passed: 0,
        failed: 0,
        eq: function(_label, _actual, _expected) {
            if (_actual == _expected) {
                passed++;
            } else {
                failed++;
                show_debug_message("[GMForms tests] FAIL " + _label + ": expected " + string(_expected) + ", got " + string(_actual));
            }
        },
        rect: function(_label, _c, _l, _tp, _w, _h) {
            eq(_label + ".left", _c.left, _l);
            eq(_label + ".top", _c.top, _tp);
            eq(_label + ".width", _c.width, _w);
            eq(_label + ".height", _c.height, _h);
        },
    };

    var _f = demo_m1_build_form();

    // --- design size: Align ---------------------------------------------------
    _f.layout();
    _t.rect("design toolbar",   _f.find("pnlToolbar"),   0, 0, 1024, 40);
    _t.rect("design status",    _f.find("pnlStatus"),    0, 674, 1024, 26);
    _t.rect("design palette",   _f.find("pnlPalette"),   0, 40, 180, 634);
    _t.rect("design inspector", _f.find("pnlInspector"), 804, 40, 220, 634);
    _t.rect("design client",    _f.find("pnlClient"),    180, 40, 624, 634);
    _t.rect("design body (margins)", _f.find("pnlInspectorBody"), 6, 24, 208, 634 - 24 - 48);

    // --- resize larger: Align + Anchors ------------------------------------------
    _f.set_bounds(0, 0, 1400, 900);
    _f.layout();
    var _ch = 900 - 66;         // 834
    var _cw = 1400 - 400;       // 1000
    _t.rect("large toolbar",   _f.find("pnlToolbar"),   0, 0, 1400, 40);
    _t.rect("large status",    _f.find("pnlStatus"),    0, 874, 1400, 26);
    _t.rect("large palette",   _f.find("pnlPalette"),   0, 40, 180, _ch);
    _t.rect("large inspector", _f.find("pnlInspector"), 1180, 40, 220, _ch);
    _t.rect("large client",    _f.find("pnlClient"),    180, 40, _cw, _ch);
    _t.rect("large header (nested top)", _f.find("pnlClientHeader"), 0, 0, _cw, 30);

    _t.rect("btnHelp right,top",      _f.find("btnHelp"),    1400 - 86, 6, 80, 28);
    _t.rect("lblSize right,top",      _f.find("lblSize"),    1400 - 164, 2, 160, 22);
    _t.rect("lblStatus stretch",      _f.find("lblStatus"),  4, 2, 700 + 376, 22);
    _t.rect("btnTL left,top",         _f.find("btnTL"),      16, 46, 130, 28);
    _t.rect("btnTR right,top",        _f.find("btnTR"),      _cw - 16 - 130, 46, 130, 28);
    _t.rect("btnBL left,bottom",      _f.find("btnBL"),      16, _ch - 46, 130, 28);
    _t.rect("btnBR right,bottom",     _f.find("btnBR"),      _cw - 16 - 130, _ch - 46, 130, 28);
    _t.rect("btnStretch l,t,r",       _f.find("btnStretch"), 16, 84, _cw - 32, 28);
    _t.rect("pnlStretchBoth all four", _f.find("pnlStretchBoth"), 16, 124, _cw - 32, _ch - 184);
    _t.rect("btnSettings l,r,bottom", _f.find("btnSettings"), 8, _ch - 36, 164, 28);
    _t.rect("btnApply right,bottom",  _f.find("btnApply"),   220 - 88, _ch - 38, 80, 28);
    // no anchors: centre stays proportional. Box 592x450 -> 968x650; centre (296,225) -> (484,325)
    _t.rect("btnCentre no anchors",   _f.find("btnCentre"),  484 - 120, 325 - 14, 240, 28);

    // absolute positions and hit testing
    var _tr = _f.find("btnTR");
    _t.eq("btnTR _sx", _tr._sx, 180 + _tr.left);
    _t.eq("btnTR _sy", _tr._sy, 40 + _tr.top);
    _t.eq("hit_test btnTR", _f.hit_test(_tr._sx + 5, _tr._sy + 5), _tr);
    _t.eq("hit_test toolbar gap", _f.hit_test(270, 20), _f.find("pnlToolbar"));
    _t.eq("hit_test outside", _f.hit_test(-5, -5), undefined);

    // --- visibility change reflows ----------------------------------------------
    _f.find("pnlPalette").set_visible(false);
    _f.layout();
    _t.rect("client after hiding palette", _f.find("pnlClient"), 0, 40, 1400 - 220, _ch);
    _t.eq("hidden palette not hit", _f.hit_test(50, 300), _f.find("pnlStretchBoth"));
    _f.find("pnlPalette").set_visible(true);
    _f.layout();
    _t.rect("client after showing palette", _f.find("pnlClient"), 180, 40, _cw, _ch);

    // --- back to design size: anchors don't drift ---------------------------------
    _f.set_bounds(0, 0, 1024, 700);
    _f.layout();
    _t.rect("btnTR back at design", _f.find("btnTR"), 624 - 16 - 130, 46, 130, 28);
    _t.rect("btnCentre back at design", _f.find("btnCentre"), 176, 211, 240, 28);

    // --- tiny window: nothing negative -------------------------------------------
    _f.set_bounds(0, 0, 300, 50);
    _f.layout();
    var _checker = { bad: 0 };
    _f.walk(method(_checker, function(_c) { if (_c.width < 0 || _c.height < 0) bad++; }));
    _t.eq("no negative sizes in tiny window", _checker.bad, 0);

    // --- constraints ---------------------------------------------------------------
    var _cf = gmforms_create(GMF_Form, { width: 400, height: 300 });
    var _cp = _cf.add(gmforms_create(GMF_Panel, { align: "client", max_width: 150, min_height: 500 }));
    _cf.layout();
    _t.eq("max_width on client", _cp.width, 150);
    _t.eq("min_height on client", _cp.height, 500);

    // --- focus / tab order -------------------------------------------------------------
    _f.set_bounds(0, 0, 1024, 700);
    _f.layout();
    var _tabs = _f.get_tab_list();
    _t.eq("first tab stop", _tabs[0].name, "btnNew");
    _t.eq("last tab stop", _tabs[array_length(_tabs) - 1].name, "btnBR");
    _f.focus_next(1);
    _t.eq("Tab from nothing", _f.focused.name, "btnNew");
    _f.focus_next(1);
    _t.eq("Tab again", _f.focused.name, "btnOpen");
    _f.focus_next(-1);
    _f.focus_next(-1);
    _t.eq("Shift+Tab wraps", _f.focused.name, "btnBR");
    _f.find("btnBR").set_enabled(false);
    _t.eq("disabling focused clears focus", _f.focused, undefined);
    _f.find("pnlToolbar").set_visible(false);
    _f.focus_next(1);
    _t.eq("hidden subtree skipped", _f.focused.name, "btnToolSelect");

    // --- click dispatch via keyboard ---------------------------------------------------
    var _counter = { clicks: 0 };
    var _b = _f.find("btnToolSelect");
    _b.on_click = method(_counter, function(_s) { clicks++; });
    _b.key_down(vk_space);
    _b.key_up(vk_space);
    _t.eq("Space clicks focused button", _counter.clicks, 1);
    _b.set_enabled(false);
    _b.key_down(vk_space);
    _b.key_up(vk_space);
    _t.eq("disabled button ignores Space", _counter.clicks, 1);

    // --- M2: serialization ---------------------------------------------------------------

    // round trip: code-built tree -> JSON -> tree -> JSON must be byte-identical
    var _rf = gmforms_create(GMF_Form, { name: "frmTest", width: 500, height: 300, caption: "Test" });
    var _bar = _rf.add(gmforms_create(GMF_Panel, { name: "pnlBar", align: "top", height: 36 }));
    var _btn = _bar.add(gmforms_create(GMF_Button, { name: "btnOk", caption: "OK", left: 6, top: 4 }));
    _btn._ev_names[$ "on_click"] = "btnOk_Click";
    _rf.add(gmforms_create(GMF_Label, { name: "lblInfo", caption: "Hi", left: 10, top: 50 }));

    var _json1 = gmforms_form_to_json(_rf);
    var _tree2 = gmforms_load_form_json(_json1, { btnOk_Click: function(_s) {} });
    var _json2 = gmforms_form_to_json(_tree2);
    _t.eq("serialize round trip is stable", _json1, _json2);
    _t.eq("event resolved against handlers", is_callable(_tree2.find("btnOk").on_click), true);

    // missing handler: warns (see log), leaves the field unset, but keeps the name for re-saving
    var _tree3 = gmforms_load_form_json(_json1, {});
    _t.eq("missing handler leaves on_click unresolved", _tree3.find("btnOk").on_click, undefined);
    _t.eq("missing handler name still round-trips", gmforms_form_to_json(_tree3), _json1);

    // defaults are omitted
    var _plain = gmforms_create(GMF_Button, { name: "btnPlain" });
    var _ps = gmforms_control_to_struct(_plain);
    _t.eq("default caption omitted", struct_exists(_ps, "caption"), false);
    _t.eq("default width omitted", struct_exists(_ps, "width"), false);
    _t.eq("class always present", _ps[$ "class"], "Button");
    _t.eq("name present when set", _ps[$ "name"], "btnPlain");

    // anchored controls serialize their design rect, not the current (drifted) one
    var _pf = gmforms_create(GMF_Form, { width: 400, height: 300 });
    var _pp = _pf.add(gmforms_create(GMF_Panel, { align: "client" }));
    var _ac = _pp.add(gmforms_create(GMF_Control, { name: "acRight", left: 300, top: 10, width: 100, height: 20, anchors: ["right", "top"] }));
    _pf.layout();
    _pf.set_bounds(0, 0, 800, 300);
    _pf.layout();
    _t.eq("anchored control drifted before serializing", _ac.left, 700);
    _t.eq("serialize keeps design left, not drifted left", gmforms_control_to_struct(_ac)[$ "left"], 300);

    // unknown class: warns, is skipped, siblings still load
    var _bad_json = json_stringify({
        format: "gmforms", version: 1,
        root: { class: "Form", children: [
            { class: "Frobnicator", name: "whoops" },
            { class: "Label", name: "lblOk" },
        ] },
    });
    var _bt = gmforms_load_form_json(_bad_json);
    _t.eq("unknown class child skipped, root still loads", array_length(_bt.children), 1);
    _t.eq("sibling after unknown class still loads", _bt.children[0].name, "lblOk");

    // unsupported version / wrong format are rejected, not crashed on
    _t.eq("unsupported version rejected", gmforms_load_form_json(json_stringify({ format: "gmforms", version: 2, root: { class: "Form" } })), undefined);
    _t.eq("wrong format rejected", gmforms_load_form_json(json_stringify({ format: "nope", version: 1, root: {} })), undefined);

    // --- M3: CheckBox ---------------------------------------------------------------
    var _cb = gmforms_create(GMF_CheckBox, { name: "cbTest" });
    _t.eq("checkbox default unchecked", _cb.checked, false);
    var _cbc = { changes: 0, last: undefined, clicks: 0 };
    _cb.on_change = method(_cbc, function(_s, _v) { changes++; last = _v; });
    _cb.on_click  = method(_cbc, function(_s) { clicks++; });
    _cb.click();
    _t.eq("checkbox click toggles checked", _cb.checked, true);
    _t.eq("checkbox fires on_change", _cbc.changes, 1);
    _t.eq("checkbox on_change value", _cbc.last, true);
    _t.eq("checkbox fires on_click too", _cbc.clicks, 1);
    _cb.click();
    _t.eq("checkbox click toggles back", _cb.checked, false);
    _cb.key_down(vk_space); _cb.key_up(vk_space);
    _t.eq("space toggles checkbox", _cb.checked, true);
    _cb.set_enabled(false);
    _cb.key_down(vk_space); _cb.key_up(vk_space);
    _t.eq("disabled checkbox ignores space", _cb.checked, true);
    var _cbs = gmforms_control_to_struct(gmforms_create(GMF_CheckBox, { name: "cbPlain" }));
    _t.eq("checkbox default checked omitted", struct_exists(_cbs, "checked"), false);
    _t.eq("checkbox class name", _cbs[$ "class"], "CheckBox");

    // --- M3: Splitter -----------------------------------------------------------------
    var _sf = gmforms_create(GMF_Form, { width: 600, height: 300 });
    var _pal = _sf.add(gmforms_create(GMF_Panel, { name: "palLeft", align: "left", width: 200 }));
    var _spl = _sf.add(gmforms_create(GMF_Splitter, { name: "splLeft", align: "left", width: 4, min_size: 40 }));
    var _cli = _sf.add(gmforms_create(GMF_Panel, { name: "cliMain", align: "client" }));
    _sf.layout();
    _t.rect("splitter(left): palette initial", _pal, 0, 0, 200, 300);
    _t.rect("splitter(left): splitter initial", _spl, 200, 0, 4, 300);
    _t.rect("splitter(left): client initial", _cli, 204, 0, 396, 300);

    _spl.mouse_down(2, 10, mb_left);
    _sf.capture = _spl;
    _spl.mouse_move(2 + 30, 10);   // drag right 30px -> left-aligned target grows
    _sf.layout();
    _t.eq("splitter(left) drag right grows target", _pal.width, 230);
    _spl.mouse_move(2 - 300, 10);  // drag far left of the original press -> clamps to min_size
    _sf.layout();
    _t.eq("splitter(left) clamps to min_size", _pal.width, 40);
    _spl.mouse_up(2, 10, mb_left);
    _sf.capture = undefined;

    var _sf2 = gmforms_create(GMF_Form, { width: 600, height: 300 });
    var _insp = _sf2.add(gmforms_create(GMF_Panel, { name: "insp", align: "right", width: 260 }));
    var _spl2 = _sf2.add(gmforms_create(GMF_Splitter, { name: "splR", align: "right", width: 4, min_size: 40 }));
    var _cli2 = _sf2.add(gmforms_create(GMF_Panel, { name: "cliR", align: "client" }));
    _sf2.layout();
    _spl2.mouse_down(2, 10, mb_left);
    _sf2.capture = _spl2;
    _spl2.mouse_move(2 + 10, 10);  // drag right 10px toward the right-docked target -> shrinks it
    _sf2.layout();
    _t.eq("splitter(right) drag right shrinks target", _insp.width, 250);
    _sf2.capture = undefined;

    _t.eq("splitter registered class name", gmforms_control_to_struct(gmforms_create(GMF_Splitter, { name: "splPlain" }))[$ "class"], "Splitter");

    // --- M3: Viewport -----------------------------------------------------------------
    var _vp = gmforms_create(GMF_Viewport, { name: "vpTest", width: 400, height: 300 });
    _vp.cam = { x: 100, y: 50, zoom: 2 };
    var _w1 = _vp.screen_to_world(40, 30);
    _t.eq("screen_to_world x", _w1.x, 100 + 40 / 2);
    _t.eq("screen_to_world y", _w1.y, 50 + 30 / 2);
    var _s1 = _vp.world_to_screen(_w1.x, _w1.y);
    _t.eq("world_to_screen round trip x", _s1.x, 40);
    _t.eq("world_to_screen round trip y", _s1.y, 30);

    _vp.cam = { x: 0, y: 0, zoom: 1 };
    var _anchor_before = _vp.screen_to_world(100, 80);
    _vp.zoom_at(100, 80, 2);
    var _anchor_after = _vp.world_to_screen(_anchor_before.x, _anchor_before.y);
    _t.eq("zoom_at keeps cursor point fixed x", round(_anchor_after.x), 100);
    _t.eq("zoom_at keeps cursor point fixed y", round(_anchor_after.y), 80);
    _t.eq("zoom_at applied factor", _vp.cam.zoom, 2);

    _vp.min_zoom = 0.5; _vp.max_zoom = 4;
    _vp.zoom_at(0, 0, 100);
    _t.eq("zoom clamps to max_zoom", _vp.cam.zoom, 4);
    _vp.zoom_at(0, 0, 0.0001);
    _t.eq("zoom clamps to min_zoom", _vp.cam.zoom, 0.5);

    _vp.cam = { x: 0, y: 0, zoom: 2 };
    _vp.mouse_down(50, 50, mb_middle);
    _vp.mouse_move(60, 55);
    _t.eq("pan moves cam.x opposite drag, scaled by zoom", _vp.cam.x, -10 / 2);
    _t.eq("pan moves cam.y opposite drag, scaled by zoom", _vp.cam.y, -5 / 2);
    _vp.mouse_up(60, 55, mb_middle);
    _t.eq("pan ends on mouse up", _vp._panning, false);

    var _md = { got: undefined };
    _vp.cam = { x: 10, y: 10, zoom: 2 };
    _vp.on_mouse_down = method(_md, function(_s, _wx, _wy, _btn) { got = { x: _wx, y: _wy, btn: _btn }; });
    _vp.mouse_down(20, 20, mb_left);
    _t.eq("on_mouse_down gets world x", _md.got.x, 10 + 20 / 2);
    _t.eq("on_mouse_down gets world y", _md.got.y, 10 + 20 / 2);
    _md.got = undefined;
    _vp.mouse_down(20, 20, mb_middle);
    _t.eq("panning click does not fire on_mouse_down", _md.got, undefined);
    _vp.mouse_up(20, 20, mb_middle);

    var _vp2 = gmforms_create(GMF_Viewport, { name: "vpWheel", width: 200, height: 200 });
    _vp2.cam = { x: 0, y: 0, zoom: 1 };
    var _wc = { fired: 0 };
    _vp2.on_wheel = method(_wc, function(_s, _d) { fired++; });
    _vp2.mouse_wheel(-1);
    _t.eq("wheel up zooms in", _vp2.cam.zoom > 1, true);
    _vp2.mouse_wheel(1);
    _t.eq("on_wheel fires per call", _wc.fired, 2);

    _t.eq("viewport registered class name", gmforms_control_to_struct(gmforms_create(GMF_Viewport, { name: "vpPlain" }))[$ "class"], "Viewport");

    // --- M3: Edit ---------------------------------------------------------------------
    var _ed = gmforms_create(GMF_Edit, { name: "edTest" });
    var _edc = { changes: 0 };
    _ed.on_change = method(_edc, function(_s, _v) { changes++; });
    _ed.key_char("H"); _ed.key_char("i");
    _t.eq("typed text", _ed.text, "Hi");
    _t.eq("caret after typing", _ed._caret, 2);
    _t.eq("on_change fired per keystroke", _edc.changes, 2);

    _ed.key_char(chr(8));
    _t.eq("control char ignored by key_char", _ed.text, "Hi");

    _ed.key_down(vk_backspace);
    _t.eq("backspace deletes before caret", _ed.text, "H");
    _ed._move_caret(0, false);
    _ed.key_down(vk_delete);
    _t.eq("delete removes after caret", _ed.text, "");

    _ed.text = "Hello World";
    _ed.select_all();
    _t.eq("select_all selects to end", _ed._caret, string_length(_ed.text));
    _ed.key_down(vk_backspace);
    _t.eq("backspace with full selection clears text", _ed.text, "");

    _ed.text = "Hello";
    _ed._move_caret(0, false);
    _ed._move_caret(3, true);
    _t.eq("_move_caret extends selection", _ed._sel_anchor, 0);
    _ed._insert_text("X");
    _t.eq("typing replaces selection", _ed.text, "Xlo");

    _ed.text = "sample text";
    _ed.select_all();
    _ed.cut();
    _t.eq("cut removes selected text regardless of OS clipboard result", _ed.text, "");
    _ed._insert_text("pasted");
    _t.eq("insertion used by paste() works", _ed.text, "pasted");

    _t.eq("_index_at_x clicking far left is index 0", _ed._index_at_x(0), 0);
    _t.eq("_index_at_x clicking far right clamps to text length", _ed._index_at_x(999999), string_length(_ed.text));

    _ed.password = true;
    _t.eq("password mode still bounds index to text length", _ed._index_at_x(999999), string_length(_ed.text));

    var _ed2 = gmforms_create(GMF_Edit, { name: "edScroll", width: 50 });
    _ed2.text = string_repeat("x", 50);
    _ed2._move_caret(string_length(_ed2.text), false);
    _t.eq("scroll_x advances when caret goes beyond the visible width", _ed2._scroll_x > 0, true);

    _t.eq("edit default text omitted", struct_exists(gmforms_control_to_struct(gmforms_create(GMF_Edit, { name: "edPlain" })), "text"), false);

    // --- M3: combined round trip --------------------------------------------------------
    var _m3f = gmforms_create(GMF_Form, { name: "frmM3", width: 400, height: 300 });
    var _m3cb = _m3f.add(gmforms_create(GMF_CheckBox, { name: "cbM3", caption: "Enable" }));
    _m3cb._ev_names[$ "on_change"] = "cbM3_Change";
    var _m3sp = _m3f.add(gmforms_create(GMF_Splitter, { name: "splM3", align: "left" }));
    var _m3vp = _m3f.add(gmforms_create(GMF_Viewport, { name: "vpM3", align: "client" }));
    _m3vp._ev_names[$ "on_draw"] = "vpM3_Draw";
    var _m3ed = _m3f.add(gmforms_create(GMF_Edit, { name: "edM3", text: "hi" }));

    var _m3json1 = gmforms_form_to_json(_m3f);
    var _m3tree2 = gmforms_load_form_json(_m3json1, { cbM3_Change: function(_s, _v) {}, vpM3_Draw: function(_s, _c) {} });
    var _m3json2 = gmforms_form_to_json(_m3tree2);
    _t.eq("M3 round trip is stable", _m3json1, _m3json2);
    _t.eq("M3 checkbox event resolved", is_callable(_m3tree2.find("cbM3").on_change), true);
    _t.eq("M3 viewport event resolved", is_callable(_m3tree2.find("vpM3").on_draw), true);

    // --- M4: undo stack ------------------------------------------------------------------
    var _us = new GMF_UndoStack(3);
    var _doc = { a: 1, b: "x", arr: [10, 20] };
    var _uc = { changes: 0 };
    _us.on_change = method(_uc, function(_s) { changes++; });
    _t.eq("undo: empty can't undo", _us.can_undo(), false);
    _us.set_value(_doc, "a", 2);
    _t.eq("undo: set_value applies", _doc.a, 2);
    _t.eq("undo: can undo after set", _us.can_undo(), true);
    _t.eq("undo: default label", _us.undo_label(), "Set a");
    _t.eq("undo: undo() returns true", _us.undo(), true);
    _t.eq("undo: value reverted", _doc.a, 1);
    _t.eq("undo: can redo", _us.can_redo(), true);
    _us.redo();
    _t.eq("undo: redo re-applies", _doc.a, 2);
    _us.set_value(_doc.arr, 1, 99, "Arr");
    _t.eq("undo: array index write", _doc.arr[1], 99);
    _us.undo();
    _t.eq("undo: array index undo", _doc.arr[1], 20);
    _us.set_value(_doc, "b", "y");
    _t.eq("undo: new push clears redo", _us.can_redo(), false);
    _t.eq("undo: on_change fired", _uc.changes > 0, true);

    // command structs: functions in the literal see the literal's own fields
    var _cmdlog = { s: "" };
    _us.clear();
    _us.execute({ log: _cmdlog, do_fn: function() { log.s += "d"; }, undo_fn: function() { log.s += "u"; }, label: "L" });
    _us.undo(); _us.redo();
    _t.eq("undo: execute/undo/redo run the command", _cmdlog.s, "dud");

    // grouping: one step, undone in reverse order
    _us.clear();
    _doc.a = 0;
    _us.begin_group("drag");
    _us.set_value(_doc, "a", 1);
    _us.begin_group("nested");
    _us.set_value(_doc, "a", 2);
    _us.end_group();
    _us.set_value(_doc, "a", 3);
    _us.end_group();
    _t.eq("undo: group applies all", _doc.a, 3);
    _t.eq("undo: group label is the outer one", _us.undo_label(), "drag");
    _us.undo();
    _t.eq("undo: group undone as one step", _doc.a, 0);
    _t.eq("undo: nothing left after group undo", _us.can_undo(), false);
    _us.redo();
    _t.eq("undo: group redone in order", _doc.a, 3);
    _us.begin_group("empty");
    _us.end_group();
    _t.eq("undo: empty group records nothing", _us.undo_label(), "drag");

    // limit
    _us.clear();
    for (var _i = 1; _i <= 5; _i++) _us.set_value(_doc, "a", _i * 10);
    var _steps = 0;
    while (_us.undo()) _steps++;
    _t.eq("undo: limit keeps only the newest steps", _steps, 3);
    _t.eq("undo: limit - oldest kept state", _doc.a, 20);

    // pushes during undo/redo are ignored (safe for on_change handlers that record)
    _us.clear();
    var _reent = { stack: _us, doc: _doc };
    _us.execute({ ctx: _reent, do_fn: function() { ctx.doc.a = 7; }, undo_fn: function() { ctx.doc.a = 6; ctx.stack.set_value(ctx.doc, "b", "z"); } });
    _us.undo();
    _t.eq("undo: push during undo ignored", _us.can_redo() && !_us.can_undo(), true);

    // snapshot mode
    _us.clear();
    var _snapdoc = { v: 1 };
    var _before = json_stringify(_snapdoc);
    _snapdoc.v = 5;
    _us.push_snapshot("snap", _before, json_stringify(_snapdoc), method({ d: _snapdoc }, function(_json) { d.v = json_parse(_json).v; }));
    _us.undo();
    _t.eq("undo: snapshot restores before", _snapdoc.v, 1);
    _us.redo();
    _t.eq("undo: snapshot restores after", _snapdoc.v, 5);
    _us.push("not a command");
    _t.eq("undo: invalid push ignored", _us.undo_label(), "snap");

    // --- M4: PropertyGrid ---------------------------------------------------------------
    var _pgf = gmforms_create(GMF_Form, { width: 400, height: 400 });
    var _pg = _pgf.add(gmforms_create(GMF_PropertyGrid, { name: "pgTest", align: "client" }));
    _pgf.layout();
    _t.eq("pg: empty grid has no rows", _pg.row_count(), 0);

    var _obj = { name: "Goblin", hp: 12, speed: 1.5, alive: true, stats: { str: 3, dex: 4 }, loot: ["gold", "dagger"], _hidden: 1, fn: function() {} };
    _pg.bind(_obj);
    // inferred, sorted, "_" and functions skipped: alive, hp, loot, name, speed, stats
    _t.eq("pg: inferred row count", _pg.row_count(), 6);
    _t.eq("pg: rows sorted by name", _pg.get_row(0).label, "alive");
    _t.eq("pg: bool inferred", _pg.get_row(_pg.find_row("alive")).meta.type, "bool");
    _t.eq("pg: number inferred as real", _pg.get_row(_pg.find_row("hp")).meta.type, "real");
    _t.eq("pg: string inferred", _pg.get_row(_pg.find_row("name")).meta.type, "string");
    _t.eq("pg: struct expandable", _pg.get_row(_pg.find_row("stats")).expandable, true);
    _t.eq("pg: underscore field hidden", _pg.find_row("_hidden"), -1);
    _t.eq("pg: function field hidden", _pg.find_row("fn"), -1);

    _pg.toggle_expand(_pg.find_row("stats"));
    _t.eq("pg: expanding a struct adds its fields", _pg.row_count(), 8);
    _t.eq("pg: nested path", _pg.get_row(_pg.find_row("stats.dex")).depth, 1);
    _pg.set_expanded("loot", true);
    _t.eq("pg: array items shown", _pg.get_row(_pg.find_row("loot.1")).label, "[1]");
    _t.eq("pg: array item value", _pg.get_row_value(_pg.find_row("loot.1")), "dagger");

    var _pgc = { n: 0, key: "", old: undefined, nv: undefined, owner: undefined };
    _pg.on_change = method(_pgc, function(_s, _k, _o, _nv, _ow) { n++; key = _k; old = _o; nv = _nv; owner = _ow; });

    _pg.activate(_pg.find_row("alive"));
    _t.eq("pg: activate toggles bool", _obj.alive, false);
    _t.eq("pg: on_change key", _pgc.key, "alive");
    _t.eq("pg: on_change old/new", _pgc.old == true && _pgc.nv == false, true);

    _pg.set_row_value(_pg.find_row("stats.str"), 9);
    _t.eq("pg: nested write", _obj.stats.str, 9);
    _t.eq("pg: on_change owner is the nested struct", _pgc.owner, _obj.stats);
    _pg.set_row_value(_pg.find_row("loot.0"), "silver");
    _t.eq("pg: array item write", _obj.loot[0], "silver");
    var _before_n = _pgc.n;
    _pg.set_row_value(_pg.find_row("hp"), 12);
    _t.eq("pg: unchanged value doesn't fire on_change", _pgc.n, _before_n);

    // in-place text editing
    _pg.focus();
    _t.eq("pg: begin_edit on a string row", _pg.begin_edit(_pg.find_row("name")), true);
    _t.eq("pg: editor shows the value", _pg._editor.text, "Goblin");
    _pg.key_char("X");   // replaces the selected text
    _pg.key_down(vk_enter);
    _t.eq("pg: Enter commits the edit", _obj.name, "X");
    _t.eq("pg: not editing after commit", _pg.is_editing(), false);
    _pg.begin_edit(_pg.find_row("name"));
    _pg.key_char("Y");
    _pg.key_down(vk_escape);
    _t.eq("pg: Escape cancels the edit", _obj.name, "X");
    _pg.select(_pg.find_row("speed"));
    _pg.key_char("2");   // typing on a selected row starts an edit
    _t.eq("pg: typing starts an edit", _pg.is_editing(), true);
    _pg.key_char("."); _pg.key_char("5");
    _pgf.set_focus(undefined);
    _t.eq("pg: focus loss commits", _obj.speed, 2.5);
    _pg.begin_edit(_pg.find_row("hp"));
    _pg._editor.text = "abc";
    _pg.commit_edit();
    _t.eq("pg: invalid number is rejected", _obj.hp, 12);

    // metadata: enum with labels, int range + step, readonly, categories
    var _unit = { kind: 1, level: 5, id: 42, color: c_red, tint: undefined };
    var _meta = [
        { name: "kind",  type: "enum", values: [0, 1, 2], labels: ["Orc", "Elf", "Dwarf"], category: "Main" },
        { name: "level", type: "int", min: 1, max: 10, step: 2, category: "Main" },
        { name: "id",    type: "int", readonly: true },
        { name: "color", type: "color", category: "Look" },
        { name: "tint",  type: "color", category: "Look" },
    ];
    _pg.bind(_unit, _meta);
    // uncategorised first: id, #Main, kind, level, #Look, color, tint
    _t.eq("pg: metadata row count incl. categories", _pg.row_count(), 7);
    _t.eq("pg: uncategorised rows come first", _pg.get_row(0).label, "id");
    _t.eq("pg: category header", _pg.get_row(1).kind, "category");
    _t.eq("pg: enum label shown", _pg._value_text(_pg.get_row(_pg.find_row("kind"))), "Elf");
    _pg.activate(_pg.find_row("kind"));
    _t.eq("pg: enum cycles forward", _unit.kind, 2);
    _pg.activate(_pg.find_row("kind"));
    _t.eq("pg: enum wraps", _unit.kind, 0);
    _pg._key_side(_pg.find_row("kind"), -1);
    _t.eq("pg: enum cycles back", _unit.kind, 2);
    _pg._key_side(_pg.find_row("level"), 1);
    _t.eq("pg: int steps by step", _unit.level, 7);
    _pg._key_side(_pg.find_row("level"), 1); _pg._key_side(_pg.find_row("level"), 1);
    _t.eq("pg: int clamps to max", _unit.level, 10);
    _pg.begin_edit(_pg.find_row("level"));
    _pg._editor.text = "-4.6";
    _pg.commit_edit();
    _t.eq("pg: typed int clamps to min", _unit.level, 1);
    _pg.set_row_value(_pg.find_row("id"), 7);
    _t.eq("pg: readonly row not written", _unit.id, 42);
    _t.eq("pg: readonly row can't be edited", _pg.begin_edit(_pg.find_row("id")), false);
    _t.eq("pg: colour shown as hex", _pg._value_text(_pg.get_row(_pg.find_row("color"))), "#FF0000");
    _pg.begin_edit(_pg.find_row("tint"));
    _pg._editor.text = "#10ff80";
    _pg.commit_edit();
    _t.eq("pg: hex parsed to colour", _unit.tint, make_colour_rgb(16, 255, 128));
    _t.eq("pg: colour hex round trip", gmforms_color_to_hex(gmforms_color_from_hex("#12AB9C")), "#12AB9C");
    _t.eq("pg: bad hex rejected", gmforms_color_from_hex("#12XB9C"), undefined);
    _pg.toggle_expand(_pg.find_row("#Main"));
    _t.eq("pg: collapsing a category hides its rows", _pg.find_row("kind"), -1);
    _t.eq("pg: collapsed row count", _pg.row_count(), 5);
    _pg.set_expanded("#Main", true);
    _t.eq("pg: expanding it again", _pg.find_row("kind") >= 0, true);

    // real with range + fractional step: no float drift
    var _phys = { f: 0.1 };
    _pg.bind(_phys, [{ name: "f", type: "real", range: { min: 0, max: 1, step: 0.1 } }]);
    _pg._key_side(0, 1); _pg._key_side(0, 1);
    _t.eq("pg: 0.1 steps don't drift", _phys.f, 0.3);
    _t.eq("pg: number formatting", gmforms_format_number(0.3), "0.3");
    _t.eq("pg: integer formatting", gmforms_format_number(12), "12");

    // undo integration
    var _pu = new GMF_UndoStack();
    _pg.undo = _pu;
    _pg.bind(_unit, _meta);
    _pg.set_row_value(_pg.find_row("level"), 4);
    _pg.activate(_pg.find_row("kind"));
    _t.eq("pg+undo: two steps recorded", _pu.undo_label(), "Set kind");
    _pu.undo();
    _t.eq("pg+undo: enum undone", _unit.kind, 2);
    _pu.undo();
    _t.eq("pg+undo: int undone", _unit.level, 1);
    _pu.redo();
    _t.eq("pg+undo: redo", _unit.level, 4);
    _t.eq("pg+undo: on_change fires on redo too", _pgc.key, "level");

    // bind_control: the Object Inspector case, written through set() so layout follows
    var _bf = gmforms_create(GMF_Form, { width: 300, height: 200 });
    var _bb = _bf.add(gmforms_create(GMF_Button, { name: "btnInspect", left: 10, top: 10 }));
    _bf.layout();
    _pg.undo = undefined;
    _pg.bind_control(_bb);
    _t.eq("pg control: events not listed", _pg.find_row("onClick"), -1);
    _t.eq("pg control: name row", _pg.get_row_value(_pg.find_row("name")), "btnInspect");
    _pg.set_row_value(_pg.find_row("left"), 50);
    _bf.layout();
    _t.eq("pg control: left written through set()", _bb.left, 50);
    _t.eq("pg control: anchors re-captured", _bb._anc.l, 50);
    _pg.set_row_value(_pg.find_row("align"), "client");
    _bf.layout();
    _t.eq("pg control: align applied by layout", _bb.width, 300);
    _pg.set_expanded("margin", true);
    _pg.set_row_value(_pg.find_row("margin.l"), 8);
    _bf.layout();
    _t.eq("pg control: nested margin write re-lays out", _bb.left, 8);
    _pg.begin_edit(_pg.find_row("anchors"));
    _pg._editor.text = "Right, bottom";
    _pg.commit_edit();
    _t.eq("pg control: anchors parsed", gmforms_value_equals(_bb.anchors, ["right", "bottom"]), true);

    _pg.bind(undefined);
    _t.eq("pg: unbind clears rows", _pg.row_count(), 0);
    _t.eq("pg: registered class name", gmforms_control_to_struct(gmforms_create(GMF_PropertyGrid, { name: "pgPlain" }))[$ "class"], "PropertyGrid");
    var _pgjson = gmforms_form_to_json(_pgf);
    _t.eq("pg: in-place editor not serialized", string_pos("\"Edit\"", _pgjson), 0);
    _t.eq("pg: form with grid round-trips", gmforms_form_to_json(gmforms_load_form_json(_pgjson)), _pgjson);

    // --- M4: tile editor sample model -----------------------------------------------------
    var _td = demo_tiles_new_doc(8, 6);
    var _tu = new GMF_UndoStack();
    _t.eq("tiles: border is stone", _td.cells[0].t, 2);
    _tu.begin_group("stroke");
    demo_tiles_paint(_td, _tu, 1, 1, 4);
    demo_tiles_paint(_td, _tu, 2, 1, 4);
    _t.eq("tiles: painting the same tile is a no-op", demo_tiles_paint(_td, _tu, 2, 1, 4), false);
    _t.eq("tiles: out of range paint ignored", demo_tiles_paint(_td, _tu, 99, 1, 4), false);
    _tu.end_group();
    _t.eq("tiles: painted", _td.cells[1 * 8 + 2].t, 4);
    _tu.undo();
    _t.eq("tiles: stroke undone as one step", _td.cells[1 * 8 + 1].t + _td.cells[1 * 8 + 2].t, 0);
    demo_tiles_clear(_td, _tu);
    _t.eq("tiles: clear empties cells", _td.cells[0].t, -1);
    _tu.undo();
    _t.eq("tiles: clear undone from snapshot", _td.cells[0].t, 2);
    _td.cells[9].tag = "chest";
    var _tjson = demo_tiles_to_json(_td);
    var _td2 = demo_tiles_from_json(_tjson);
    _t.eq("tiles: JSON round trip", demo_tiles_to_json(_td2), _tjson);
    _t.eq("tiles: bools survive JSON", is_bool(_td2.info.wrap_edges), true);
    _t.eq("tiles: bad document rejected", demo_tiles_from_json("{\"format\":\"nope\"}"), undefined);

    // --- M5: popup layer + menus ----------------------------------------------------------
    var _mf = gmforms_create(GMF_Form, { width: 600, height: 400 });
    var _mlog = { clicks: 0, last: "", sender: undefined, under: 0 };
    var _mfn = method(_mlog, function(_s, _it) { clicks++; last = _it.caption; sender = _s; });
    var _mb = _mf.add(gmforms_create(GMF_MenuBar, { name: "mbMain" }));
    _mb.add_menu("File", [
        gmforms_menu_item("New", _mfn, { shortcut: "Ctrl+N" }),
        gmforms_menu_separator(),
        gmforms_menu_item("Locked", _mfn, { enabled: false, shortcut: "Ctrl+L" }),
        gmforms_submenu("Recent", [ gmforms_menu_item("a.map", _mfn), gmforms_menu_item("b.map", _mfn) ]),
        gmforms_menu_item("Exit", _mfn),
    ]);
    _mb.add_menu("Edit", [ gmforms_menu_item("Undo", _mfn, { shortcut: "Ctrl+Shift+Z" }) ]);
    var _under = _mf.add(gmforms_create(GMF_Button, { name: "btnUnder", left: 10, top: 40, width: 400, height: 100 }));
    _under.on_click = method(_mlog, function(_s) { under++; });
    _mf.layout();

    _mf.simulate_click(10, 12);
    _t.eq("menu: pressing a caption opens its menu", array_length(_mf.popups), 1);
    _t.eq("menu: menubar reports open", _mb.is_open(), true);
    _t.eq("menu: popup is hit-tested above the tree", _mf.control_at(20, 30), _mf.top_popup());
    _mf.simulate_key(vk_escape);
    _t.eq("menu: Escape closes it", array_length(_mf.popups), 0);

    _mf.simulate_click(10, 12);
    _mf.simulate_click(380, 130);   // on btnUnder, outside the menu
    _t.eq("menu: outside click closes", array_length(_mf.popups), 0);
    _t.eq("menu: outside click is consumed", _mlog.under, 0);

    _mf.simulate_click(10, 12);
    _mf.simulate_click(20, 30);     // "New"
    _t.eq("menu: item click fires on_click", _mlog.last, "New");
    _t.eq("menu: sender is the menu bar", _mlog.sender, _mb);
    _t.eq("menu: item click closes the menu", array_length(_mf.popups), 0);

    _mf.simulate_click(10, 12);
    _mf.simulate_click(20, 64);     // "Locked" (disabled)
    _t.eq("menu: disabled item does nothing", _mlog.clicks, 1);
    _mf.close_popups();

    _mf.simulate_click(10, 12);
    _mf.simulate_move(20, 88);      // hover "Recent"
    _t.eq("menu: hovering a submenu item opens it", array_length(_mf.popups), 2);
    _mf.simulate_key(vk_left);
    _t.eq("menu: Left closes the submenu", array_length(_mf.popups), 1);
    _mf.simulate_key(vk_escape);
    _t.eq("menu: Escape after that closes the menu", array_length(_mf.popups), 0);

    _mb.open_menu(0, true);
    _t.eq("menu: keyboard open selects the first item", _mf.top_popup()._hot, 0);
    _mf.simulate_key(vk_down);
    _t.eq("menu: Down skips separators and disabled items", _mf.top_popup()._hot, 3);
    _mf.simulate_key(vk_right);
    _t.eq("menu: Right opens a submenu with its first item selected", _mf.top_popup()._hot, 0);
    _mf.simulate_key(vk_left);
    _mf.simulate_key(vk_down);
    _mf.simulate_key(vk_right);     // on "Exit": no submenu -> next menu-bar menu
    _t.eq("menu: Right on a plain item moves to the next menu", _mb._open_index, 1);
    _mf.simulate_key(vk_left);
    _t.eq("menu: Left on a root menu moves to the previous menu", _mb._open_index, 0);
    _mf.simulate_key(vk_enter);
    _t.eq("menu: Enter activates the selected item", _mlog.last, "New");

    _mf.simulate_click(10, 12);
    var _edit_x = 4 + _mb._caption_rects()[1].x + 2;
    _mf.simulate_move(_edit_x, 12);
    _t.eq("menu: hovering another caption switches menus", _mb._open_index, 1);
    _mf.simulate_key(vk_tab);
    _t.eq("menu: Tab closes popups", array_length(_mf.popups), 0);

    var _clicks_before = _mlog.clicks;
    _t.eq("shortcut: Ctrl+N handled", _mf.dispatch_shortcut(ord("N"), true, false, false), true);
    _t.eq("shortcut: fired the item", _mlog.clicks, _clicks_before + 1);
    _t.eq("shortcut: disabled item ignored", _mf.dispatch_shortcut(ord("L"), true, false, false), false);
    _t.eq("shortcut: modifiers must match", _mf.dispatch_shortcut(ord("Z"), true, false, false), false);
    _mf.dispatch_shortcut(ord("Z"), true, true, false);
    _t.eq("shortcut: Ctrl+Shift+Z", _mlog.last, "Undo");
    _t.eq("shortcut: parse F5", gmforms_parse_shortcut("F5").key, vk_f5);
    var _psc = gmforms_parse_shortcut("Ctrl+Alt+Del");
    _t.eq("shortcut: parse Ctrl+Alt+Del", _psc.ctrl && _psc.alt && !_psc.shift && _psc.key == vk_delete, true);
    _t.eq("shortcut: bad modifier rejected", gmforms_parse_shortcut("Hyper+X"), undefined);
    _t.eq("shortcut: plain letter is not a shortcut key", gmforms_is_shortcut_key(ord("S"), false, false), false);
    _t.eq("shortcut: Ctrl+letter is", gmforms_is_shortcut_key(ord("S"), true, false), true);
    _t.eq("shortcut: F3 alone is", gmforms_is_shortcut_key(vk_f3, false, false), true);
    _t.eq("shortcut: Ctrl itself is not", gmforms_is_shortcut_key(vk_control, true, false), false);

    // context menu
    var _ctx = _mf.add(gmforms_create(GMF_Panel, { name: "pnlCtx", left: 420, top: 200, width: 150, height: 100 }));
    _ctx.popup_menu = gmforms_create(GMF_PopupMenu, { items: [ gmforms_menu_item("Rename", _mfn), gmforms_menu_item("Delete", _mfn) ] });
    _mf.simulate_click(450, 220, mb_right);
    _t.eq("context menu: right-click opens popup_menu", _mf.top_popup(), _ctx.popup_menu);
    _t.eq("context menu: popup_component is the clicked control", _ctx.popup_menu.popup_component, _ctx);
    _mf.simulate_click(460, 230);
    _t.eq("context menu: item fires with the menu as sender", _mlog.sender == _ctx.popup_menu && _mlog.last == "Rename", true);

    // --- M5: ComboBox (+ dropdown popup) ---------------------------------------------------
    var _cbo = _mf.add(gmforms_create(GMF_ComboBox, { name: "cboColor", left: 10, top: 300, width: 150, items: ["Red", "Green", "Blue"] }));
    var _cboc = { n: 0, last: -1 };
    _cbo.on_change = method(_cboc, function(_s, _i) { n++; last = _i; });
    _mf.simulate_click(20, 310);
    _t.eq("combo: click opens the dropdown", _mf.top_popup().class_name, "DropDownList");
    _t.eq("combo: dropdown opens below", _mf.top_popup().top, 324);
    _mf.simulate_click(20, 324 + 1 + 20 + 5);   // "Green"
    _t.eq("combo: picking an item selects it", _cbo.item_index, 1);
    _t.eq("combo: text", _cbo.get_text(), "Green");
    _t.eq("combo: pick fires on_change", _cboc.last, 1);
    _t.eq("combo: pick closes the dropdown", array_length(_mf.popups), 0);
    _mf.simulate_click(20, 310);
    _mf.simulate_click(20, 310);
    _t.eq("combo: clicking the combo again closes it", array_length(_mf.popups), 0);
    _mf.simulate_click(20, 310);
    _mf.simulate_click(590, 390);
    _t.eq("combo: outside click closes without changing", _cbo.item_index == 1 && array_length(_mf.popups) == 0, true);
    _cbo.key_down(vk_down);
    _t.eq("combo: Down while closed selects the next item", _cbo.item_index, 2);
    _cbo.drop_down();
    _cbo.set_visible(false);
    _t.eq("popup: hiding the owner closes its popup", array_length(_mf.popups), 0);
    _cbo.set_visible(true);
    _cbo.set_bounds(10, 370, 150, 24);
    _mf.layout();
    _cbo.drop_down();
    _t.eq("combo: dropdown flips above when there's no room below", _mf.top_popup().top < 370, true);
    _mf.close_popups();

    // --- M5: ListBox ---------------------------------------------------------------------
    var _lb = _mf.add(gmforms_create(GMF_ListBox, { name: "lbItems", left: 250, top: 150, width: 150, height: 100 }));
    for (var _i = 0; _i < 20; _i++) _lb.add_item("item " + string(_i));
    var _lbc = { changes: 0, act: 0 };
    _lb.on_change = method(_lbc, function(_s, _i) { changes++; });
    _lb.on_activate = method(_lbc, function(_s, _i) { act++; });
    _mf.simulate_click(260, 150 + 1 + 40 + 5);
    _t.eq("listbox: click selects the row", _lb.item_index, 2);
    _t.eq("listbox: click focuses it", _mf.focused, _lb);
    _mf.simulate_click(260, 150 + 1 + 40 + 5);
    _t.eq("listbox: double-click activates", _lbc.act, 1);
    _mf.simulate_key(vk_down);
    _t.eq("listbox: Down", _lb.item_index, 3);
    _mf.simulate_key(vk_end);
    _t.eq("listbox: End selects the last item", _lb.item_index, 19);
    _t.eq("listbox: End scrolls it into view", _lb._scroll_y, 20 * 20 - 98);
    _lb.mouse_wheel(-1);
    _t.eq("listbox: wheel scrolls", _lb._scroll_y, 20 * 20 - 98 - 60);
    _lb.remove_item(0);
    _t.eq("listbox: removing above keeps the same item selected", _lb.get_text(), "item 19");
    _t.eq("listbox: on_change count", _lbc.changes, 3);

    // --- M5: TreeView ----------------------------------------------------------------------
    var _tv = _mf.add(gmforms_create(GMF_TreeView, { name: "tvScene", left: 10, top: 150, width: 200, height: 140 }));
    var _na = _tv.add_node(undefined, "A");
    var _na1 = _tv.add_node(_na, "A1");
    var _na2 = _tv.add_node(_na, "A2");
    var _na2a = _tv.add_node(_na2, "A2a");
    _tv.add_node(undefined, "B");
    var _tvc = { node: undefined, n: 0 };
    _tv.on_change = method(_tvc, function(_s, _node) { node = _node; n++; });
    _t.eq("tree: collapsed roots only", _tv._item_count(), 2);
    _mf.simulate_click(16, 160);        // A's expander
    _t.eq("tree: expander click expands", _tv._item_count(), 4);
    _t.eq("tree: expander click doesn't select", _tv.selected_node, undefined);
    _mf.simulate_click(60, 150 + 1 + 40 + 5);   // "A2"
    _t.eq("tree: click selects a node", _tvc.node, _na2);
    _mf.simulate_key(vk_right);
    _t.eq("tree: Right expands", _tv._item_count(), 5);
    _mf.simulate_key(vk_right);
    _t.eq("tree: Right again goes to the first child", _tv.selected_node, _na2a);
    _mf.simulate_key(vk_left);
    _t.eq("tree: Left on a leaf goes to the parent", _tv.selected_node, _na2);
    _mf.simulate_key(vk_left);
    _t.eq("tree: Left collapses", _tv._item_count(), 4);
    _tv.set_expanded(_na, false);
    _tv.select_node(_na2a);
    _t.eq("tree: select_node expands ancestors", _tv._item_count(), 5);
    _t.eq("tree: select_node selects", _tv.get_row_node(_tv.item_index), _na2a);
    _tv.remove_node(_na2);
    _t.eq("tree: removing the selected subtree clears the selection", _tv.selected_node, undefined);
    _t.eq("tree: removed rows", _tv._item_count(), 3);
    _t.eq("tree: node_parent", _tv.node_parent(_na1), _na);

    // --- M5: ColorPicker -----------------------------------------------------------------------
    var _cp = _mf.add(gmforms_create(GMF_ColorPicker, { name: "cpTint", left: 250, top: 260, color: c_white }));
    var _cpc = { n: 0 };
    _cp.on_change = method(_cpc, function(_s, _c) { n++; });
    _mf.simulate_click(260, 270);
    var _cpop = _mf.top_popup();
    _t.eq("colour: click opens the popup", _cpop.class_name, "ColorPopup");
    _t.eq("colour: popup flips above when needed", _cpop.top, 260 - 232);
    _mf.simulate_click(_cpop._sx + 11 + 6 * 23 + 5, _cpop._sy + 156 + 5);   // preset 6 = c_red
    _t.eq("colour: preset sets the colour", _cp.color, c_red);
    _t.eq("colour: on_change fired", _cpc.n, 1);
    _cpop._drag = "sv";
    _cpop._drag_to(8, 8 + 140);
    _t.eq("colour: bottom of the SV square is black", _cpop.get_color(), c_black);
    _cpop._drag = "";
    _mf.simulate_key(vk_escape);
    _t.eq("colour: Escape closes", array_length(_mf.popups), 0);

    // --- M5: PropertyGrid popup editors --------------------------------------------------------
    var _pgu = new GMF_UndoStack();
    var _gunit = { kind: 0, tint: c_red };
    _pg.undo = _pgu;
    _pg.bind(_gunit, [
        { name: "kind", type: "enum", values: [0, 1, 2], labels: ["Orc", "Elf", "Dwarf"] },
        { name: "tint", type: "color" },
    ]);
    _pgf.layout();
    _pgf.simulate_click(_pg.name_width + 30, 5);
    _t.eq("pg: enum click opens a dropdown", _pgf.top_popup().class_name, "DropDownList");
    _pgf.simulate_click(_pg.name_width + 30, 22 + 1 + 20 + 5);    // "Elf"
    _t.eq("pg: dropdown pick writes the value", _gunit.kind, 1);
    _t.eq("pg: dropdown pick is one undo step", _pgu.undo_label(), "Set kind");
    _pgf.simulate_click(_pg.name_width + 8, 22 + 5);                // tint swatch
    var _gpop = _pgf.top_popup();
    _t.eq("pg: colour swatch opens the colour popup", _gpop.class_name, "ColorPopup");
    _gpop.source._cp_set(c_blue, false);
    _t.eq("pg: live colour preview writes through", _gunit.tint, c_blue);
    _t.eq("pg: live preview records no undo step", _pgu.undo_label(), "Set kind");
    _gpop.source._cp_set(c_lime, true);
    _t.eq("pg: release records one step", _pgu.undo_label(), "Set tint");
    _pgu.undo();
    _t.eq("pg: undo restores the colour from before the popup", _gunit.tint, c_red);
    _pgf.close_popups();
    _pg.undo = undefined;
    _pg.bind(undefined);

    // --- M5: TabControl ---------------------------------------------------------------------------
    var _tf = gmforms_create(GMF_Form, { width: 300, height: 200 });
    var _tc = _tf.add(gmforms_create(GMF_TabControl, { name: "tabs", align: "client" }));
    var _tp0 = _tc.add_page("General");
    var _tp1 = _tc.add_page("Physics");
    var _tp2 = _tc.add_page("Audio");
    _tp1.add(gmforms_create(GMF_Label, { name: "lblOnPhysics", caption: "hi" }));
    _tf.layout();
    _t.eq("tabs: first page visible", _tp0.visible && !_tp1.visible && !_tp2.visible, true);
    _t.rect("tabs: page fills the area under the tabs", _tp0, 1, 26, 298, 173);
    var _trs = _tc._tab_rects();
    _tf.simulate_click(_trs[2].x + 5, 10);
    _t.eq("tabs: clicking a tab switches", _tc.tab_index, 2);
    _t.eq("tabs: only the active page is visible", !_tp0.visible && _tp2.visible, true);
    _tf.simulate_key(vk_left);
    _t.eq("tabs: Left when focused", _tc.tab_index, 1);
    _tc.tab_index = 0;          // assigned directly: layout re-syncs the pages
    _tc.invalidate_layout();
    _tf.layout();
    _t.eq("tabs: direct tab_index assignment syncs on layout", _tp0.visible && !_tp1.visible, true);
    _tc.set_tab_index(1);
    var _tjson1 = gmforms_form_to_json(_tf);
    var _tf2 = gmforms_load_form_json(_tjson1);
    _t.eq("tabs: JSON round trip", gmforms_form_to_json(_tf2), _tjson1);
    _tf2.layout();
    _t.eq("tabs: loaded tab_index", _tf2.find("tabs").tab_index, 1);
    _t.eq("tabs: loaded page visibility", _tf2.find("tabs").get_page(1).visible && !_tf2.find("tabs").get_page(0).visible, true);

    // --- M5: Toolbar ---------------------------------------------------------------------------------
    var _tbf = gmforms_create(GMF_Form, { width: 400, height: 100 });
    var _tb = _tbf.add(gmforms_create(GMF_Toolbar, { name: "tbMain" }));
    var _tb1 = _tb.add_button("One");
    var _tbs = _tb.add_separator();
    var _tb2 = _tb.add_button("Two");
    _tbf.layout();
    _t.eq("toolbar: first button at the padding", _tb1.left, 4);
    _t.eq("toolbar: centred vertically", _tb1.top, 5);
    _t.eq("toolbar: separator after it", _tbs.left, _tb1.left + _tb1.width + 4);
    _t.eq("toolbar: next button after the separator", _tb2.left, _tbs.left + _tbs.width + 4);
    _tb1.set_visible(false);
    _tbf.layout();
    _t.eq("toolbar: hidden items take no space", _tbs.left, 4);

    // --- M5: SpinEdit / Slider --------------------------------------------------------------------------
    var _se = gmforms_create(GMF_SpinEdit, { name: "seCount", min_value: 0, max_value: 10, step: 2 });
    var _sec = { n: 0 };
    _se.on_change = method(_sec, function(_s, _v) { n++; });
    _se.set_value(5);
    _t.eq("spin: set_value", _se.value, 5);
    _t.eq("spin: text follows value", _se.text, "5");
    _se.set_value(99);
    _t.eq("spin: clamps to max", _se.value, 10);
    _se.text = "7";
    _se.commit();
    _t.eq("spin: typed text commits", _se.value, 7);
    _se.text = "abc";
    _se.commit();
    _t.eq("spin: invalid text reverts", _se.text, "7");
    _se.key_down(vk_down);
    _t.eq("spin: Down steps", _se.value, 5);
    _se.mouse_down(_se.width - 4, 3, mb_left);
    _t.eq("spin: top button steps up", _se.value, 7);
    _t.eq("spin: on_change per value change", _sec.n, 5);
    _se.text = "";
    _se._caret = 0; _se._sel_anchor = 0;
    _se.key_char("4"); _se.key_char("x");
    _t.eq("spin: only numeric characters are typed", _se.text, "4");
    var _sd = gmforms_create(GMF_SpinEdit, { decimals: 2, max_value: 100 });
    _sd.set_value(3.14159);
    _t.eq("spin: rounds to decimals", _sd.text, "3.14");

    var _sl = gmforms_create(GMF_Slider, { name: "slVol", width: 110, step: 5 });
    _sl.set_value(42);
    _t.eq("slider: snaps to step", _sl.value, 40);
    _t.eq("slider: value at left end", _sl._value_at(5), 0);
    _t.eq("slider: value at right end", _sl._value_at(105), 100);
    _t.eq("slider: value in the middle", _sl._value_at(55), 50);
    _sl.key_down(vk_right);
    _t.eq("slider: Right steps", _sl.value, 45);
    _sl.key_down(vk_end);
    _t.eq("slider: End", _sl.value, 100);
    _sl.mouse_wheel(1);
    _t.eq("slider: wheel down steps down", _sl.value, 95);

    // --- M5: SpritePicker ------------------------------------------------------------------------------
    var _surf = surface_create(8, 8);
    surface_set_target(_surf);
    draw_clear(c_red);
    surface_reset_target();
    var _spr = sprite_create_from_surface(_surf, 0, 0, 8, 8, false, false, 0, 0);
    surface_free(_surf);
    var _sp = gmforms_create(GMF_SpritePicker, { name: "spIcon", sprites: [_spr], labels: ["red dot"] });
    _sp.set_item_index(1);
    _t.eq("sprite picker: select a sprite", _sp.sprite, _spr);
    _t.eq("sprite picker: label", _sp.get_text(), "red dot");
    _sp.set_item_index(0);
    _t.eq("sprite picker: (none)", _sp.get_text(), "(none)");
    _t.eq("sprite picker: project sprite list is an array", is_array(gmforms_sprite_list()), true);
    sprite_delete(_spr);

    // --- M5: serialization of the new classes --------------------------------------------------------
    var _sf5 = gmforms_create(GMF_Form, { name: "frmM5", width: 500, height: 400 });
    _sf5.add(gmforms_create(GMF_MenuBar, { name: "mb" }));
    var _stb = _sf5.add(gmforms_create(GMF_Toolbar, { name: "tb" }));
    _stb.add_button("Go");
    _stb.add_separator();
    _sf5.add(gmforms_create(GMF_ListBox, { name: "lb", items: ["a", "b"], item_index: 1 }));
    var _stv = _sf5.add(gmforms_create(GMF_TreeView, { name: "tv" }));
    _stv.add_node(_stv.add_node(undefined, "root"), "leaf");
    _sf5.add(gmforms_create(GMF_ComboBox, { name: "cb", items: ["x", "y"], item_index: 0 }));
    _sf5.add(gmforms_create(GMF_SpinEdit, { name: "se", value: 5 }));
    _sf5.add(gmforms_create(GMF_Slider, { name: "sl", value: 30 }));
    _sf5.add(gmforms_create(GMF_ColorPicker, { name: "cp", color: c_red }));
    _sf5.add(gmforms_create(GMF_SpritePicker, { name: "sp" }));
    var _stc = _sf5.add(gmforms_create(GMF_TabControl, { name: "tc" }));
    _stc.add_page("One");
    var _m5json = gmforms_form_to_json(_sf5);
    var _m5tree = gmforms_load_form_json(_m5json);
    _t.eq("M5 round trip is stable", gmforms_form_to_json(_m5tree), _m5json);
    _t.eq("M5 tree nodes survive JSON", _m5tree.find("tv").nodes[0].nodes[0].text, "leaf");
    _t.eq("M5 spin value survives JSON", _m5tree.find("se").value, 5);

    // --- M6: menu serialization, design-time loads, text files ---------------------------------
    var _mbf = gmforms_create(GMF_Form, { name: "frmMenus", width: 300, height: 200 });
    var _mbar = _mbf.add(gmforms_create(GMF_MenuBar, { name: "mb" }));
    var _mi = gmforms_menu_item("Save", undefined, { shortcut: "Ctrl+S" });
    _mi.on_click_name = "doSave";
    _mbar.menus = [ gmforms_submenu("File", [ _mi, gmforms_menu_separator(), gmforms_menu_item("Code only", function(_s, _it) {}) ]) ];
    var _mj = gmforms_form_to_json(_mbf);
    var _hs = { called: 0 };
    _hs.doSave = method(_hs, function(_s, _it) { called++; });
    var _mbf2 = gmforms_load_form_json(_mj, _hs);
    _t.eq("menus: JSON round trip", gmforms_form_to_json(_mbf2), _mj);
    var _mb2 = _mbf2.find("mb");
    _t.eq("menus: onClick bound by name drives the shortcut", _mb2.handle_shortcut(ord("S"), true, false, false), true);
    _t.eq("menus: handler called", _hs.called, 1);
    _t.eq("menus: separator survives", _mb2.menus[0].items[1].separator, true);
    _t.eq("menus: a code-only item is saved without onClick", string_count("onClick", _mj), 1);
    var _lc0 = gmforms_init().log_count;
    gmforms_load_form_json(_mj);
    _t.eq("load without a handlers struct is silent (design time)", gmforms_init().log_count, _lc0);
    gmforms_load_form_json(_mj, {});
    _t.eq("load with handlers warns about a missing one", gmforms_init().log_count, _lc0 + 1);

    gmforms_write_text_file("gmforms_test.txt", "line 1\nline 2");
    _t.eq("text file round trip", gmforms_read_text_file("gmforms_test.txt"), "line 1\nline 2");
    var _tb_buf = buffer_load("gmforms_test.txt");
    _t.eq("text file has no trailing NUL", buffer_get_size(_tb_buf), 13);
    buffer_delete(_tb_buf);
    file_delete("gmforms_test.txt");
    _t.eq("missing text file reads as undefined", gmforms_read_text_file("no_such_file.txt"), undefined);

    // --- M6: PropertyGrid arrays (+ / x) and double-click -----------------------------------------
    var _arrobj = { tags: ["a", "b"] };
    var _au = new GMF_UndoStack();
    _pg.undo = _au;
    _pg.bind(_arrobj, [{ name: "tags", type: "array", resizable: true, element: { type: "string" } }]);
    _pg.add_element(_pg.find_row("tags"));
    _t.eq("pg array: + appends a copy of the last item", gmforms_value_equals(_arrobj.tags, ["a", "b", "b"]), true);
    _pg.remove_element(_pg.find_row("tags.0"));
    _t.eq("pg array: x removes that item", gmforms_value_equals(_arrobj.tags, ["b", "b"]), true);
    _au.undo();
    _au.undo();
    _t.eq("pg array: both undoable", gmforms_value_equals(_arrobj.tags, ["a", "b"]), true);
    _pg.undo = undefined;

    _pg.bind_control(_mbar);
    var _mrow = _pg.find_row("menus");
    _t.eq("pg menus: MenuBar.menus is an editable list", _pg.get_row(_mrow).meta.resizable, true);
    _pg.add_element(_mrow);
    _t.eq("pg menus: + adds an item", _mbar.menus[1].caption, "Item");
    _pg.set_expanded("menus.1", true);
    _pg.set_row_value(_pg.find_row("menus.1.caption"), "Help");
    _t.eq("pg menus: caption edit", _mbar.menus[1].caption, "Help");
    _t.eq("pg menus: item row label shows the caption", _pg.get_row(_pg.find_row("menus.1")).label, "[1] Help");
    _pg.set_row_value(_pg.find_row("menus.1.onClick"), "mnuHelp_Click");
    _t.eq("pg menus: onClick edits the handler name", _mbar.menus[1].on_click_name, "mnuHelp_Click");

    var _dbl = { key: "" };
    _pg.bind({ alpha: "x", beta: "y" });
    _pg.on_dbl_click = method(_dbl, function(_s, _k, _o) { key = _k; });
    _pgf.layout();
    _pgf.simulate_click(20, 22 + 5);
    _pgf.simulate_click(20, 22 + 5);
    _t.eq("pg: double-click fires on_dbl_click with the key", _dbl.key, "beta");
    _pg.on_dbl_click = undefined;
    _pg.bind(undefined);

    // --- M6: handler stub generation ------------------------------------------------------------------
    var _cgf = gmforms_create(GMF_Form, { name: "frmCode", width: 300, height: 200 });
    var _cgb = _cgf.add(gmforms_create(GMF_Button, { name: "btnGo" }));
    _cgb._ev_names.on_click = "btnGo_Click";
    _cgb._ev_names.on_mouse_down = "btnGo_MouseDown";
    var _cgm = _cgf.add(gmforms_create(GMF_MenuBar, { name: "mbCode" }));
    var _cgq = gmforms_menu_item("Quit");
    _cgq.on_click_name = "mnuQuit_Click";
    _cgm.menus = [ gmforms_submenu("File", [ _cgq ]) ];
    var _src = gmforms_design_handlers_source(_cgf);
    _t.eq("codegen: constructor", string_pos("function frmCode_Handlers() constructor {", _src) > 0, true);
    _t.eq("codegen: click stub", string_pos("btnGo_Click = function(_sender) {", _src) > 0, true);
    _t.eq("codegen: mouse-down parameters", string_pos("btnGo_MouseDown = function(_sender, _x, _y, _button)", _src) > 0, true);
    _t.eq("codegen: menu item stub", string_pos("mnuQuit_Click = function(_sender, _item)", _src) > 0, true);
    var _edited = string_replace(_src, "btnGo_Click = function(_sender) {\n", "btnGo_Click = function(_sender) {\n        show_debug_message(\"user code\");\n");
    _cgb._ev_names.on_mouse_enter = "btnGo_Enter";
    var _src2 = gmforms_design_handlers_source(_cgf, _edited);
    _t.eq("codegen: existing code is kept", string_pos("user code", _src2) > 0, true);
    _t.eq("codegen: a new handler is appended", string_pos("btnGo_Enter = function(_sender)", _src2) > 0, true);
    _t.eq("codegen: nothing is duplicated", string_count("btnGo_Click = function", _src2), 1);
    _t.eq("codegen: appended inside the constructor", string_last_pos("}", _src2) > string_pos("btnGo_Enter", _src2), true);
    _t.eq("codegen: regenerating again changes nothing", gmforms_design_handlers_source(_cgf, _src2), _src2);
    _t.eq("codegen: handler identifiers", gmforms_design_ident("Open recent..."), "OpenRecent");

    // --- M6: the designer, driven through its real input path --------------------------------------
    var _da = new DesignerApp();
    _da.form.layout();
    _da.new_form({ name: "frmT", width: 400, height: 300 });
    var _cv = _da.canvas;
    _da.form.layout();
    _cv._layout_target();
    var _fx = _cv._sx + _cv.offset_x;
    var _fy = _cv._sy + _cv.offset_y;

    _cv.place_class = "Button";
    _da.form.simulate_click(_fx + 42, _fy + 38);
    var _db = _da.target.find("Button1");
    _t.eq("designer: click places a control", _db != undefined, true);
    _t.eq("designer: placed on the grid", _db.left == 40 && _db.top == 40, true);
    _t.eq("designer: caption defaults to the name", _db.caption, "Button1");
    _t.eq("designer: placing disarms the palette", _cv.place_class, "");
    _t.eq("designer: the new control is selected", _cv.selected, _db);
    _t.eq("designer: one undo step", _da.undo.undo_label(), "Create Button1");
    _t.eq("designer: structure tree", _da.tree.nodes[0].nodes[0].text, "Button1 : Button");
    _t.eq("designer: inspector bound", _da.props_grid.target, _db);

    _cv.place_class = "Panel";
    _da.form.simulate_drag(_fx + 160, _fy + 16, _fx + 360, _fy + 176);
    _t.rect("designer: drag out a new control's rect", _da.target.find("Panel1"), 160, 16, 200, 160);

    _da.form.simulate_drag(_fx + 60, _fy + 50, _fx + 220, _fy + 90);   // Button1 by (+160, +40)
    _db = _da.target.find("Button1");
    _t.eq("designer: dropping on a container reparents", _db.parent.name, "Panel1");
    _t.eq("designer: reparenting keeps the screen position", _db.left == 40 && _db.top == 64, true);
    _da.do_undo();
    _t.eq("designer: undo restores the old parent", _da.target.find("Button1").parent, _da.target);
    _t.eq("designer: undo keeps the selection by name", _cv.selected.name, "Button1");
    _da.do_redo();
    _t.eq("designer: redo", _da.target.find("Button1").parent.name, "Panel1");

    _da.form.set_focus(_cv);
    _cv.select(_da.target.find("Button1"));
    _da.form.simulate_key(vk_right);
    _t.eq("designer: arrow key nudges", _da.target.find("Button1").left, 41);
    _da.form.simulate_key(vk_delete);
    _t.eq("designer: Delete removes the selection", _da.target.find("Button1"), undefined);
    _t.eq("designer: its parent is selected", _cv.selected.name, "Panel1");
    _da.form.simulate_key(vk_escape);
    _t.eq("designer: Escape selects the parent", _cv.selected, _da.target);

    _cv.select(_da.target.find("Panel1"));
    _da.form.simulate_drag(_fx + 360, _fy + 176, _fx + 392, _fy + 200);   // bottom-right handle
    var _dp = _da.target.find("Panel1");
    _t.eq("designer: a handle resizes (snapped)", _dp.width == 232 && _dp.height == 184, true);

    _da.props_grid.set_row_value(_da.props_grid.find_row("name"), "pnlMain");
    _t.eq("designer: rename through the inspector", _da.target.find("pnlMain") != undefined, true);
    _da.props_grid.set_row_value(_da.props_grid.find_row("name"), "frmT");
    _t.eq("designer: a duplicate name is refused", _da.target.find("pnlMain") != undefined, true);

    var _ev_btn = _cv.create_control("Button", _da.target.find("pnlMain"), 8, 8);
    _da.events_grid.select(_da.events_grid.find_row("onClick"));
    _da.events_grid.on_dbl_click(_da.events_grid, "onClick", _da.events_grid.target);
    _t.eq("designer: double-click names the handler <control>_<Event>", _ev_btn._ev_names[$ "on_click"], "Button1_Click");
    _t.eq("designer: event binding is undoable", _da.undo.undo_label(), "Set onClick");

    var _dtc = _cv.create_control("TabControl", _da.target, 8, 200, 200, 90);
    _t.eq("designer: a new TabControl gets a page", array_length(_dtc.pages()), 1);
    _cv.add_tab_page();
    _t.eq("designer: add a tab page", _dtc.tab_index == 1 && _cv.selected.name == "TabSheet2", true);
    var _ded = _cv.create_control("Edit", _dtc, 4, 4);
    _t.eq("designer: dropping on a TabControl lands on its active page", _ded.parent.name, "TabSheet2");

    _cv.set_form_size(480, 320);
    _t.eq("designer: form design size", _da.target.width == 480 && _da.target.height == 320, true);
    var _djson = gmforms_form_to_json(_da.target);
    _t.eq("designer: the designed form round-trips", gmforms_form_to_json(gmforms_load_form_json(_djson)), _djson);

    // --- M6 acceptance: the tile editor's form, rebuilt in the designer, is what the sample loads ---------
    var _da2 = new DesignerApp();
    designer_script_tile_editor(_da2);
    var _tfile = gmforms_read_text_file(DEMO_TILES_FORM);
    _t.eq("M6: datafiles/tile_editor.gmform.json is present", _tfile != undefined, true);
    _t.eq("M6: the designer rebuild matches it byte for byte", gmforms_form_to_json(_da2.target), _tfile);
    var _lc1 = gmforms_init().log_count;
    var _tapp = new DemoTilesApp();
    _t.eq("M6: the sample loads its designed form without warnings", gmforms_init().log_count, _lc1);
    _t.eq("M6: toolbar button bound by name", is_callable(_tapp.form.find("btnSave").on_click), true);
    _t.eq("M6: menu item bound by name", is_callable(_tapp.menu.find_item("Save").on_click), true);
    _t.eq("M6: viewport events bound by name", is_callable(_tapp.vp.on_draw) && is_callable(_tapp.vp.on_mouse_down), true);
    _tapp.form.dispatch_shortcut(ord("2"), true, false, false);
    _t.eq("M6: a loaded menu shortcut drives the sample", _tapp.tool, "select");

    var _ok = (_t.failed == 0);
    show_debug_message("[GMForms tests] " + string(_t.passed) + " passed, " + string(_t.failed) + " failed");
    return _ok;
}
