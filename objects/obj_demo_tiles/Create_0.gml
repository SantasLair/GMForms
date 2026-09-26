/// @desc Build the tile editor sample (see scripts/demo_tiles).
if (GMF_RUN_TESTS && room == room_first) gmforms_run_tests();
// scripted runs that start in another room
if (DEMO_M5_CAPTURE) { room_goto(rm_demo_m5); exit; }
if (DESIGNER_CAPTURE || DESIGNER_EXPORT_TILES) { room_goto(rm_designer); exit; }

app = new DemoTilesApp();
host = gmforms_host_create(app.form);
_capture_t = 0;   // frame counter for DEMO_TILES_CAPTURE (see Step)
