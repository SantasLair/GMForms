/// @desc Optional scripted screenshot run.
if (DEMO_M5_CAPTURE) {
    _capture_t++;
    demo_m5_capture_step(app, _capture_t);
}
