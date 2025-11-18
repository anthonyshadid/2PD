
//
//  STLModeler.swift
//  2PDiPhone

//  Created by Keyvon R on 11/9/25.
//  Updated to match flat-prong SCAD with 7-seg engraved numbers on both sides
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

/// Generates STL that mirrors the current SCAD (flat prongs + engraved 7-seg digits both sides).
func generateSCADCompatSTL(distancesMM: [Double]) throws -> URL {
    guard distancesMM.count >= 3 else { throw STLGenError.needAtLeast3 }
    guard distancesMM.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw STLGenError.badDistances }

    let tris = SCADCompatModeler.makeTris(distances: distancesMM)
    let data = STLWriter.writeASCII(tris: tris, name: "2PD_wheel")

    let stamp = ISO8601DateFormatter().string(from: Date())
    let name = "wheel_" + distancesMM.map { String(Int($0.rounded())) }.joined(separator: "-") + "_\(stamp).stl"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try data.write(to: url, options: .atomic)
    return url
}

// Geometry core --------------------------------------------------------------

fileprivate struct V { var x: Double, y: Double, z: Double }

fileprivate extension V {
    static func +(l: V, r: V) -> V { .init(x: l.x + r.x, y: l.y + r.y, z: l.z + r.z) }
    static func -(l: V, r: V) -> V { .init(x: l.x - r.x, y: l.y - r.y, z: l.z - r.z) }
    static func *(l: V, s: Double) -> V { .init(x: l.x * s, y: l.y * s, z: l.z * s) }
}

fileprivate struct T { var a: V, b: V, c: V }

fileprivate enum STLWriter {
    static func writeASCII(tris: [T], name: String) -> Data {
        func normal(_ t: T) -> V {
            let u = t.b - t.a
            let v = t.c - t.a
            let nx = u.y * v.z - u.z * v.y
            let ny = u.z * v.x - u.x * v.z
            let nz = u.x * v.y - u.y * v.x
            let L = max(1e-12, sqrt(nx * nx + ny * ny + nz * nz))
            return .init(x: nx / L, y: ny / L, z: nz / L)
        }
        func f(_ v: Double) -> String { String(format: "%.6f", v) }

        var s = "solid \(name)\n"
        for t in tris {
            let n = normal(t)
            s += " facet normal \(f(n.x)) \(f(n.y)) \(f(n.z))\n"
            s += "  outer loop\n"
            s += "   vertex \(f(t.a.x)) \(f(t.a.y)) \(f(t.a.z))\n"
            s += "   vertex \(f(t.b.x)) \(f(t.b.y)) \(f(t.b.z))\n"
            s += "   vertex \(f(t.c.x)) \(f(t.c.y)) \(f(t.c.z))\n"
            s += "  endloop\n"
            s += " endfacet\n"
        }
        s += "endsolid \(name)\n"
        return Data(s.utf8)
    }
}

// SCAD-compatible modeler ----------------------------------------------------

