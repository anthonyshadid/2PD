// 2-Point Discrimination Wheel — parametric n-gon, COUNTERclockwise order + split thickness
// Includes badge/lanyard through-hole between 0 mm and 2 mm

distances_mm       = is_undef(distances_mm) ? [0,2,3,4,5,6,7,8] : distances_mm;

// --- geometry ---
outer_flat_to_flat = is_undef(outer_flat_to_flat) ? 40 : outer_flat_to_flat;
body_thickness     = is_undef(body_thickness) ? 3 : body_thickness;
prong_thickness    = is_undef(prong_thickness) ? 1.4 : prong_thickness;

spike_length  = is_undef(spike_length) ? 7 : spike_length;
base_d        = is_undef(base_d) ? 3 : base_d;
shank_d       = is_undef(shank_d) ? 1.4 : shank_d;
tip_d         = is_undef(tip_d) ? 0.15 : tip_d;
root_overlap  = is_undef(root_overlap) ? .7 : root_overlap;

// --- labels / hub ---
label_size    = is_undef(label_size) ? 3.5 : label_size;
label_depth   = is_undef(label_depth) ? .33 : label_depth;
font_name     = is_undef(font_name) ? "DejaVu Sans:style=Bold" : font_name;
label_radial  = is_undef(label_radial) ? 0.80 : label_radial;
hub_diameter  = is_undef(hub_diameter) ? 17 : hub_diameter;
thumb_depth   = is_undef(thumb_depth) ? .5 : thumb_depth;

// --- lanyard / badge hole ---
lanyard_hole_d      = is_undef(lanyard_hole_d) ? 3.5 : lanyard_hole_d;
lanyard_hole_inset  = is_undef(lanyard_hole_inset) ? 3.35 : lanyard_hole_inset;
// larger inset = farther inward from the octagon corner
// 5.0 should place it slightly inside the corner between 0 and 2 mm

// optional
chamfer = is_undef(chamfer) ? 0.8 : chamfer;
$fn = is_undef($fn) ? 72 : $fn;

function apothem(across_flats,n)=across_flats/2;
function circ_radius(across_flats,n)=across_flats/(2*cos(180/n));

// Use BODY thickness for anything “top referenced”
function total_thickness()=body_thickness + max(chamfer,0);

module polygon_plate(n, across_flats, thk){
  r = circ_radius(across_flats,n);
  linear_extrude(thk)
    polygon(points=[for(i=[0:n-1]) let(a=360*i/n)[r*cos(a), r*sin(a)]]);
}

module spike_single_flat(len=spike_length,bd=base_d,sd=shank_d,td=tip_d){
  base_r=bd/2; shank_r=sd/2; tip_r=td/2;
  bx=-root_overlap; sx=len*0.55; tx=len;

  linear_extrude(height=prong_thickness)
  union(){
    translate([bx,0]) circle(r=base_r);
    hull(){
      translate([bx,0]) circle(r=base_r);
      translate([sx,0]) circle(r=shank_r);
    }
    hull(){
      translate([sx,0]) circle(r=shank_r);
      translate([tx,0]) circle(r=tip_r);
    }
  }
}

module thumb_well_top(){
  translate([0,0,body_thickness - thumb_depth])
    cylinder(h=thumb_depth,d=hub_diameter,$fn=72);
}

module lanyard_corner_hole(distances){
  n = len(distances);
  R = circ_radius(outer_flat_to_flat,n);

  // For default [0,2,3,4,5,6,7,8]:
  // distance[0] is at 22.5 degrees, distance[1] is at 67.5 degrees,
  // so the corner between 0 and 2 mm is at 45 degrees.
  ang = 360 / n;

  translate([(R - lanyard_hole_inset) * cos(ang),
             (R - lanyard_hole_inset) * sin(ang),
             -0.1])
    cylinder(h = body_thickness + 0.2, d = lanyard_hole_d, $fn = 72);
}

module edge_numbers_cut(distances,a){
  n=len(distances);
  for(i=[0:n-1]){
    angN=+360*(i+0.5)/n;

    translate([(label_radial*a)*cos(angN),
               (label_radial*a)*sin(angN),
               body_thickness - label_depth])
      rotate([0,0,angN-90])
        linear_extrude(height=label_depth + 0.2)
          text(str(distances[i]),
               size=label_size,font=font_name,
               halign="center",valign="center");
  }
}

module wheel_solid(distances){
  n=len(distances);
  a=apothem(outer_flat_to_flat,n);

  union(){
    polygon_plate(n,outer_flat_to_flat,body_thickness);

    for(i=[0:n-1]){
      angN=+360*(i+0.5)/n;

      translate([a*cos(angN),a*sin(angN),0])
        rotate([0,0,angN]){
          sep=distances[i];
          translate([0,+sep/2,0]) spike_single_flat();
          translate([0,-sep/2,0]) spike_single_flat();
        }
    }
  }
}

module discriminator(distances){
  n=len(distances);
  assert(n>=3,"distances_mm must have at least 3 entries.");

  difference(){
    wheel_solid(distances);
    thumb_well_top();
    lanyard_corner_hole(distances);
    edge_numbers_cut(distances, apothem(outer_flat_to_flat,n));
  }
}
discriminator(distances_mm);