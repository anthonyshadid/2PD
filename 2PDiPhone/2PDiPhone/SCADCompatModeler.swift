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

/// Generates STL that mirrors updated SCAD (with through-cut numbers).
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
    // ---- Parameters (matching SCAD defaults) ----
    static let outer_flat_to_flat = 63.5
    static let base_thickness     = 3.0

    static let spike_length       = 14.0
    static let base_d             = 3.0
    static let tip_d              = 0.6
    static let root_overlap       = 0.7

    static let hub_diameter       = 20.0
    static let thumb_depth        = 0.5

    // Labels (through-cut)
    static let label_size         = 3.0
    static let label_depth        = 0.5   // ignored for through-cut
    static let label_radial       = 0.80

    // Tessellation density
    static let fnPolygon          = 96
    static let fnRound            = 128

    static func makeTris(distances: [Double]) -> [T] {
        let n = distances.count
        let a = outer_flat_to_flat / 2.0
        let r = outer_flat_to_flat / (2.0 * cos(.pi/Double(n)))

        var tris: [T] = []

        // 1) n-gon plate
        let poly = (0..<n).map { i -> V in
            let ang = 2.0 * .pi * Double(i)/Double(n)
            return V(x: r * cos(ang), y: r * sin(ang), z: 0)
        }
        tris += extrudePolygon(poly, z0: 0, z1: base_thickness)

        // 2) spikes: sideways frustums centered through thickness
        for i in 0..<n {
            let angN = -2.0 * .pi * (Double(i) + 0.5) / Double(n)   // face normal angle
            let faceCenter = V(x: a * cos(angN), y: a * sin(angN), z: 0)

            // local frame: x=outward normal, y=along edge, z=thickness
            let xAxis = V(x: cos(angN), y: sin(angN), z: 0)
            let yAxis = V(x: -sin(angN), y: cos(angN), z: 0)
            let zAxis = V(x: 0, y: 0, z: 1)

            let rBase = base_d/2.0
            let rTip  = tip_d/2.0
            let sep   = distances[i]

            let basePlus  = faceCenter + yAxis*(+sep/2) + xAxis*(-root_overlap) + zAxis*(base_thickness/2)
            let baseMinus = faceCenter + yAxis*(-sep/2) + xAxis*(-root_overlap) + zAxis*(base_thickness/2)

            tris += frustumAlongAxis(baseCenter: basePlus,  axis: xAxis, h: spike_length, rBase: rBase, rTip: rTip, facets: fnRound)
            tris += frustumAlongAxis(baseCenter: baseMinus, axis: xAxis, h: spike_length, rBase: rBase, rTip: rTip, facets: fnRound)
        }

        // 3) thumb well (top pocket)
        tris += pocketTop(radius: hub_diameter/2, zTop: base_thickness, depth: thumb_depth)

        // 4) THROUGH-CUT numbers at rim
        for i in 0..<n {
            let angN = -2.0 * .pi * (Double(i) + 0.5) / Double(n)
            let cx = (label_radial * a) * cos(angN)
            let cy = (label_radial * a) * sin(angN)
            let center = V(x: cx, y: cy, z: base_thickness)

            let xAxis = V(x: cos(angN), y: sin(angN), z: 0)  // glyph vertical
            let yAxis = V(x:-sin(angN), y: cos(angN), z: 0)  // glyph horizontal

            let text = String(Int(distances[i].rounded()))
            tris += engraveSevenSegment(text: text,
                                        center: center,
                                        xAxis: xAxis,
                                        yAxis: yAxis,
                                        height: label_size,
                                        depth: label_depth,
                                        gap: 0.20 * label_size)
        }

        return tris
    }

    // --- Shape builders ---

    private static func frustumAlongAxis(baseCenter c0: V, axis: V, h: Double, rBase: Double, rTip: Double, facets: Int) -> [T] {
        let a = normalize(axis)
        let up = (abs(a.z) < 0.9) ? V(x:0,y:0,z:1) : V(x:1,y:0,z:0)
        let xAxis = a
        let yAxis = normalize(cross(up, xAxis))
        let zAxis = cross(xAxis, yAxis)
        func toWorld(_ x: Double, _ y: Double, _ z: Double) -> V { c0 + xAxis*x + yAxis*y + zAxis*z }

        let dA = 2.0 * .pi / Double(facets)
        var ts: [T] = []
        for i in 0..<facets {
            let a0 = Double(i)*dA, a1 = Double(i+1)*dA
            let y0b = rBase * cos(a0), z0b = rBase * sin(a0)
            let y1b = rBase * cos(a1), z1b = rBase * sin(a1)
            let y0t = rTip  * cos(a0), z0t = rTip  * sin(a0)
            let y1t = rTip  * cos(a1), z1t = rTip  * sin(a1)

            let b0 = toWorld(0, y0b, z0b), b1 = toWorld(0, y1b, z1b)
            let t0 = toWorld(h, y0t, z0t), t1 = toWorld(h, y1t, z1t)

            ts += quad(b0,b1,t1,t0)
            let cb = toWorld(0,0,0)
            ts.append(T(a: cb, b: b1, c: b0))
            let ct = toWorld(h,0,0)
            ts.append(T(a: ct, b: t0, c: t1))
        }
        return ts
    }

    private static func pocketTop(radius: Double, zTop: Double, depth: Double) -> [T] {
        let z0 = zTop - depth, z1 = zTop
        let facets = fnRound
        let dA = 2.0 * .pi / Double(facets)
        var ts: [T] = []
        for i in 0..<facets {
            let a0 = Double(i)*dA, a1 = Double(i+1)*dA
            let p00 = V(x: radius*cos(a0), y: radius*sin(a0), z: z0)
            let p01 = V(x: radius*cos(a1), y: radius*sin(a1), z: z0)
            let p10 = V(x: radius*cos(a0), y: radius*sin(a0), z: z1)
            let p11 = V(x: radius*cos(a1), y: radius*sin(a1), z: z1)
            ts += quad(p00,p01,p11,p10)
        }
        let c = V(x: 0, y: 0, z: z0)
        for i in 0..<facets {
            let a0 = Double(i)*dA, a1 = Double(i+1)*dA
            let p0 = V(x: radius*cos(a0), y: radius*sin(a0), z: z0)
            let p1 = V(x: radius*cos(a1), y: radius*sin(a1), z: z0)
            ts.append(T(a: c, b: p1, c: p0))
        }
        return ts
    }

    private static func extrudePolygon(_ poly0: [V], z0: Double, z1: Double) -> [T] {
        var poly = poly0
        if polygonArea(poly) < 0 { poly.reverse() }
        let b0 = poly.map { V(x: $0.x, y: $0.y, z: z0) }
        let b1 = poly.map { V(x: $0.x, y: $0.y, z: z1) }

        var ts: [T] = []
        for i in 1..<(b0.count-1) { ts.append(T(a: b0[0], b: b0[i+1], c: b0[i])) }
        for i in 1..<(b1.count-1) { ts.append(T(a: b1[0], b: b1[i],   c: b1[i+1])) }
        for i in 0..<poly.count {
            let j = (i+1) % poly.count
            ts += quad(b0[i], b0[j], b1[j], b1[i])
        }
        return ts
    }

    private static func quad(_ v0: V, _ v1: V, _ v2: V, _ v3: V) -> [T] { [T(a:v0,b:v1,c:v2), T(a:v0,b:v2,c:v3)] }
    private static func polygonArea(_ p: [V]) -> Double {
        var A = 0.0
        for i in 0..<p.count { let j = (i+1)%p.count; A += p[i].x*p[j].y - p[j].x*p[i].y }
        return 0.5*A
    }
    private static func cross(_ a: V, _ b: V) -> V { .init(x:a.y*b.z - a.z*b.y, y:a.z*b.x - a.x*b.z, z:a.x*b.y - a.y*b.x) }
    private static func normalize(_ v: V) -> V { let L=max(1e-12, sqrt(v.x*v.x + v.y*v.y + v.z*v.z)); return .init(x:v.x/L,y:v.y/L,z:v.z/L) }

    // ---------------- Seven-segment digits (THROUGH-CUT) ---------------------

    private struct SegRect { let u: Double, v: Double, uw: Double, vh: Double }

    private static func engraveSevenSegment(text: String,
                                            center: V,
                                            xAxis: V, yAxis: V,
                                            height: Double,
                                            depth: Double,
                                            gap: Double) -> [T] {
        // depth is ignored for through-cuts (we cut 0..base_thickness)
        let h = height
        let w = 0.6 * h
        let sw = 0.18 * h
        let digitAdvance = w + 0.20*h

        let chars = Array(text)
        let totalW = Double(chars.count) * digitAdvance - 0.20*h
        var ts: [T] = []

        for (idx, ch) in chars.enumerated() {
            let cx = -totalW/2 + Double(idx)*digitAdvance + w/2
            for rect in sevenSegmentRects(for: ch, w: w, h: h, sw: sw) {
                let uC = cx + rect.u
                let vC = rect.v
                ts += throughCutRect(uCenter: uC, vCenter: vC,
                                     uWidth: rect.uw, vHeight: rect.vh,
                                     frameCenter: center,
                                     xAxis: xAxis, yAxis: yAxis,
                                     z0: 0.0, z1: base_thickness)
            }
            _ = gap
        }
        return ts
    }

    private static func sevenSegmentRects(for ch: Character, w: Double, h: Double, sw: Double) -> [SegRect] {
        let topY    = +h/2 - sw/2
        let midY    = 0.0
        let botY    = -h/2 + sw/2
        let upY     = +h/4
        let downY   = -h/4
        let leftX   = -w/2 + sw/2
        let rightX  = +w/2 - sw/2

        func H(_ y: Double) -> SegRect { .init(u: 0,    v: y,    uw: w,  vh: sw) }
        func V(_ x: Double, _ y: Double) -> SegRect { .init(u: x, v: y,  uw: sw, vh: h/2 - sw/2) }

        let map: [Character: [String]] = [
            "0": ["a","b","c","d","e","f"],
            "1": ["b","c"],
            "2": ["a","b","g","e","d"],
            "3": ["a","b","g","c","d"],
            "4": ["f","g","b","c"],
            "5": ["a","f","g","c","d"],
            "6": ["a","f","g","e","c","d"],
            "7": ["a","b","c"],
            "8": ["a","b","c","d","e","f","g"],
            "9": ["a","b","c","d","f","g"]
        ]

        var rects: [SegRect] = []
        for s in map[ch] ?? [] {
            switch s {
            case "a": rects.append(H(topY))
            case "d": rects.append(H(botY))
            case "g": rects.append(H(midY))
            case "b": rects.append(V(rightX, upY))
            case "c": rects.append(V(rightX, downY))
            case "e": rects.append(V(leftX,  downY))
            case "f": rects.append(V(leftX,  upY))
            default: break
            }
        }
        return rects
    }

    // Through-cut rectangular hole (builds the inner walls only; no caps)
    private static func throughCutRect(uCenter: Double, vCenter: Double,
                                       uWidth: Double, vHeight: Double,
                                       frameCenter: V,
                                       xAxis: V, yAxis: V,
                                       z0: Double, z1: Double) -> [T] {
        let du = uWidth/2, dv = vHeight/2

        let pTop = [
            frameCenter + yAxis*(uCenter - du) + xAxis*(vCenter - dv),
            frameCenter + yAxis*(uCenter + du) + xAxis*(vCenter - dv),
            frameCenter + yAxis*(uCenter + du) + xAxis*(vCenter + dv),
            frameCenter + yAxis*(uCenter - du) + xAxis*(vCenter + dv)
        ].map { V(x: $0.x, y: $0.y, z: z1) }

        let pBot = pTop.map { V(x: $0.x, y: $0.y, z: z0) }

        var ts: [T] = []
        ts += quad(pBot[0], pBot[1], pTop[1], pTop[0]) // front
        ts += quad(pBot[1], pBot[2], pTop[2], pTop[1]) // right
        ts += quad(pBot[2], pBot[3], pTop[3], pTop[2]) // back
        ts += quad(pBot[3], pBot[0], pTop[0], pTop[3]) // left
        return ts
    }
}
