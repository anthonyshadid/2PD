
//
//  SCADCompatModeler.swift
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//  Updated to match discriminator.scad: tapered prongs (hull of 3 circles),
//  prong_thickness=1.4, raised labels on top, lanyard corner hole.
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

func generateSCADCompatSTL(distancesMM: [Double]) throws -> URL {
    guard distancesMM.count >= 3 else { throw STLGenError.needAtLeast3 }
    guard distancesMM.allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw STLGenError.badDistances }

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
fileprivate typealias V2 = (Double, Double)

fileprivate extension V {
    static func +(l: V, r: V) -> V { .init(x: l.x+r.x, y: l.y+r.y, z: l.z+r.z) }
    static func -(l: V, r: V) -> V { .init(x: l.x-r.x, y: l.y-r.y, z: l.z-r.z) }
    static func *(l: V, s: Double) -> V { .init(x: l.x*s, y: l.y*s, z: l.z*s) }
}

fileprivate struct T { var a: V, b: V, c: V }

fileprivate enum STLWriter {
    static func writeASCII(tris: [T], name: String) -> Data {
        func normal(_ t: T) -> V {
            let u = t.b - t.a, v = t.c - t.a
            let nx = u.y*v.z - u.z*v.y
            let ny = u.z*v.x - u.x*v.z
            let nz = u.x*v.y - u.y*v.x
            let L = max(1e-12, sqrt(nx*nx+ny*ny+nz*nz))
            return .init(x: nx/L, y: ny/L, z: nz/L)
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
            s += "  endloop\n endfacet\n"
        }
        s += "endsolid \(name)\n"
        return Data(s.utf8)
    }
}

// SCAD-compatible modeler ----------------------------------------------------

