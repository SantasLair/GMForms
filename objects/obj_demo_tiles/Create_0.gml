/// @desc Build the tile editor sample (see scripts/demo_tiles).
if (GMF_RUN_TESTS && room == room_first) gmforms_run_tests();
if (DEMO_M5_CAPTURE) { room_goto(rm_demo_m5); exit; }   // scripted gallery screenshots start there

app = new DemoTilesApp();
host = gmforms_host_create(app.form);
_capture_t = 0;   // frame counter for DEMO_TILES_CAPTURE (see Step)
