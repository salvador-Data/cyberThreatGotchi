// CyberThreatGotchi — FRONT SHELL
// Export e-ink: openscad -o ../stl/eink/ctg_front_shell.stl ctg_front_shell.scad
// Export LCD:   openscad -Dvariant=lcd -o ../stl/lcd/ctg_front_shell.stl ctg_front_shell.scad

include <ctg_params.scad>
include <ctg_variant.scad>

dw = display_w();
dh = display_h();
dz = display_z();

module front_shell() {
  difference() {
    union() {
      rounded_box(width, depth, height, corner_r);
      for (p = cat_positions) {
        translate([p[0], depth - 1.2, p[1]])
          scale([1, 0.55, 1])
          sphere(r = cat_bump_r, $fn = 28);
      }
      translate([(width - dw) / 2 - bezel_lip, depth - wall - bezel_lip, dz - bezel_lip])
        cube([dw + 2 * bezel_lip, bezel_lip + 0.8, dh + 2 * bezel_lip]);
    }
    translate([wall, wall + depth / 2, wall])
      cube([width - 2 * wall, depth / 2 - wall + 0.1, height - 2 * wall]);
    translate([(width - dw) / 2, depth - wall - 0.2, dz])
      cube([dw, wall + 1.5, dh]);
    translate([wall - 0.1, wall + 4, height / 2 - 10])
      cube([ribbon_w + 0.2, ribbon_d, 20]);
    translate([width / 2 - usbc_w / 2, depth - wall - 0.2, 2])
      cube([usbc_w, wall + 1.5, usbc_h]);
  }
  for (p = standoff_positions) {
    translate([p[0], depth / 2 + 2, p[1]])
      standoff_post(standoff_h, standoff_od, standoff_hole);
  }
}

front_shell();
