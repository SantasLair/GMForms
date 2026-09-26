/// @desc Host state. Use gmforms_host_create(form) rather than placing this object by hand.
form = undefined;          // the GMF_Form this host drives
fill_window = true;        // keep the form sized to the window (1:1 pixels, reflow instead of scale)
resize_app_surface = true; // resize application_surface to the window too (prevents GUI letterboxing)
_last_w = -1;
_last_h = -1;
_last_caption = undefined;
