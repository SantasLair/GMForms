/// @desc Track window size, then run the form's input.
if (form == undefined) exit;

if (fill_window) {
    var _w = window_get_width();
    var _h = window_get_height();
    // window size is 0 while minimised; keep the last layout in that case
    if (_w > 0 && _h > 0 && (_w != _last_w || _h != _last_h)) {
        _last_w = _w;
        _last_h = _h;
        // Decision D5: 1:1 pixels. Resizing the application surface to the window keeps its aspect
        // equal to the window's, so GameMaker never letterboxes the GUI layer (with "Keep aspect
        // ratio" on, the GUI would otherwise be scaled into the letterboxed rect).
        if (resize_app_surface && application_surface_is_enabled()) {
            surface_resize(application_surface, _w, _h);
        }
        display_set_gui_size(_w, _h);
        form.set_bounds(0, 0, _w, _h);
    }
}

if (form.caption != _last_caption) {
    _last_caption = form.caption;
    window_set_caption(form.caption);
}

form.update();
