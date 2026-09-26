/// @desc Optional visual check: with GMF_DEMO_CAPTURE on, saves screenshots to the save area
///       (game_save_id) at design, large and small window sizes, then ends the game.
if (!GMF_DEMO_CAPTURE) exit;

_capture_t++;
switch (_capture_t) {
    case 30:  screen_save("m1_a_design.png"); break;
    case 31:  window_set_size(1200, 760); break;
    case 60:  screen_save("m1_b_large.png"); show_debug_message("[GMForms] window " + string(window_get_width()) + "x" + string(window_get_height()) + " gui " + string(display_get_gui_width()) + " scale " + string(global.gmforms.scissor_scale_x)); break;
    case 61:  form.find("btnTogglePalette").click(); form.focus_next(1); form.focus_next(1); break;
    case 90:  screen_save("m1_c_nopalette_focus.png"); break;
    case 91:  form.find("btnTogglePalette").click(); form.find("btnToggleEnabled").click(); window_set_size(760, 520); break;
    case 120: screen_save("m1_d_small.png"); show_debug_message("[GMForms] capture dir: " + game_save_id); break;
    case 121: game_end(); break;
}
