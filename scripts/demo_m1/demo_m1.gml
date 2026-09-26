/// M1 demo: a hand-built form showing Align (top/bottom/left/right/client, nested) and Anchors.
/// Resize the window: panels reflow, anchored buttons keep their edge distances.
/// Tab / Shift+Tab cycles focus; Space or Enter clicks the focused button.

#macro GMF_DEMO_CAPTURE false   // true: obj_demo_m1 saves screenshots at several window sizes, then quits

/// @func demo_m1_build_form()
/// @returns {Struct.GMF_Form}
function demo_m1_build_form() {
    var _form = gmforms_create(GMF_Form, {
        name: "frmDemo",
        caption: "GMForms M1 demo - resize the window",
        width: 1024,            // design size: anchors are captured against this
        height: 700,
    });

    // ---- top toolbar -------------------------------------------------------
    var _top = _form.add(gmforms_create(GMF_Panel, { name: "pnlToolbar", align: "top", height: 40 }));
    _top.add(gmforms_create(GMF_Button, { name: "btnNew",   caption: "New",   left: 6,   top: 6, width: 80 }));
    _top.add(gmforms_create(GMF_Button, { name: "btnOpen",  caption: "Open",  left: 92,  top: 6, width: 80 }));
    _top.add(gmforms_create(GMF_Button, { name: "btnSave",  caption: "Save",  left: 178, top: 6, width: 80 }));
    _top.add(gmforms_create(GMF_Button, { name: "btnTogglePalette",   caption: "Toggle palette",   left: 280, top: 6, width: 130 }));
    _top.add(gmforms_create(GMF_Button, { name: "btnToggleInspector", caption: "Toggle inspector", left: 416, top: 6, width: 140 }));
    _top.add(gmforms_create(GMF_Button, { name: "btnToggleEnabled",   caption: "Disable top-right", left: 562, top: 6, width: 150 }));
    _top.add(gmforms_create(GMF_Button, { name: "btnHelp",  caption: "Help",  left: 1024 - 86, top: 6, width: 80,
        anchors: ["right", "top"] }));

    // ---- bottom status bar -------------------------------------------------
    var _status = _form.add(gmforms_create(GMF_Panel, { name: "pnlStatus", align: "bottom", height: 26 }));
    _status.add(gmforms_create(GMF_Label, { name: "lblStatus", caption: "Ready. Press Tab to move focus.",
        left: 4, top: 2, width: 700, height: 22, anchors: ["left", "top", "right"] }));
    _status.add(gmforms_create(GMF_Label, { name: "lblSize", caption: "", text_align: "right",
        left: 1024 - 164, top: 2, width: 160, height: 22, anchors: ["right", "top"] }));

    // design-time client height between toolbar and status bar
    var _ch = 700 - 40 - 26;    // 634

    // ---- left palette ------------------------------------------------------
    var _left = _form.add(gmforms_create(GMF_Panel, { name: "pnlPalette", align: "left", width: 180,
        caption: "Palette (align = left)" }));
    var _tools = ["Select", "Brush", "Fill", "Eraser"];
    for (var _i = 0; _i < array_length(_tools); _i++) {
        _left.add(gmforms_create(GMF_Button, { name: "btnTool" + _tools[_i], caption: _tools[_i],
            left: 8, top: 28 + _i * 34, width: 164, anchors: ["left", "top", "right"] }));
    }
    _left.add(gmforms_create(GMF_Button, { name: "btnSettings", caption: "Settings (bottom)",
        left: 8, top: _ch - 36, width: 164, anchors: ["left", "right", "bottom"] }));

    // ---- right inspector (nested align inside) ----------------------------
    var _right = _form.add(gmforms_create(GMF_Panel, { name: "pnlInspector", align: "right", width: 220 }));
    _right.add(gmforms_create(GMF_Label, { name: "lblInspector", caption: "Inspector (align = right)",
        align: "top", height: 24 }));
    _right.add(gmforms_create(GMF_Panel, { name: "pnlInspectorBody", caption: "nested align = client",
        align: "client", margin: { l: 6, t: 0, r: 6, b: 48 } }));
    _right.add(gmforms_create(GMF_Button, { name: "btnApply", caption: "Apply",
        left: 220 - 88, top: _ch - 38, width: 80, anchors: ["right", "bottom"] }));
    _right.add(gmforms_create(GMF_Button, { name: "btnRevert", caption: "Revert",
        left: 220 - 174, top: _ch - 38, width: 80, anchors: ["right", "bottom"] }));

    // ---- client area -------------------------------------------------------
    var _cw = 1024 - 180 - 220; // 624
    var _center = _form.add(gmforms_create(GMF_Panel, { name: "pnlClient", align: "client", border: false,
        color: make_colour_rgb(36, 36, 40) }));
    _center.add(gmforms_create(GMF_Panel, { name: "pnlClientHeader", align: "top", height: 30,
        caption: "Client area (align = client) with a nested top-aligned header" }));

    _center.add(gmforms_create(GMF_Button, { name: "btnTL", caption: "left, top",
        left: 16, top: 46, width: 130, anchors: ["left", "top"] }));
    _center.add(gmforms_create(GMF_Button, { name: "btnTR", caption: "right, top",
        left: _cw - 16 - 130, top: 46, width: 130, anchors: ["right", "top"] }));
    _center.add(gmforms_create(GMF_Button, { name: "btnStretch", caption: "left, top, right (stretches)",
        left: 16, top: 84, width: _cw - 32, anchors: ["left", "top", "right"] }));

    var _box = _center.add(gmforms_create(GMF_Panel, { name: "pnlStretchBoth", caption: "Panel anchored on all four sides",
        left: 16, top: 124, width: _cw - 32, height: _ch - 124 - 60, anchors: ["left", "top", "right", "bottom"] }));
    var _bw = _cw - 32;         // 592
    var _bh = _ch - 124 - 60;   // 450
    _box.add(gmforms_create(GMF_Button, { name: "btnCentre", caption: "no anchors (keeps centre)",
        left: floor(_bw / 2) - 120, top: floor(_bh / 2) - 14, width: 240, anchors: [] }));
    _box.add(gmforms_create(GMF_Button, { name: "btnBoxBR", caption: "right, bottom",
        left: _bw - 138, top: _bh - 36, width: 130, anchors: ["right", "bottom"] }));

    _center.add(gmforms_create(GMF_Button, { name: "btnBL", caption: "left, bottom",
        left: 16, top: _ch - 46, width: 130, anchors: ["left", "bottom"] }));
    _center.add(gmforms_create(GMF_Button, { name: "btnBR", caption: "right, bottom",
        left: _cw - 16 - 130, top: _ch - 46, width: 130, anchors: ["right", "bottom"] }));

    return _form;
}
