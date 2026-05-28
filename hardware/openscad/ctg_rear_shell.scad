// CyberThreatGotchi — REAR SHELL (battery tray + vents + branding)
// Export: openscad -o ../stl/eink/ctg_rear_shell.stl ctg_rear_shell.scad

include <ctg_params.scad>

module vent_slots() {
  for (i = [0 : vent_count - 1]) {
    translate([width / 2 - vent_w / 2, wall + 1 + i * (vent_h + vent_gap), height / 2 - 12])
      cube([vent_w, wall + 2, vent_h]);
  }
}

module eth_grommets() {
  for (x = eth_x_positions) {
    translate([x, -0.1, height / 2 - 8])
      rotate([-90, 0, 0])
      cylinder(h = wall + 2, r = eth_grommet_r, $fn = 32);
  }
}

module rear_branding() {
  // Embossed text on rear outer face (Y=0)
  translate([width / 2, -0.05, 14])
    rotate([-90, 0, 0])
    linear_extrude(height = 0.9)
      text("HACKER PLANET LLC", size = 3.2, halign = "center", valign = "center",
           font = "Liberation Sans:style=Bold");
  translate([width / 2, -0.05, 6])
    rotate([-90, 0, 0])
    linear_extrude(height = 0.6)
      text("CyberThreatGotchi", size = 2.2, halign = "center", valign = "center",
           font = "Liberation Sans:style=Regular");
}

module rear_shell() {
  difference() {
    union() {
      rounded_box(width, depth, height, corner_r);
      translate([wall + 2, wall + 1, wall + 2])
        cube([width - 2 * wall - 4, battery_lip, battery_shelf_z]);
      rear_branding();
    }
    translate([wall, wall, wall])
      cube([width - 2 * wall, depth / 2 - wall, height - 2 * wall]);
    vent_slots();
    eth_grommets();
    translate([width / 2 - usbc_w / 2, -0.1, 2])
      cube([usbc_w, wall + 2, usbc_h]);
    translate([width - 14, depth / 2 - 3, height - 10])
      rotate([0, 90, 0])
      cylinder(h = 8, r = reset_r, $fn = 24);
  }
  for (x = [clip_slot_x, width - clip_slot_x - clip_slot_w]) {
    translate([x, depth - wall - clip_slot_d, height / 2 - clip_slot_h / 2])
      cube([clip_slot_w, clip_slot_d + 0.5, clip_slot_h]);
  }
}

rear_shell();
