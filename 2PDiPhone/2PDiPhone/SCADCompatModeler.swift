//
//  STLModeler.swift
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//

import Foundation

// Public API -----------------------------------------------------------------

enum STLGenError: Error, LocalizedError {
    case needAtLeast3, badDistances
    var errorDescription: String? {
        switch self {
        case .needAtLeast3: return "distances_mm must have at least 3 entries."
        case .badDistances: return "Please enter numeric distances (mm)."
        }
    }
}

/// Generates an STL that mirrors your updated SCAD (minus chamfer & text).
func generateSCADCompatSTL(distancesMM: [Double]) throws -> URL {
    guard distancesMM.count >= 3 else { throw STLGenError.needAtLeast3 }
    guard distancesMM.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw STLGenError.badDistances }

    let tris = SCADCompatModeler.makeTris(distances: distancesMM)
    let data = STLWriter.writeASCII(tris: tris, name: "2PD_wheel")

    let stamp = ISO8601DateFormatter().string(from: Date())
    let name = "wheel_" + distancesMM.map{ String(Int($0.rounded())) }.joined(separator: "-") + "_\(stamp).stl"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try data.write(to: url, options: .atomic)
    return url
}

// Geometry core --------------------------------------------------------------

fileprivate struct V { var x: Double, y: Double, z: Double }
fileprivate extension V {
    static func +(l: V, r: V) -> V { .init(x:l.x+r.x, y:l.y+r.y, z:l.z+r.z) }
    static func -(l: V, r: V) -> V { .init(x:l.x-r.x, y:l.y-r.y, z:l.z-r.z) }
    static func *(l: V, s: Double) -> V { .init(x:l.x*s, y:l.y*s, z:l.z*s) }
}
fileprivate struct T { var a: V, b: V, c: V }

fileprivate enum STLWriter {
    static func writeASCII(tris: [T], name: String) -> Data {
        func n(_ t: T) -> V {
            let u = t.b - t.a, v = t.c - t.a
            let nx = u.y*v.z - u.z*v.y, ny = u.z*v.x - u.x*v.z, nz = u.x*v.y - u.y*v.x
            let L = max(1e-12, sqrt(nx*nx+ny*ny+nz*nz))
            return .init(x:nx/L, y:ny/L, z:nz/L)
        }
        func f(_ v: Double) -> String { String(format: "%.6f", v) }
        var s = "solid \(name)\n"
        for t in tris {
            let nn = n(t)
            s += " facet normal \(f(nn.x)) \(f(nn.y)) \(f(nn.z))\n  outer loop\n"
            s += "   vertex \(f(t.a.x)) \(f(t.a.y)) \(f(t.a.z))\n"
            s += "   vertex \(f(t.b.x)) \(f(t.b.y)) \(f(t.b.z))\n"
            s += "   vertex \(f(t.c.x)) \(f(t.c.y)) \(f(t.c.z))\n"
            s += "  endloop\n endfacet\n"
        }
        s += "endsolid \(name)\n"
        return Data(s.utf8)
    }
}

