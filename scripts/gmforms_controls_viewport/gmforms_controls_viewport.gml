/// GMForms — GMF_Viewport: hosts user GML drawing behind a pannable/zoomable camera.
/// See gamemaker-form-designer-plan.md section 10 and CLAUDE.md's M3 notes for the camera convention.

/// @func GMF_Viewport()
/// @desc Hosts user GML drawing behind a camera. cam = {x, y, zoom}: (x,y) is the world point shown
///       at the viewport's local (0,0); zoom is world-to-screen scale.
///       Known limitation: no control-level destroy() hook exists yet, so a Viewport's surface is not
///       freed if the control is removed mid-session; GameMaker frees all surfaces at room end.
function GMF_Viewport() : GMF_Control() constructor {
    class_name = "Viewport";
    width = 320;
    height = 240;
    cam = { x: 0, y: 0, zoom: 1 };
    min_zoom = 0.1;
    max_zoom = 8;
    grid_size = 0;          // 0 = no grid overlay
    bg_color = undefined;   // undefined = theme.viewport_bg
    on_draw = undefined;    // (sender, cam) — draw in world coordinates; the camera transform is already applied
    on_wheel = undefined;   // (sender, delta) — fired after the built-in zoom
    _surface = -1;
    _surf_w = 0;
    _surf_h = 0;
    _panning = false;
    _pan_last_x = 0;
    _pan_last_y = 0;

    static published = array_concat(gmforms_base_published(), [
        { name: "width",     type: "int",    default_value: 320 },
        { name: "height",    type: "int",    default_value: 240 },
        { name: "cam",       type: "struct", default_value: { x: 0, y: 0, zoom: 1 } },
        { name: "min_zoom",  type: "real",   default_value: 0.1 },
        { name: "max_zoom",  type: "real",   default_value: 8 },
        { name: "grid_size", type: "int",    default_value: 0 },
        { name: "bg_color",  type: "color",  default_value: undefined },
        { name: "onDraw",      type: "event" },
        { name: "onMouseDown", type: "event" },
        { name: "onMouseUp",   type: "event" },
        { name: "onMouseMove", type: "event" },
        { name: "onWheel",     type: "event" },
    ]);

    /// @func screen_to_world(lx, ly)
    /// @desc Converts local (control-space) coordinates to world coordinates under the current camera.
    static screen_to_world = function(_lx, _ly) {
        return { x: cam.x + _lx / cam.zoom, y: cam.y + _ly / cam.zoom };
    };

    /// @func world_to_screen(wx, wy)
    /// @desc Converts world coordinates to local (control-space) coordinates under the current camera.
    static world_to_screen = function(_wx, _wy) {
        return { x: (_wx - cam.x) * cam.zoom, y: (_wy - cam.y) * cam.zoom };
    };

    /// @func zoom_at(lx, ly, factor)
    /// @desc Multiplies zoom by factor (clamped to min_zoom/max_zoom) while keeping the world point
    ///       under local (lx, ly) fixed on screen.
    static zoom_at = function(_lx, _ly, _factor) {
        var _before = screen_to_world(_lx, _ly);
        cam.zoom = clamp(cam.zoom * _factor, min_zoom, max_zoom);
        var _after = screen_to_world(_lx, _ly);
        cam.x += (_before.x - _after.x);
        cam.y += (_before.y - _after.y);
    };

    // Pan: middle-mouse drag, or Space+left-drag. Otherwise converts to world coords and fires the
    // matching on_mouse_* event (same field names as the base control, but world-space arguments here).
    static mouse_down = function(_x, _y, _btn) {
        if (_btn == mb_middle || (_btn == mb_left && keyboard_check(vk_space))) {
            _panning = true; _pan_last_x = _x; _pan_last_y = _y; return;
        }
        var _w = screen_to_world(_x, _y);
        if (is_callable(on_mouse_down)) on_mouse_down(self, _w.x, _w.y, _btn);
    };
    static mouse_move = function(_x, _y) {
        if (_panning) {
            cam.x -= (_x - _pan_last_x) / cam.zoom;
            cam.y -= (_y - _pan_last_y) / cam.zoom;
            _pan_last_x = _x; _pan_last_y = _y;
            return;
        }
        var _w = screen_to_world(_x, _y);
        if (is_callable(on_mouse_move)) on_mouse_move(self, _w.x, _w.y);
    };
    static mouse_up = function(_x, _y, _btn) {
        if (_panning && (_btn == mb_middle || _btn == mb_left)) { _panning = false; return; }
        var _w = screen_to_world(_x, _y);
        if (is_callable(on_mouse_up)) on_mouse_up(self, _w.x, _w.y, _btn);
    };

    // Wheel zoom, centered on the cursor. delta<0 is wheel-up (zoom in), per GMF_Form's _wd convention.
    static mouse_wheel = function(_delta) {
        var _lx = device_mouse_x_to_gui(0) - _sx;
        var _ly = device_mouse_y_to_gui(0) - _sy;
        zoom_at(_lx, _ly, power(1.1, -_delta));
        if (is_callable(on_wheel)) on_wheel(self, _delta);
        return true;
    };

    static _draw_grid = function() {
        var _th = gmforms_theme();
        draw_set_colour(_th.viewport_grid);
        var _tl = screen_to_world(0, 0);
        var _br = screen_to_world(width, height);
        var _x0 = floor(_tl.x / grid_size) * grid_size;
        var _y0 = floor(_tl.y / grid_size) * grid_size;
        for (var _gx = _x0; _gx <= _br.x; _gx += grid_size) draw_line(_gx, _tl.y, _gx, _br.y);
        for (var _gy = _y0; _gy <= _br.y; _gy += grid_size) draw_line(_tl.x, _gy, _br.x, _gy);
    };

    static draw = function() {
        var _w = max(1, round(width)), _h = max(1, round(height));
        if (!surface_exists(_surface) || _surf_w != _w || _surf_h != _h) {
            if (surface_exists(_surface)) surface_free(_surface);
            _surface = surface_create(_w, _h);
            _surf_w = _w; _surf_h = _h;
        }
        var _th = gmforms_theme();
        surface_set_target(_surface);
        draw_clear(bg_color ?? _th.viewport_bg);
        var _mat = matrix_get(matrix_world);
        matrix_set(matrix_world, matrix_build(-cam.x * cam.zoom, -cam.y * cam.zoom, 0, 0, 0, 0, cam.zoom, cam.zoom, 1));
        if (grid_size > 0) _draw_grid();
        if (is_callable(on_draw)) on_draw(self, cam);
        matrix_set(matrix_world, _mat);
        surface_reset_target();

        if (gmforms_scissor_push(_sx, _sy, width, height)) {
            draw_surface(_surface, _sx, _sy);
        }
        gmforms_scissor_pop();
    };

    static draw_overlay = function() {
        gmforms_draw_frame(_sx, _sy, width, height, gmforms_theme().viewport_border);
    };
}
