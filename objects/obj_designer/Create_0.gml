/// @desc The GMForms form designer (see scripts/designer_app).
if (GMF_RUN_TESTS && room == room_first) gmforms_run_tests();

app = new DesignerApp();
host = gmforms_host_create(app.form);
_capture_t = 0;

if (DESIGNER_EXPORT_TILES) {
    designer_script_tile_editor(app);
    app.save_file("tile_editor.gmform.json");
    show_debug_message("[GMForms] exported tile_editor.gmform.json to " + game_save_id);
    show_debug_message("[GMForms] capture dir: " + game_save_id);
    game_end();
}
