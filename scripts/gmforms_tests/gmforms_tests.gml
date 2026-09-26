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

    var _ok = (_t.failed == 0);
    show_debug_message("[GMForms tests] " + string(_t.passed) + " passed, " + string(_t.failed) + " failed");
    return _ok;
}
