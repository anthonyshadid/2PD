// 2-Point Discrimination Wheel — parametric n-gon, flat perimeter prongs (sharper & thinner)
$fa = 3;
$fs = 0.25;
$fn = is_undef($fn) ? 96 : $fn;

/************* User controls *************/
distances_mm       = is_undef(distances_mm) ? [2,4,6,8,10,15,20,25] : distances_mm;
outer_flat_to_flat = is_undef(outer_flat_to_flat) ? 67 : outer_flat_to_flat;
base_thickness     = is_undef(base_thickness) ? 3.0 : base_thickness;

// Prongs (planar)
spike_length  = is_undef(spike_length) ? 16 : spike_length;  // radial length of each prong
base_d        = is_undef(base_d) ? 2.2 : base_d;             // **thinner** root width
root_overlap  = is_undef(root_overlap) ? 0 : root_overlap;   // 0 = no inward bite (keeps edge flush/pointy)

// Labels / hub
label_size    = is_undef(label_size) ? 3 : label_size;
label_depth   = is_undef(label_depth) ? 0.5 : label_depth;
font_name     = is_undef(font_name) ? "DejaVu Sans:style=Bold" : font_name;
label_radial  = is_undef(label_radial) ? 0.80 : label_radial;
hub_diameter  = is_undef(hub_diameter) ? 20 : hub_diameter;
thumb_depth   = is_undef(thumb_depth) ? 0.5 : thumb_depth;

// No chamfer so tips stay sharp
chamfer       = 0;

function apothem(across_flats,n)=across_flats/2;
function circ_radius(across_flats,n)=across_flats/(2*cos(180/n));
function total_thickness()=base_thickness;

/************* 2D primitives *************/
module ngon_2d(n, across_flats){
  r=circ_radius(across_flats,n);
  polygon(points=[for(i=[0:n-1]) let(a=360*i/n)[r*cos(a), r*sin(a)]]);
}

// Flat prong as a sharp isosceles triangle (no bevel, no bite)
module flat_prong_2d(len=spike_length, root_w=base_d, bite=root_overlap){
  polygon(points=[
    [-bite, -root_w/2],
    [-bite,  root_w/2],
    [ len,    0      ]  // sharp tip
  ]);
}

/************* Features on top *************/
module thumb_well_top(){
  translate([0,0,total_thickness()-thumb_depth])
    cylinder(h=thumb_depth,d=hub_diameter,$fn=72);
}

module edge_numbers_top(distances,a){
  n=len(distances);
  for(i=[0:n-1]){
    angN=-360*(i+0.5)/n;
    translate([(label_radial*a)*cos(angN),
               (label_radial*a)*sin(angN),
               total_thickness()-label_depth])
      rotate([0,0,angN-90])
        linear_extrude(height=label_depth)
          text(str(distances[i]),
               size=label_size,font=font_name,
               halign="center",valign="center");
  }
}

/************* Build: outline -> extrude *************/
module wheel_outline_2d(distances){
  n=len(distances);
  a=apothem(outer_flat_to_flat,n);

  union(){
    ngon_2d(n, outer_flat_to_flat);

    for(i=[0:n-1]){
      angN=-360*(i+0.5)/n;
      sep = distances[i];

      translate([a*cos(angN), a*sin(angN)])
        rotate(angN){
          translate([0, +sep/2]) flat_prong_2d(spike_length, base_d, root_overlap);
          translate([0, -sep/2]) flat_prong_2d(spike_length, base_d, root_overlap);
        }
    }
  }
}

module wheel_body_flat(distances){
  // No chamfer — preserves sharp tips and avoids the 45° dip
  linear_extrude(height=base_thickness)
    wheel_outline_2d(distances);
}

/************* Main *************/
module discriminator(distances){
  n=len(distances);
  assert(n>=3,"distances_mm must have at least 3 entries.");
  difference(){
    wheel_body_flat(distances);
    thumb_well_top();
    edge_numbers_top(distances, apothem(outer_flat_to_flat,n));
  }
}

discriminator(distances_mm);
