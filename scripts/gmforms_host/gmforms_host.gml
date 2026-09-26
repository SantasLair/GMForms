/// GMForms — host helpers (decision D2: one host instance owns a form).

/// @func gmforms_host_create(form, [depth], [fill_window])
/// @desc Creates an obj_gmforms_host instance that updates and draws the form.
/// @param {Struct} form            A GMF_Form.
/// @param {Real}   [depth]         Instance depth (default 0).
/// @param {Bool}   [fill_window]   true (default): the form always fills the window and reflows on resize.
///                                 false: the form keeps its own left/top/width/height.
/// @returns {Id.Instance} The host instance.
function gmforms_host_create(_form, _depth = 0, _fill_window = true) {
    var _inst = instance_create_depth(0, 0, _depth, obj_gmforms_host);
    _inst.form = _form;
    _inst.fill_window = _fill_window;
    return _inst;
}