fileprivate enum SCADCompatModeler {
    // ---- Parameters ----
    static let outer_flat_to_flat = 63.5
    static let base_thickness     = 3.0

    static let spike_length       = 14.0      // along outward normal (X in local)
    static let base_d             = 3.0       // diameter at body
    static let tip_d              = 0.6       // diameter at tip
    static let root_overlap       = 0.7       // how far the base intrudes into the body

    static let hub_diameter       = 20.0
    static let thumb_depth        = 0.5

    // Tessellation density (approx. SCAD $fn=96 / local 128)
    static let fnPolygon          = 96
    static let fnRound            = 128

    static func makeTris(distances: [Double]) -> [T] {
        let n = distances.count
        let a = outer_flat_to_flat / 2.0                           // apothem
        let r = outer_flat_to_flat / (2.0 * cos(.pi/Double(n)))     // circ radius

        var tris: [T] = []

        // 1) n-gon plate (extruded prism)
        let poly = (0..<n).map { i -> V in
            let ang = 2.0 * .pi * Double(i)/Double(n)
            return V(x: r * cos(ang), y: r * sin(ang), z: 0)
        }
        tris += extrudePolygon(poly, z0: 0, z1: base_thickness)

        // 2) spikes: sideways frustums, centered in thickness, base intrudes by root_overlap
        for i in 0..<n {
            let angN = -2.0 * .pi * (Double(i) + 0.5) / Double(n)   // face normal angle
            let faceCenter = V(x: a * cos(angN), y: a * sin(angN), z: 0)

            // local frame: x=outward normal, y=along edge, z=thickness
            let xAxis = V(x: cos(angN), y: sin(angN), z: 0)
            let yAxis = V(x: -sin(angN), y: cos(angN), z: 0)
            let zAxis = V(x: 0, y: 0, z: 1)

            let rBase = base_d/2.0
            let rTip  = tip_d/2.0

            // Base center location for each spike:
            //   start at face center, move ±sep/2 along local Y,
            //   push inward by root_overlap along -X,
            //   center through thickness at z = base_thickness/2
            let sep = distances[i]

            let basePlus  = faceCenter + yAxis*(+sep/2) + xAxis*(-root_overlap) + zAxis*(base_thickness/2)
            let baseMinus = faceCenter + yAxis*(-sep/2) + xAxis*(-root_overlap) + zAxis*(base_thickness/2)

            tris += frustumAlongAxis(baseCenter: basePlus,
                                     axis: xAxis,
                                     h: spike_length,
                                     rBase: rBase,
                                     rTip: rTip,
                                     facets: fnRound)

            tris += frustumAlongAxis(baseCenter: baseMinus,
                                     axis: xAxis,
                                     h: spike_length,
                                     rBase: rBase,
                                     rTip: rTip,
                                     facets: fnRound)
        }

        // 3) Thumb well (shallow top pocket, not a through-hole)
        tris += pocketTop(radius: hub_diameter/2, zTop: base_thickness, depth: thumb_depth)

        return tris
    }

    // --- Shape builders ---

    /// Frustum (truncated cone) oriented along `axis` starting at `baseCenter` and extending +axis by `h`.
    private static func frustumAlongAxis(baseCenter c0: V, axis: V, h: Double, rBase: Double, rTip: Double, facets: Int) -> [T] {
        let a = normalize(axis)
        let up = (abs(a.z) < 0.9) ? V(x:0,y:0,z:1) : V(x:1,y:0,z:0)
        let xAxis = a
        let yAxis = normalize(cross(up, xAxis))
        let zAxis = cross(xAxis, yAxis)

        func toWorld(_ x: Double, _ y: Double, _ z: Double) -> V {
            return c0 + xAxis*x + yAxis*y + zAxis*z
        }

        let dA = 2.0 * .pi / Double(facets)
        var ts: [T] = []

        // Rings at base (x=0) and tip (x=h)
        for i in 0..<facets {
            let a0 = Double(i)*dA
            let a1 = Double(i+1)*dA

            let y0b = rBase * cos(a0), z0b = rBase * sin(a0)
            let y1b = rBase * cos(a1), z1b = rBase * sin(a1)

            let y0t = rTip  * cos(a0), z0t = rTip  * sin(a0)
            let y1t = rTip  * cos(a1), z1t = rTip  * sin(a1)

            let b0 = toWorld(0,   y0b, z0b)
            let b1 = toWorld(0,   y1b, z1b)
            let t0 = toWorld(h,   y0t, z0t)
            let t1 = toWorld(h,   y1t, z1t)

            // side quad
            ts += quad(b0, b1, t1, t0)

            // base cap (faces -axis): center at x=0
            let cb = toWorld(0, 0, 0)
            ts.append(T(a: cb, b: b1, c: b0))

            // tip cap (faces +axis): center at x=h
            let ct = toWorld(h, 0, 0)
            ts.append(T(a: ct, b: t0, c: t1))
        }
        return ts
    }

    /// Pocket at top (subtract by construction)
    private static func pocketTop(radius: Double, zTop: Double, depth: Double) -> [T] {
        let z0 = zTop - depth, z1 = zTop
        let facets = fnRound
        let dA = 2.0 * .pi / Double(facets)
        var ts: [T] = []

        // vertical wall
        for i in 0..<facets {
            let a0 = Double(i)*dA, a1 = Double(i+1)*dA
            let p00 = V(x: radius*cos(a0), y: radius*sin(a0), z: z0)
            let p01 = V(x: radius*cos(a1), y: radius*sin(a1), z: z0)
            let p10 = V(x: radius*cos(a0), y: radius*sin(a0), z: z1)
            let p11 = V(x: radius*cos(a1), y: radius*sin(a1), z: z1)
            ts += quad(p00,p01,p11,p10)
        }
        // bottom disc
        let c = V(x: 0, y: 0, z: z0)
        for i in 0..<facets {
            let a0 = Double(i)*dA, a1 = Double(i+1)*dA
            let p0 = V(x: radius*cos(a0), y: radius*sin(a0), z: z0)
            let p1 = V(x: radius*cos(a1), y: radius*sin(a1), z: z0)
            ts.append(T(a: c, b: p1, c: p0))
        }
        return ts
    }

    /// Extrude arbitrary simple polygon between z0 and z1 (adds top, bottom, and walls).
    private static func extrudePolygon(_ poly0: [V], z0: Double, z1: Double) -> [T] {
        var poly = poly0
        if polygonArea(poly) < 0 { poly.reverse() }
        let b0 = poly.map { V(x: $0.x, y: $0.y, z: z0) }
        let b1 = poly.map { V(x: $0.x, y: $0.y, z: z1) }

        var ts: [T] = []
        // bottom (faces down)
        for i in 1..<(b0.count-1) { ts.append(T(a: b0[0], b: b0[i+1], c: b0[i])) }
        // top (faces up)
        for i in 1..<(b1.count-1) { ts.append(T(a: b1[0], b: b1[i],   c: b1[i+1])) }
        // side walls
        for i in 0..<poly.count {
            let j = (i+1) % poly.count
            ts += quad(b0[i], b0[j], b1[j], b1[i])
        }
        return ts
    }

    private static func quad(_ v0: V, _ v1: V, _ v2: V, _ v3: V) -> [T] {
        [T(a:v0,b:v1,c:v2), T(a:v0,b:v2,c:v3)]
    }
    private static func polygonArea(_ p: [V]) -> Double {
        var A = 0.0
        for i in 0..<p.count {
            let j = (i+1)%p.count
            A += p[i].x*p[j].y - p[j].x*p[i].y
        }
        return 0.5*A
    }
    private static func cross(_ a: V, _ b: V) -> V {
        .init(x: a.y*b.z - a.z*b.y, y: a.z*b.x - a.x*b.z, z: a.x*b.y - a.y*b.x)
    }
    private static func normalize(_ v: V) -> V {
        let L = max(1e-12, sqrt(v.x*v.x + v.y*v.y + v.z*v.z))
        return .init(x: v.x/L, y: v.y/L, z: v.z/L)
    }
}