fileprivate enum SCADCompatModeler {

    // ---- Parameters matching discriminator.scad defaults ----
    static let outer_flat_to_flat = 40.0
    static let base_thickness     = 3.0
    static let prong_thickness    = 1.4     // prongs are shorter than body

    static let spike_length = 7.0
    static let base_d       = 3.0
    static let shank_d      = 1.4
    static let tip_d        = 0.15
    static let root_overlap = 0.7

    static let hub_diameter = 17.0
    static let thumb_depth  = 0.5

    static let label_size   = 4.3
    static let label_depth  = 0.5
    static let label_radial = 0.80

    static let lanyard_hole_d     = 3.5
    static let lanyard_hole_inset = 3.35

    static let fnRound = 72

    // ---- Utility ----
    private static func apothem(acrossFlats: Double, n: Int) -> Double { acrossFlats / 2.0 }
    private static func circRadius(acrossFlats: Double, n: Int) -> Double {
        acrossFlats / (2.0 * cos(.pi / Double(n)))
    }

    // ---- Main entry ----
    static func makeTris(distances: [Double]) -> [T] {
        let n  = distances.count
        let a  = apothem(acrossFlats: outer_flat_to_flat, n: n)
        let r  = circRadius(acrossFlats: outer_flat_to_flat, n: n)

        // Octagon corners (CCW), matching SCAD polygon_plate
        let bodyPoly: [V] = (0..<n).map { i in
            let ang = 2.0 * .pi * Double(i) / Double(n)
            return V(x: r * cos(ang), y: r * sin(ang), z: 0)
        }

        // Lanyard hole center: at corner between face 0 and face 1
        let lanyardAng = 2.0 * .pi / Double(n)
        let lR  = r - lanyard_hole_inset
        let lCx = lR * cos(lanyardAng)
        let lCy = lR * sin(lanyardAng)

        var tris: [T] = []

        // 1) Body plate + thumb-well pocket
        tris += makeBodyTris(
            outer: bodyPoly,
            lanyardCx: lCx, lanyardCy: lCy, lanyardR: lanyard_hole_d / 2.0,
            hubR: hub_diameter / 2.0,
            z0: 0.0, z1: base_thickness, pocketDepth: thumb_depth
        )

        // 2) Tapered prongs, one pair per face, CCW angle order matching SCAD
        let profile = prongProfile2D()
        for i in 0..<n {
            let sep  = distances[i]
            let angN = 2.0 * .pi * (Double(i) + 0.5) / Double(n)   // CCW
            let cx = a * cos(angN), cy = a * sin(angN)
            let cosA = cos(angN),   sinA = sin(angN)

            let signs: [Double] = sep == 0 ? [0.0] : [+1.0, -1.0]
            for sign in signs {
                let polyWorld: [V] = profile.map { (lx, ly) in
                    let yShift = ly + sign * sep / 2.0
                    return V(x: cx + lx * cosA - yShift * sinA,
                             y: cy + lx * sinA + yShift * cosA,
                             z: 0.0)
                }
                tris += extrudePolygon(polyWorld, z0: 0.0, z1: prong_thickness)
            }
        }

        // 3) Raised labels on top only, matching SCAD edge_numbers_top
        //    SCAD: translate to label position, rotate([0,0,angN-90]), linear_extrude(label_depth) text()
        //    After rotate(angN-90): text horizontal = (sin(angN), -cos(angN))
        //                          text vertical    = (cos(angN),  sin(angN))
        let zLabel = base_thickness - 0.01
        for i in 0..<n {
            let value = distances[i]
            let angN  = 2.0 * .pi * (Double(i) + 0.5) / Double(n)
            let labelR = label_radial * a
            let cx = labelR * cos(angN), cy = labelR * sin(angN)

            let uAxis = V(x:  sin(angN), y: -cos(angN), z: 0)
            let vAxis = V(x:  cos(angN), y:  sin(angN), z: 0)

            tris += raiseSevenSegmentNumber(
                value,
                center: V(x: cx, y: cy, z: zLabel),
                uAxis: uAxis, vAxis: vAxis,
                height: label_size,
                z0: zLabel, z1: zLabel + label_depth
            )
        }

        return tris
    }

    // ---- Prong profile: hull of three circles (base, shank, tip) ----
    //
    //  C1=(bx,0) r=r1  ←──── external tangent ────→  C2=(sx,0) r=r2  ──→  C3=(tx,0) r=r3
    //
    //  For two circles on x-axis, (x1,r1) and (x2,r2), r1>r2:
    //    sinPhi = (r1-r2)/(x2-x1)
    //    Upper tangent point on Ci: (xi + ri*sinPhi, ri*cosPhi)  where cosPhi = sqrt(1-sinPhi^2)
    //    Tangent angle from center: a = atan2(cosPhi, sinPhi)
    //
    private static func prongProfile2D() -> [(Double, Double)] {
        let bx = -root_overlap
        let sx = spike_length * 0.55
        let tx = spike_length
        let r1 = base_d  / 2.0
        let r2 = shank_d / 2.0
        let r3 = tip_d   / 2.0

        // Segment C1→C2
        let d12  = sx - bx
        let sp12 = (r1 - r2) / d12
        let cp12 = sqrt(max(0.0, 1.0 - sp12 * sp12))
        let a12  = atan2(cp12, sp12)

        // Segment C2→C3
        let d23  = tx - sx
        let sp23 = (r2 - r3) / d23
        let cp23 = sqrt(max(0.0, 1.0 - sp23 * sp23))
        let a23  = atan2(cp23, sp23)

        let nBase = 12
        let nShank = 3
        let nTip  = 10

        var pts: [(Double, Double)] = []

        // Base arc: CW from angle -a12 through π to +a12  (the "back" semicircle of C1)
        // CW parameterization: angle(t) = -a12 + t*(2*a12 - 2π)
        for j in 0...nBase {
            let t   = Double(j) / Double(nBase)
            let ang = -a12 + t * (2.0 * a12 - 2.0 * .pi)
            pts.append((bx + r1 * cos(ang), r1 * sin(ang)))
        }

        // Upper tangent C1→C2 (ut2a)
        pts.append((sx + r2 * sp12, r2 * cp12))

        // Upper shank arc from a12 to a23 on C2
        for j in 1...nShank {
            let t   = Double(j) / Double(nShank)
            let ang = a12 + t * (a23 - a12)
            pts.append((sx + r2 * cos(ang), r2 * sin(ang)))
        }

        // Upper tangent C2→C3 (ut3)
        pts.append((tx + r3 * sp23, r3 * cp23))

        // Tip arc: CW from +a23 through 0 to -a23  (the "forward" tip of C3)
        for j in 1...nTip {
            let t   = Double(j) / Double(nTip)
            let ang = a23 - t * 2.0 * a23
            pts.append((tx + r3 * cos(ang), r3 * sin(ang)))
        }

        // Lower tangent C3→C2 (lt2b)
        pts.append((sx + r2 * sp23, -r2 * cp23))

        // Lower shank arc from -a23 to -a12 on C2
        for j in 1...nShank {
            let t   = Double(j) / Double(nShank)
            let ang = -a23 + t * (a23 - a12)   // from -a23 → -a12
            pts.append((sx + r2 * cos(ang), r2 * sin(ang)))
        }

        // Lower tangent C2→C1 (lt1 closes back to start)
        // (start of next iteration would be the same as pts[0])

        return pts
    }

    // ---- Body plate + thumb-well pocket (watertight) ----
    // Bottom face: octagon - lanyard hole
    // Top face:    octagon - hub circle - lanyard hole
    // Side faces:  outer walls, lanyard hole walls, hub cylinder wall, pocket bottom
    private static func makeBodyTris(
        outer: [V],
        lanyardCx: Double, lanyardCy: Double, lanyardR: Double,
        hubR: Double,
        z0: Double, z1: Double, pocketDepth: Double
    ) -> [T] {
        let n  = outer.count
        let m  = fnRound
        let pz = z1 - pocketDepth

        func cwCircle(cx: Double, cy: Double, r: Double) -> [(Double, Double)] {
            (0..<m).map { i in
                let a = -2.0 * .pi * Double(i) / Double(m)
                return (cx + r * cos(a), cy + r * sin(a))
            }
        }

        let outerPts   = outer.map { ($0.x, $0.y) }
        let lanyardPts = cwCircle(cx: lanyardCx, cy: lanyardCy, r: lanyardR)
        let hubPts     = cwCircle(cx: 0, cy: 0, r: hubR)

        // Bottom face: octagon - lanyard hole
        let botTris = earClip(mergeHole(outer: outerPts, hole: lanyardPts))

        // Top face: octagon - hub circle - lanyard hole
        let topTris = earClip(
            mergeHole(outer: mergeHole(outer: outerPts, hole: hubPts), hole: lanyardPts)
        )

        var ts: [T] = []

        // Bottom face (-z normal = reversed winding)
        for (a, b, c) in botTris {
            ts.append(T(a: V(x: a.0, y: a.1, z: z0),
                        b: V(x: c.0, y: c.1, z: z0),
                        c: V(x: b.0, y: b.1, z: z0)))
        }

        // Top face (+z normal)
        for (a, b, c) in topTris {
            ts.append(T(a: V(x: a.0, y: a.1, z: z1),
                        b: V(x: b.0, y: b.1, z: z1),
                        c: V(x: c.0, y: c.1, z: z1)))
        }

        // Outer octagon walls (outward normals)
        for i in 0..<n {
            let j = (i+1) % n
            ts += quad(
                V(x: outer[i].x, y: outer[i].y, z: z0),
                V(x: outer[j].x, y: outer[j].y, z: z0),
                V(x: outer[j].x, y: outer[j].y, z: z1),
                V(x: outer[i].x, y: outer[i].y, z: z1)
            )
        }

        // Lanyard hole walls (inward normals = toward hole axis)
        // CW-ordered pts: going i→j is CW; quad(i,j,j_top,i_top) gives inward normals
        for i in 0..<m {
            let j = (i+1) % m
            ts += quad(
                V(x: lanyardPts[i].0, y: lanyardPts[i].1, z: z0),
                V(x: lanyardPts[j].0, y: lanyardPts[j].1, z: z0),
                V(x: lanyardPts[j].0, y: lanyardPts[j].1, z: z1),
                V(x: lanyardPts[i].0, y: lanyardPts[i].1, z: z1)
            )
        }

        // Hub pocket cylinder wall (z=pz → z=z1, inward normals)
        // Using CCW angles; reversing i,j order gives inward normals
        for i in 0..<m {
            let a0 = 2.0 * .pi * Double(i)   / Double(m)
            let a1 = 2.0 * .pi * Double(i+1) / Double(m)
            let hb0 = V(x: hubR*cos(a0), y: hubR*sin(a0), z: pz)
            let hb1 = V(x: hubR*cos(a1), y: hubR*sin(a1), z: pz)
            let ht0 = V(x: hubR*cos(a0), y: hubR*sin(a0), z: z1)
            let ht1 = V(x: hubR*cos(a1), y: hubR*sin(a1), z: z1)
            ts += quad(hb1, hb0, ht0, ht1)  // reversed = inward normals
        }

        // Hub pocket bottom disc (z=pz, +z normal)
        let hc = V(x: 0, y: 0, z: pz)
        for i in 0..<m {
            let a0 = 2.0 * .pi * Double(i)   / Double(m)
            let a1 = 2.0 * .pi * Double(i+1) / Double(m)
            ts.append(T(a: hc,
                        b: V(x: hubR*cos(a0), y: hubR*sin(a0), z: pz),
                        c: V(x: hubR*cos(a1), y: hubR*sin(a1), z: pz)))
        }

        return ts
    }

    private static func mergeHole(
        outer: [(Double, Double)], hole: [(Double, Double)]
    ) -> [(Double, Double)] {
        let n = outer.count, m = hole.count
        var minD = Double.infinity, bi = 0, bj = 0
        for i in 0..<n {
            for j in 0..<m {
                let dx = outer[i].0 - hole[j].0, dy = outer[i].1 - hole[j].1
                let d = dx*dx + dy*dy
                if d < minD { minD = d; bi = i; bj = j }
            }
        }
        var result: [(Double, Double)] = []
        for k in 0..<n { result.append(outer[(bi+k) % n]) }
        for k in 0..<m { result.append(hole[(bj+k) % m]) }
        return result
    }

    // ---- Ear clipper (O(n²) per clip, fine for ≤100 vertices) ----
    private static func earClip(_ poly: [(Double, Double)]) -> [(V2, V2, V2)] {
        var verts = poly
        var result: [(V2, V2, V2)] = []
        var maxIter = verts.count * verts.count + verts.count

        while verts.count >= 3 && maxIter > 0 {
            maxIter -= 1
            let cnt = verts.count
            var clipped = false
            for i in 0..<cnt {
                let a = verts[(i + cnt - 1) % cnt]
                let b = verts[i]
                let c = verts[(i + 1) % cnt]
                let cross = (b.0-a.0)*(c.1-a.1) - (b.1-a.1)*(c.0-a.0)
                if cross <= 1e-10 { continue }  // reflex or degenerate
                if !earContainsOtherVertex(a: a, b: b, c: c, verts: verts) {
                    result.append((a, b, c))
                    verts.remove(at: i)
                    clipped = true
                    break
                }
            }
            if !clipped { break }
        }
        if verts.count == 3 { result.append((verts[0], verts[1], verts[2])) }
        return result
    }

    private static func earContainsOtherVertex(
        a: V2, b: V2, c: V2, verts: [(Double, Double)]
    ) -> Bool {
        for v in verts {
            if abs(v.0-a.0)<1e-12 && abs(v.1-a.1)<1e-12 { continue }
            if abs(v.0-b.0)<1e-12 && abs(v.1-b.1)<1e-12 { continue }
            if abs(v.0-c.0)<1e-12 && abs(v.1-c.1)<1e-12 { continue }
            if pointInTriangle2D(v, a, b, c) { return true }
        }
        return false
    }

    private static func pointInTriangle2D(_ p: V2, _ a: V2, _ b: V2, _ c: V2) -> Bool {
        func s(_ p1: V2, _ p2: V2, _ p3: V2) -> Double {
            (p1.0-p3.0)*(p2.1-p3.1) - (p2.0-p3.0)*(p1.1-p3.1)
        }
        let d1 = s(p,a,b), d2 = s(p,b,c), d3 = s(p,c,a)
        return !((d1<0||d2<0||d3<0) && (d1>0||d2>0||d3>0))
    }

    // ---- General polygon extrusion (used for prongs) ----
    private static func extrudePolygon(_ poly0: [V], z0: Double, z1: Double) -> [T] {
        guard poly0.count >= 3 else { return [] }
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

    private static func quad(_ v0: V, _ v1: V, _ v2: V, _ v3: V) -> [T] {
        [T(a: v0, b: v1, c: v2), T(a: v0, b: v2, c: v3)]
    }

    private static func polygonArea(_ p: [V]) -> Double {
        var A = 0.0
        for i in 0..<p.count {
            let j = (i+1) % p.count
            A += p[i].x * p[j].y - p[j].x * p[i].y
        }
        return 0.5 * A
    }

    // ---- Raised 7-segment labels (matching SCAD linear_extrude + text) ----

    private struct SegRect { let u: Double, v: Double, uw: Double, vh: Double }

    private static func raiseSevenSegmentNumber(
        _ value: Double,
        center: V, uAxis: V, vAxis: V,
        height: Double,
        z0: Double, z1: Double
    ) -> [T] {
        let numInt = Int(value.rounded())
        let text   = String(numInt)
        let h  = height
        let w  = 0.6 * h
        let sw = 0.18 * h
        let digitAdv = w + 0.20 * h
        let chars = Array(text)
        let totalW = Double(chars.count) * digitAdv - 0.20 * h
        var ts: [T] = []
        for (idx, ch) in chars.enumerated() {
            let cx = -totalW/2.0 + Double(idx)*digitAdv + w/2.0
            for rect in sevenSegmentRects(for: ch, w: w, h: h, sw: sw) {
                ts += raiseRect(
                    uCenter: cx + rect.u, vCenter: rect.v,
                    uWidth: rect.uw, vHeight: rect.vh,
                    frameCenter: center, uAxis: uAxis, vAxis: vAxis,
                    z0: z0, z1: z1
                )
            }
        }
        return ts
    }

    private static func sevenSegmentRects(for ch: Character,
                                          w: Double, h: Double, sw: Double) -> [SegRect] {
        let topY  = +h/2.0 - sw/2.0, midY = 0.0, botY = -h/2.0 + sw/2.0
        let upY   = +h/4.0, downY = -h/4.0
        let leftX = -w/2.0 + sw/2.0, rightX = +w/2.0 - sw/2.0

        func H(_ y: Double) -> SegRect { .init(u: 0.0, v: y, uw: w, vh: sw) }
        func VV(_ x: Double, _ y: Double) -> SegRect { .init(u: x, v: y, uw: sw, vh: h/2.0 - sw/2.0) }

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
            case "b": rects.append(VV(rightX, upY))
            case "c": rects.append(VV(rightX, downY))
            case "e": rects.append(VV(leftX,  downY))
            case "f": rects.append(VV(leftX,  upY))
            default:  break
            }
        }
        return rects
    }

    private static func raiseRect(
        uCenter: Double, vCenter: Double,
        uWidth: Double, vHeight: Double,
        frameCenter: V, uAxis: V, vAxis: V,
        z0: Double, z1: Double
    ) -> [T] {
        let du = uWidth/2.0, dv = vHeight/2.0
        func wp(u: Double, v: Double) -> V {
            frameCenter + uAxis * u + vAxis * v
        }
        let p2D: [V] = [
            wp(u: uCenter-du, v: vCenter-dv),
            wp(u: uCenter+du, v: vCenter-dv),
            wp(u: uCenter+du, v: vCenter+dv),
            wp(u: uCenter-du, v: vCenter+dv)
        ]
        let bot = p2D.map { V(x: $0.x, y: $0.y, z: z0) }
        let top = p2D.map { V(x: $0.x, y: $0.y, z: z1) }
        var ts: [T] = []
        ts += quad(bot[0], bot[1], top[1], top[0])
        ts += quad(bot[1], bot[2], top[2], top[1])
        ts += quad(bot[2], bot[3], top[3], top[2])
        ts += quad(bot[3], bot[0], top[0], top[3])
        ts.append(T(a: bot[0], b: bot[2], c: bot[1]))
        ts.append(T(a: bot[0], b: bot[3], c: bot[2]))
        ts.append(T(a: top[0], b: top[1], c: top[2]))
        ts.append(T(a: top[0], b: top[2], c: top[3]))
        return ts
    }
}
