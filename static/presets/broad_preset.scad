
// 2-Point Discrimination Wheel — parametric n-gon, clockwise order
distances_mm       = is_undef(distances_mm) ? [5,8,10,12,15,20,25,30] : distances_mm;
outer_flat_to_flat = is_undef(outer_flat_to_flat) ? 63.5 : outer_flat_to_flat;
base_thickness     = is_undef(base_thickness) ? 3.0 : base_thickness;
spike_length  = is_undef(spike_length) ? 14 : spike_length;
base_d        = is_undef(base_d) ? 3 : base_d;
shank_d       = is_undef(shank_d) ? 1.4 : shank_d;
tip_d         = is_undef(tip_d) ? 0.6 : tip_d;
root_overlap  = is_undef(root_overlap) ? 0.7 : root_overlap;
label_size    = is_undef(label_size) ? 3 : label_size;
label_depth   = is_undef(label_depth) ? 0.5 : label_depth;
font_name     = is_undef(font_name) ? "DejaVu Sans:style=Bold" : font_name;
label_radial  = is_undef(label_radial) ? 0.80 : label_radial;
hub_diameter  = is_undef(hub_diameter) ? 20 : hub_diameter;
thumb_depth   = is_undef(thumb_depth) ? 0.5 : thumb_depth;
chamfer = is_undef(chamfer) ? 0.8 : chamfer;
$fn = is_undef($fn) ? 72 : $fn;

module soft_chamfer(h=chamfer){
  if (h>0) minkowski(){ children(); cylinder(h=h,r1=h,r2=0,$fn=24); }
  else children();
}
function apothem(across_flats,n)=across_flats/2;
function circ_radius(across_flats,n)=across_flats/(2*cos(180/n));
function total_thickness()=base_thickness+max(chamfer,0);

module polygon_plate(n, across_flats, thk){
  r=circ_radius(across_flats,n);
  soft_chamfer()
    linear_extrude(thk)
      polygon(points=[for(i=[0:n-1]) let(a=360*i/n)[r*cos(a),r*sin(a)]]);
}

module spike_single_flat(len=spike_length,bd=base_d,sd=shank_d,td=tip_d){
  base_r=bd/2; shank_r=sd/2; tip_r=td/2;
  bx=-root_overlap; sx=len*0.55; tx=len;
  linear_extrude(height=base_thickness)
  union(){
    translate([bx,0]) circle(r=base_r);
    hull(){translate([bx,0])circle(r=base_r);translate([sx,0])circle(r=shank_r);}
    hull(){translate([sx,0])circle(r=shank_r);translate([tx,0])circle(r=tip_r);}
  }
}

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

module wheel_solid(distances){
  n=len(distances);
  a=apothem(outer_flat_to_flat,n);
  union(){
    polygon_plate(n,outer_flat_to_flat,base_thickness);
    for(i=[0:n-1]){
      angN=-360*(i+0.5)/n;
      translate([a*cos(angN),a*sin(angN),0])
        rotate([0,0,angN]){
          sep=distances[i];
          translate([0,+sep/2,0])spike_single_flat();
          translate([0,-sep/2,0])spike_single_flat();
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
    edge_numbers_top(distances,apothem(outer_flat_to_flat,n));
  }
}

discriminator(distances_mm);
