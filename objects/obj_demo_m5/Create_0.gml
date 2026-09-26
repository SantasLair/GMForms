/// @desc Build the M5 controls gallery (see scripts/demo_m5).
if (GMF_RUN_TESTS && room == room_first) gmforms_run_tests();

app = new DemoM5App();
host = gmforms_host_create(app.form);
_capture_t = 0;   // frame counter for DEMO_M5_CAPTURE (see Step)
