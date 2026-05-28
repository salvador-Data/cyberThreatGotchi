// CyberThreatGotchi — SNAP CLIP (joins front + rear shells)
// Export: openscad -o ctg_clip.stl ctg_clip.scad

include <ctg_params.scad>

module clip_arm(offset_x) {
  translate([offset_x, 0, 0])
    difference() {
      union() {
        cube([clip_arm_w, clip_depth, clip_arm_h]);
        translate([clip_arm_w / 2, clip_depth, clip_arm_h / 2])
          rotate([90, 0, 0])
          cylinder(h = 3, r = clip_arm_w / 2 + 0.5, $fn = 24);
      }
      translate([clip_arm_w / 2, -0.1, clip_arm_h - clip_hook_h])
        rotate([0, 0, 0])
        cube([clip_arm_w - 2, clip_depth + 2, clip_hook_h + 2], center = false);
    }
}

module snap_clip() {
  union() {
    // Crossbar
    translate([(width - clip_bar_w) / 2, 0, clip_arm_h - 2])
      cube([clip_bar_w, clip_depth, 4]);
    clip_arm((width - clip_bar_w) / 2 - clip_arm_w + 2);
    clip_arm((width + clip_bar_w) / 2 - 2);
    // Finger pull tab
    translate([width / 2 - 8, clip_depth - 1, clip_arm_h + 2])
      cube([16, 8, 3]);
  }
}

snap_clip();
