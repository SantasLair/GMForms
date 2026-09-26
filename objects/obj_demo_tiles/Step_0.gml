/// @desc Optional scripted screenshot run (shortcuts are handled by the form's menu bar).
if (DEMO_TILES_CAPTURE) {
    _capture_t++;
    demo_tiles_capture_step(app, _capture_t);
}
