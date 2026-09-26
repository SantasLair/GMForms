/// @desc Build the M1 demo form and wire its events in code (event style B from the plan).
if (GMF_RUN_TESTS && room == room_first) gmforms_run_tests();

form = demo_m1_build_form();
status = form.find("lblStatus");
size_label = form.find("lblSize");

set_status = function(_text) {
    status.caption = _text;
};

// Every button without its own handler reports the click in the status bar.
form.walk(function(_c) {
    if (_c.class_name == "Button" && _c.on_click == undefined) {
        _c.on_click = function(_sender) {
            set_status("Clicked " + _sender.name + "  (\"" + _sender.caption + "\")");
        };
    }
});

var _btn_palette = form.find("btnTogglePalette");
_btn_palette.on_click = function(_sender) {
    var _p = form.find("pnlPalette");
    _p.set_visible(!_p.visible);
    set_status("Palette " + (_p.visible ? "shown" : "hidden") + " - client area reflowed");
};

var _btn_inspector = form.find("btnToggleInspector");
_btn_inspector.on_click = function(_sender) {
    var _p = form.find("pnlInspector");
    _p.set_visible(!_p.visible);
    set_status("Inspector " + (_p.visible ? "shown" : "hidden") + " - client area reflowed");
};

var _btn_enabled = form.find("btnToggleEnabled");
_btn_enabled.on_click = function(_sender) {
    var _b = form.find("btnTR");
    _b.set_enabled(!_b.enabled);
    _sender.caption = _b.enabled ? "Disable top-right" : "Enable top-right";
    set_status("btnTR " + (_b.enabled ? "enabled" : "disabled"));
};

var _btn_help = form.find("btnHelp");
_btn_help.on_click = function(_sender) {
    set_status("Resize the window to see Align/Anchors reflow. Tab / Shift+Tab moves focus; Space or Enter clicks.");
};

form.on_resize = function(_sender) {
    size_label.caption = string(_sender.width) + " x " + string(_sender.height);
};

host = gmforms_host_create(form);
form.on_resize(form);   // show the initial size

_capture_t = 0;   // frame counter for GMF_DEMO_CAPTURE (see Step)
