// Shared parameters — CyberThreatGotchi Tamagotchi enclosure (mm)

// Outer envelope
width  = 95;
height = 110;
depth  = 32;
wall   = 2.0;
corner_r = 4;

// Display (Waveshare 2.13" default)
display_cut_w = 50;
display_cut_h = 26;
display_z     = 72;
bezel_lip     = 2.5;

// Ports
usbc_w = 12;
usbc_h = 6;
reset_r = 3;

// BPI-R3 Mini standoffs (verify against your board revision)
standoff_h    = 6;
standoff_od   = 4.5;
standoff_hole = 1.25;  // M2.5 pilot
standoff_positions = [[12, 45], [53, 45], [12, 78], [53, 78]];

// Cat emboss positions [x, z]
cat_bump_r = 4;
cat_positions = [[10, 88], [78, 88], [10, 28], [78, 28]];

// SPI ribbon channel (left inner wall)
ribbon_w = 8;
ribbon_d = 20;

// Rear vents
vent_count = 4;
vent_w     = 15;
vent_h     = 3;
vent_gap   = 4;

// Ethernet grommet holes (rear face)
eth_grommet_r = 4;
eth_x_positions = [24, width - 24];

// Battery tray
battery_lip     = 3;
battery_shelf_z = 18;

// Clip slots in rear shell
clip_slot_x = 6;
clip_slot_w = 10;
clip_slot_h = 14;
clip_slot_d = 2.5;

// Snap clip dimensions
clip_bar_w  = 52;
clip_arm_w  = 8;
clip_arm_h  = 16;
clip_depth  = 6;
clip_hook_h = 5;

module rounded_box(w, d, h, r) {
  hull() {
    for (dx = [r, w - r])
      for (dy = [r, d - r])
        for (dz = [r, h - r])
          translate([dx, dy, dz])
          sphere(r = r, $fn = 16);
  }
}

module standoff_post(h, od, hole) {
  difference() {
    cylinder(h = h, r = od / 2, $fn = 24);
    translate([0, 0, -0.1])
      cylinder(h = h + 1, r = hole, $fn = 16);
  }
}
