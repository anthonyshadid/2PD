//
//  STLModeler.swift
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//

import Foundation

// Public entry — matches your SCAD “discriminator(distances)” (minus text engraving)
enum STLGenError: Error, LocalizedError {
    case needAtLeast3, badDistances
    var errorDescription: String? {
        switch self {
        case .needAtLeast3: return "distances_mm must have at least 3 entries."
        case .badDistances: return "Please enter numeric distances (mm)."
        }
    }
}

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

// ------------------ Geometry core ------------------

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
    // --- SCAD params (match your file) ---
    static let outer_flat_to_flat = 63.5
    static let base_thickness     = 3.0
    static let spike_length       = 14.0
    static let base_d             = 3.0
    static let shank_d            = 1.4
    static let tip_d              = 0.6
    static let root_overlap       = 0.7
    static let hub_diameter       = 20.0
    static let thumb_depth        = 0.5
    static let fn                 = 72  // $fn

    static func makeTris(distances: [Double]) -> [T] {
        let n = distances.count
        let a = outer_flat_to_flat / 2.0                    // apothem
        let r = outer_flat_to_flat / (2.0 * cos(.pi/Double(n))) // circumscribed radius

        var tris: [T] = []

        // 1) n-gon plate (prism)
        let poly = (0..<n).map { i -> V in
            let ang = 2.0 * .pi * Double(i)/Double(n)
            return V(x: r * cos(ang), y: r * sin(ang), z: 0)
        }
        tris += extrudePolygon(poly, z0: 0, z1: base_thickness)

        // 2) two spikes per side, placed like SCAD: at angN = -360*(i+0.5)/n, centered at apothem
        for i in 0..<n {
            let angN = -2.0 * .pi * (Double(i) + 0.5) / Double(n)
            let center = V(x: a * cos(angN), y: a * sin(angN), z: 0)
            let xAxis  = V(x: cos(angN), y: sin(angN), z: 0)         // along spike axis
            let yAxis  = V(x:-sin(angN), y: cos(angN), z: 0)         // lateral (+/- sep/2)

            let baseR  = base_d/2, shankR = shank_d/2, tipR = tip_d/2
            let bx     = -root_overlap
            let sx     = spike_length * 0.55
            let tx     = spike_length

            // outline samples the union/hull shape (good printable approximation)
            let outline = spikeOutline(bx: bx, sx: sx, tx: tx,
                                       r0: baseR, r1: shankR, r2: tipR)

            func place(_ offsetY: Double) -> [V] {
                outline.map { p in
                    let local = V(x: p.x, y: p.y + offsetY, z: 0)
                    return center + xAxis*local.x + yAxis*local.y
                }
            }
            tris += extrudePolygon(place(+distances[i]/2), z0: 0, z1: base_thickness)
            tris += extrudePolygon(place(-distances[i]/2), z0: 0, z1: base_thickness)
        }

        // 3) thumb well: shallow pocket at top (NOT a through-hole)
        tris += pocketTop(radius: hub_diameter/2, zTop: base_thickness, depth: thumb_depth)

        return tris
    }

    // --- spike outline in local XY (CCW polygon) ---
    private static func spikeOutline(bx: Double, sx: Double, tx: Double,
                                     r0: Double, r1: Double, r2: Double) -> [V] {
        let steps = max(36, fn)
        var up: [V] = [], dn: [V] = []
        for i in 0...steps {
            let t = Double(i)/Double(steps)
            let x = bx + (tx - bx)*t
            let r = (x <= sx)
                ? r0 + (r1 - r0) * ( (x - bx) / max(1e-9, sx - bx) )
                : r1 + (r2 - r1) * ( (x - sx) / max(1e-9, tx - sx) )
            up.append(V(x: x, y: +r, z: 0))
            dn.append(V(x: x, y: -r, z: 0))
        }
        dn.reverse()
        var poly = up + dn
        if polygonArea(poly) < 0 { poly.reverse() }
        return poly
    }

    // --- pocket subtraction by construction (no through hole) ---
    private static func pocketTop(radius: Double, zTop: Double, depth: Double) -> [T] {
        let z0 = zTop - depth, z1 = zTop
        let dA = 2.0 * .pi / Double(fn)
        var tris: [T] = []
        // wall
        for i in 0..<fn {
            let a0 = Double(i)*dA, a1 = Double(i+1)*dA
            let p00 = V(x: radius*cos(a0), y: radius*sin(a0), z: z0)
            let p01 = V(x: radius*cos(a1), y: radius*sin(a1), z: z0)
            let p10 = V(x: radius*cos(a0), y: radius*sin(a0), z: z1)
            let p11 = V(x: radius*cos(a1), y: radius*sin(a1), z: z1)
            tris += quad(p00,p01,p11,p10)
        }
        // bottom
        let c = V(x: 0, y: 0, z: z0)
        for i in 0..<fn {
            let a0 = Double(i)*dA, a1 = Double(i+1)*dA
            let p0 = V(x: radius*cos(a0), y: radius*sin(a0), z: z0)
            let p1 = V(x: radius*cos(a1), y: radius*sin(a1), z: z0)
            tris.append(T(a: c, b: p1, c: p0))
        }
        return tris
    }

    // --- polygon extrude (adds top/bottom + side walls) ---
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
        // sides
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
}
