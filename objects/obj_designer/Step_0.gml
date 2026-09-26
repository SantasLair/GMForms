/// @desc Optional scripted screenshot run.
if (DESIGNER_CAPTURE) {
    _capture_t++;
    designer_capture_step(app, _capture_t);
}
