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

    var _ok = (_t.failed == 0);
    show_debug_message("[GMForms tests] " + string(_t.passed) + " passed, " + string(_t.failed) + " failed");
    return _ok;
}
