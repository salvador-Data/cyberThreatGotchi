// CyberThreatGotchi — parametric enclosure preview (OpenSCAD)
// Units: mm

width  = 95;
height = 110;
depth  = 32;
wall   = 2;

display_w = 50;
display_h = 26;
display_y = 72;

difference() {
  cube([width, depth, height]);
  // Hollow cavity
  translate([wall, wall, wall])
    cube([width - 2*wall, depth - 2*wall, height - wall]);
  // Display window (front face = Z max)
  translate([(width - display_w)/2, depth - wall - 0.1, display_y])
    cube([display_w, wall + 1, display_h]);
  // USB-C slot bottom
  translate([width/2 - 6, -0.1, 4])
    cube([12, wall + 2, 6]);
}

// Cat bump left front
translate([8, depth - 3, 88])
  scale([1, 0.5, 1])
  sphere(r=4, $fn=24);
