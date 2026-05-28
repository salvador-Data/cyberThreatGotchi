// LCD variant overrides — ILI9341 2.4" portrait window
// Use: openscad -Dvariant=lcd -o ../stl/lcd/ctg_front_shell.stl ctg_front_shell.scad

variant = "eink"; // eink | lcd

function display_w() = variant == "lcd" ? 39 : 50;
function display_h() = variant == "lcd" ? 55 : 26;
function display_z() = variant == "lcd" ? 48 : 72;