fileprivate enum SCADCompatModeler {
    // ---- Parameters (matching your SCAD defaults) ----
    static let outer_flat_to_flat = 67.0
    static let base_thickness     = 3.0

    // Flat prongs
    static let spike_length  = 16.0
    static let base_d        = 2.2
    static let root_overlap  = 0.0

    // Hub / thumb well
    static let hub_diameter  = 20.0
    static let thumb_depth   = 0.5

    // Labels (7-segment, engraved both sides)
    static let label_size    = 4.0
    static let label_depth   = 0.5
    static let label_radial  = 0.80

    // Tessellation
    static let fnPolygon     = 96
    static let fnRound       = 96

    // Utility (same meaning as SCAD)
    private static func apothem(acrossFlats: Double, n: Int) -> Double {
        acrossFlats / 2.0
    }
    private static func circRadius(acrossFlats: Double, n: Int) -> Double {
        acrossFlats / (2.0 * cos(.pi / Double(n)))
    }

    // Safe engraving depth (so top+bottom never meet)
    private static func engrDepth() -> Double {
        let maxDepth = base_thickness / 2.0 - 0.05
        return min(label_depth, maxDepth)
    }

    // Main entry
    static func makeTris(distances: [Double]) -> [T] {
        let n = distances.count
        let a = apothem(acrossFlats: outer_flat_to_flat, n: n)
        let r = circRadius(acrossFlats: outer_flat_to_flat, n: n)

        var tris: [T] = []

        // 1) n-gon base plate
        let basePoly2D: [V] = (0..<n).map { i in
            let ang = 2.0 * .pi * Double(i) / Double(n)
            return V(x: r * cos(ang), y: r * sin(ang), z: 0)
        }
        tris += extrudePolygon(basePoly2D, z0: 0.0, z1: base_thickness)

        // 2) Flat prongs (triangles) at each face, two per edge (sep = distance)
        for i in 0..<n {
            let sep = distances[i]
            let angN = -2.0 * .pi * (Double(i) + 0.5) / Double(n)
            let cx = a * cos(angN)
            let cy = a * sin(angN)

            let cosA = cos(angN)
            let sinA = sin(angN)

            // local 2D vertices of prong triangle in (x,y) before rotation/translation
            let localVerts: [(Double, Double)] = [
                (-root_overlap, -base_d / 2.0),
                (-root_overlap,  base_d / 2.0),
                ( spike_length,  0.0)
            ]

            // two prongs per face: ±sep/2 along local "y"
            for sign in [+1.0, -1.0] {
                let polyWorld: [V] = localVerts.map { (lx, ly) in
                    let yShift = ly + sign * sep / 2.0
                    // rotate by angN, then translate to (cx,cy)
                    let wx = cx + lx * cosA - yShift * sinA
                    let wy = cy + lx * sinA + yShift * cosA
                    return V(x: wx, y: wy, z: 0.0)
                }
                tris += extrudePolygon(polyWorld, z0: 0.0, z1: base_thickness)
            }
        }

        // 3) Thumb well pocket (top)
        tris += pocketTop(radius: hub_diameter / 2.0,
                          zTop: base_thickness,
                          depth: thumb_depth)

        // 4) Engraved numbers (7-seg) on top and bottom
        let depth = engrDepth()
        for i in 0..<n {
            let value = distances[i]
            let angN = -2.0 * .pi * (Double(i) + 0.5) / Double(n)
            let labelR = label_radial * a

            let cx = labelR * cos(angN)
            let cy = labelR * sin(angN)

            // Local glyph axes (xAxis = outward, yAxis = along edge)
            let xAxis = V(x: cos(angN),  y: sin(angN),  z: 0)
            let yAxis = V(x: -sin(angN), y: cos(angN),  z: 0)

            // TOP engraving (into top surface: z from top-depth .. top)
            let centerTop = V(x: cx, y: cy, z: base_thickness)
            tris += engraveSevenSegmentNumber(value,
                                              center: centerTop,
                                              xAxis: xAxis,
                                              yAxis: yAxis,
                                              height: label_size,
                                              z0: base_thickness - depth,
                                              z1: base_thickness)

            // BOTTOM engraving (into bottom surface: z from 0 .. depth)
            let centerBottom = V(x: cx, y: cy, z: 0.0)
            tris += engraveSevenSegmentNumber(value,
                                              center: centerBottom,
                                              xAxis: xAxis,
                                              yAxis: yAxis,
                                              height: label_size,
                                              z0: 0.0,
                                              z1: depth)
        }

        return tris
    }

    // MARK: - Primitives / helpers ------------------------------------------

    private static func extrudePolygon(_ poly0: [V], z0: Double, z1: Double) -> [T] {
        // poly0: vertices with x,y used; z ignored
        guard poly0.count >= 3 else { return [] }
        var poly = poly0
        if polygonArea(poly) < 0 { poly.reverse() }

        let b0 = poly.map { V(x: $0.x, y: $0.y, z: z0) }
        let b1 = poly.map { V(x: $0.x, y: $0.y, z: z1) }

        var ts: [T] = []

        // bottom
        for i in 1..<(b0.count - 1) {
            ts.append(T(a: b0[0], b: b0[i+1], c: b0[i]))
        }
        // top
        for i in 1..<(b1.count - 1) {
            ts.append(T(a: b1[0], b: b1[i], c: b1[i+1]))
        }
        // sides
        for i in 0..<poly.count {
            let j = (i + 1) % poly.count
            ts += quad(b0[i], b0[j], b1[j], b1[i])
        }
        return ts
    }

    private static func quad(_ v0: V, _ v1: V, _ v2: V, _ v3: V) -> [T] {
        [T(a: v0, b: v1, c: v2), T(a: v0, b: v2, c: v3)]
    }

    private static func polygonArea(_ p: [V]) -> Double {
        var A = 0.0
        for i in 0..<p.count {
            let j = (i + 1) % p.count
            A += p[i].x * p[j].y - p[j].x * p[i].y
        }
        return 0.5 * A
    }

    private static func cross(_ a: V, _ b: V) -> V {
        .init(x: a.y * b.z - a.z * b.y,
              y: a.z * b.x - a.x * b.z,
              z: a.x * b.y - a.y * b.x)
    }

    private static func normalize(_ v: V) -> V {
        let L = max(1e-12, sqrt(v.x * v.x + v.y * v.y + v.z * v.z))
        return .init(x: v.x / L, y: v.y / L, z: v.z / L)
    }

    // Cylindrical pocket at top (thumb well)
    private static func pocketTop(radius: Double, zTop: Double, depth: Double) -> [T] {
        let z0 = zTop - depth
        let z1 = zTop
        let facets = fnRound
        let dA = 2.0 * .pi / Double(facets)
        var ts: [T] = []

        // cylindrical wall
        for i in 0..<facets {
            let a0 = Double(i) * dA
            let a1 = Double(i + 1) * dA
            let p00 = V(x: radius * cos(a0), y: radius * sin(a0), z: z0)
            let p01 = V(x: radius * cos(a1), y: radius * sin(a1), z: z0)
            let p10 = V(x: radius * cos(a0), y: radius * sin(a0), z: z1)
            let p11 = V(x: radius * cos(a1), y: radius * sin(a1), z: z1)
            ts += quad(p00, p01, p11, p10)
        }

        // pocket bottom
        let c = V(x: 0, y: 0, z: z0)
        for i in 0..<facets {
            let a0 = Double(i) * dA
            let a1 = Double(i + 1) * dA
            let p0 = V(x: radius * cos(a0), y: radius * sin(a0), z: z0)
            let p1 = V(x: radius * cos(a1), y: radius * sin(a1), z: z0)
            ts.append(T(a: c, b: p1, c: p0))
        }

        return ts
    }

    // MARK: - Seven-seg digits (engraved pockets) ----------------------------

    private struct SegRect {
        let u: Double, v: Double, uw: Double, vh: Double
    }

    // Numeric seven-seg engraving for a distance value
    private static func engraveSevenSegmentNumber(_ value: Double,
                                                  center: V,
                                                  xAxis: V,
                                                  yAxis: V,
                                                  height: Double,
                                                  z0: Double,
                                                  z1: Double) -> [T] {
        let numInt = Int((value).rounded())
        let text = String(numInt)         // "2", "10", "25", etc.

        let h = height
        let w = 0.6 * h
        let sw = 0.18 * h
        let digitAdvance = w + 0.20 * h

        let chars = Array(text)
        let totalW = Double(chars.count) * digitAdvance - 0.20 * h

        var ts: [T] = []

        for (idx, ch) in chars.enumerated() {
            let cx = -totalW / 2.0 + Double(idx) * digitAdvance + w / 2.0
            for rect in sevenSegmentRects(for: ch, w: w, h: h, sw: sw) {
                let uC = cx + rect.u
                let vC = rect.v
                ts += pocketRect(uCenter: uC,
                                 vCenter: vC,
                                 uWidth: rect.uw,
                                 vHeight: rect.vh,
                                 frameCenter: center,
                                 xAxis: xAxis,
                                 yAxis: yAxis,
                                 z0: z0, z1: z1)
            }
        }
        return ts
    }

    // Rectangles for 7-seg segments for a single character
    private static func sevenSegmentRects(for ch: Character,
                                          w: Double,
                                          h: Double,
                                          sw: Double) -> [SegRect] {
        let topY    = +h / 2.0 - sw / 2.0
        let midY    = 0.0
        let botY    = -h / 2.0 + sw / 2.0
        let upY     = +h / 4.0
        let downY   = -h / 4.0
        let leftX   = -w / 2.0 + sw / 2.0
        let rightX  = +w / 2.0 - sw / 2.0

        func H(_ y: Double) -> SegRect {
            .init(u: 0.0, v: y, uw: w, vh: sw)
        }
        func V(_ x: Double, _ y: Double) -> SegRect {
            .init(u: x, v: y, uw: sw, vh: h / 2.0 - sw / 2.0)
        }

        // segment pattern per digit (a,b,c,d,e,f,g)
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

    // Rectangular pocket in glyph-local (u,v) coordinates, extruded in z
    private static func pocketRect(uCenter: Double,
                                   vCenter: Double,
                                   uWidth: Double,
                                   vHeight: Double,
                                   frameCenter: V,
                                   xAxis: V,
                                   yAxis: V,
                                   z0: Double,
                                   z1: Double) -> [T] {
        let du = uWidth / 2.0
        let dv = vHeight / 2.0

        // map (u,v) -> world XY: frameCenter + u * yAxis + v * xAxis
        func toWorldXY(u: Double, v: Double) -> V {
            frameCenter + yAxis * u + xAxis * v
        }

        let p2D: [V] = [
            toWorldXY(u: uCenter - du, v: vCenter - dv),
            toWorldXY(u: uCenter + du, v: vCenter - dv),
            toWorldXY(u: uCenter + du, v: vCenter + dv),
            toWorldXY(u: uCenter - du, v: vCenter + dv)
        ]

        // build as small prism with z from z0 to z1
        let bottom = p2D.map { V(x: $0.x, y: $0.y, z: z0) }
        let top    = p2D.map { V(x: $0.x, y: $0.y, z: z1) }

        var ts: [T] = []
        // sides
        ts += quad(bottom[0], bottom[1], top[1], top[0])
        ts += quad(bottom[1], bottom[2], top[2], top[1])
        ts += quad(bottom[2], bottom[3], top[3], top[2])
        ts += quad(bottom[3], bottom[0], top[0], top[3])
        // bottom cap
        ts.append(T(a: bottom[0], b: bottom[2], c: bottom[1]))
        ts.append(T(a: bottom[0], b: bottom[3], c: bottom[2]))
        // top cap
        ts.append(T(a: top[0], b: top[1], c: top[2]))
        ts.append(T(a: top[0], b: top[2], c: top[3]))

        return ts
    }
}
