//
//  STLModeler.swift
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//

import Foundation

// MARK: - Public API

enum STLGenError: Error, LocalizedError {
    case badDistances
    var errorDescription: String? {
        switch self {
        case .badDistances: return "Please enter 8 numeric distances in millimeters."
        }
    }
}

/// Call this from your UI. Returns a URL to the written STL file.
func generateTwoPDWheelSTL(distancesMM: [Double]) throws -> URL {
    guard distancesMM.count == 8, distancesMM.allSatisfy({ $0.isFinite && $0 > 0 }) else {
        throw STLGenError.badDistances
    }
    let tris = TwoPDModeler.makeWheelTris(distancesMM: distancesMM)
    let data = STLWriter.writeASCII(tris: tris, name: "2PD_wheel")
    let stamp = ISO8601DateFormatter().string(from: Date())
    let name = "wheel_" + distancesMM.map { String(Int($0.rounded())) }.joined(separator: "-") + "_\(stamp).stl"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try data.write(to: url, options: .atomic)
    return url
}

// MARK: - Mesh + STL

private struct Vec3 { var x: Double, y: Double, z: Double }
private extension Vec3 {
    static func +(l: Self, r: Self) -> Self { .init(x:l.x+r.x, y:l.y+r.y, z:l.z+r.z) }
    static func -(l: Self, r: Self) -> Self { .init(x:l.x-r.x, y:l.y-r.y, z:l.z-r.z) }
    static func *(l: Self, s: Double) -> Self { .init(x:l.x*s, y:l.y*s, z:l.z*s) }
}
private struct Tri { var a: Vec3, b: Vec3, c: Vec3 }

private enum STLWriter {
    static func writeASCII(tris: [Tri], name: String) -> Data {
        var s = "solid \(name)\n"
        for t in tris {
            let n = normal(t)
            s += " facet normal \(fmt(n.x)) \(fmt(n.y)) \(fmt(n.z))\n"
            s += "  outer loop\n"
            s += "   vertex \(fmt(t.a.x)) \(fmt(t.a.y)) \(fmt(t.a.z))\n"
            s += "   vertex \(fmt(t.b.x)) \(fmt(t.b.y)) \(fmt(t.b.z))\n"
            s += "   vertex \(fmt(t.c.x)) \(fmt(t.c.y)) \(fmt(t.c.z))\n"
            s += "  endloop\n"
            s += " endfacet\n"
        }
        s += "endsolid \(name)\n"
        return Data(s.utf8)
    }
    private static func normal(_ t: Tri) -> Vec3 {
        let u = t.b - t.a, v = t.c - t.a
        let nx = u.y*v.z - u.z*v.y
        let ny = u.z*v.x - u.x*v.z
        let nz = u.x*v.y - u.y*v.x
        let L = max(1e-12, sqrt(nx*nx+ny*ny+nz*nz))
        return .init(x: nx/L, y: ny/L, z: nz/L)
    }
    private static func fmt(_ v: Double) -> String { String(format: "%.6f", v) }
}

private enum TwoPDModeler {
    static func makeWheelTris(distancesMM d: [Double]) -> [Tri] {
        // Tunable parameters (match what you want physically)
        let wheelRadius: Double = 35.0
        let hubRadius: Double   = 14.0
        let thickness: Double   = 3.0
        let headOffset: Double  = wheelRadius - 5.5
        let tipRadius: Double   = 0.7
        let tipLength: Double   = 3.0
        let facetsCircle = 48

        var tris: [Tri] = []
        // Base annulus (disc with hub hole)
        tris += makeAnnulus(outerR: wheelRadius, innerR: hubRadius, thickness: thickness, facets: facetsCircle)

        // 8 heads around the wheel
        for i in 0..<8 {
            let theta = Double(i) * .pi / 4.0
            let sep = d[i]
            let half = sep / 2.0

            // small rectangular pad to anchor the tips
            let padW = max(sep + 4.0, 8.0)
            let padL = 6.0
            let padT = thickness
            let padCenter = polar(r: headOffset, theta: theta, z: 0)
            tris += makeRectPad(center: padCenter, w: padW, l: padL, t: padT, facingTheta: theta)

            // tip positions (perpendicular to radius)
            let lateral = Vec3(x: -sin(theta), y: cos(theta), z: 0)
            let radial  = Vec3(x:  cos(theta), y: sin(theta), z: 0)

            let tipC1 = padCenter + lateral * half + radial * (padL/2 + tipLength/2)
            let tipC2 = padCenter - lateral * half + radial * (padL/2 + tipLength/2)

            tris += makeCylinder(center: tipC1, axis: radial, r: tipRadius, h: tipLength, facets: facetsCircle)
            tris += makeCylinder(center: tipC2, axis: radial, r: tipRadius, h: tipLength, facets: facetsCircle)
        }
        return tris
    }

    // MARK: primitives

    private static func makeAnnulus(outerR: Double, innerR: Double, thickness: Double, facets: Int) -> [Tri] {
        var tris: [Tri] = []
        let z0 = -thickness/2, z1 = thickness/2
        let dA = 2.0 * .pi / Double(facets)
        for i in 0..<facets {
            let a0 = Double(i) * dA
            let a1 = Double(i+1) * dA
            let o00 = Vec3(x: outerR*cos(a0), y: outerR*sin(a0), z: z0)
            let o01 = Vec3(x: outerR*cos(a1), y: outerR*sin(a1), z: z0)
            let o10 = Vec3(x: outerR*cos(a0), y: outerR*sin(a0), z: z1)
            let o11 = Vec3(x: outerR*cos(a1), y: outerR*sin(a1), z: z1)
            let i00 = Vec3(x: innerR*cos(a0), y: innerR*sin(a0), z: z0)
            let i01 = Vec3(x: innerR*cos(a1), y: innerR*sin(a1), z: z0)
            let i10 = Vec3(x: innerR*cos(a0), y: innerR*sin(a0), z: z1)
            let i11 = Vec3(x: innerR*cos(a1), y: innerR*sin(a1), z: z1)
            // top, bottom, outer wall, inner wall
            tris += quad(o10, o11, i11, i10)
            tris += quad(o01, o00, i00, i01)
            tris += quad(o00, o01, o11, o10)
            tris += quad(i01, i00, i10, i11)
        }
        return tris
    }

    private static func makeRectPad(center: Vec3, w: Double, l: Double, t: Double, facingTheta: Double) -> [Tri] {
        let hx = w/2, hy = l/2, hz = t/2
        var v = [
            Vec3(x:-hx,y:-hy,z:-hz), Vec3(x:hx,y:-hy,z:-hz), Vec3(x:hx,y:hy,z:-hz), Vec3(x:-hx,y:hy,z:-hz),
            Vec3(x:-hx,y:-hy,z: hz), Vec3(x:hx,y:-hy,z: hz), Vec3(x:hx,y:hy,z: hz), Vec3(x:-hx,y:hy,z: hz)
        ].map { rotateZ($0, theta: facingTheta) + center }
        let f = [[0,1,2,3],[4,5,6,7],[0,1,5,4],[2,3,7,6],[1,2,6,5],[0,3,7,4]]
        var tris: [Tri] = []
        for q in f { tris += quad(v[q[0]], v[q[1]], v[q[2]], v[q[3]]) }
        return tris
    }

    private static func makeCylinder(center: Vec3, axis: Vec3, r: Double, h: Double, facets: Int) -> [Tri] {
        let a = normalize(axis)
        let up = abs(a.z) < 0.9 ? Vec3(x:0,y:0,z:1) : Vec3(x:1,y:0,z:0)
        let xAxis = normalize(cross(up, a))
        let yAxis = a
        let zAxis = cross(a, xAxis)
        func toWorld(_ p: Vec3) -> Vec3 { xAxis*p.x + yAxis*p.y + zAxis*p.z + center }

        var tris: [Tri] = []
        let y0 = -h/2, y1 = h/2
        let dA = 2.0 * .pi / Double(facets)
        for i in 0..<facets {
            let a0 = Double(i) * dA
            let a1 = Double(i+1) * dA
            let x0 = r * cos(a0), z0 = r * sin(a0)
            let x1 = r * cos(a1), z1 = r * sin(a1)
            let p00 = toWorld(.init(x:x0,y:y0,z:z0))
            let p01 = toWorld(.init(x:x1,y:y0,z:z1))
            let p10 = toWorld(.init(x:x0,y:y1,z:z0))
            let p11 = toWorld(.init(x:x1,y:y1,z:z1))
            // side
            tris += quad(p00, p01, p11, p10)
            // caps
            let c0 = toWorld(.init(x:0,y:y0,z:0))
            let c1 = toWorld(.init(x:0,y:y1,z:0))
            tris.append(.init(a: c0, b: p01, c: p00))
            tris.append(.init(a: c1, b: p10, c: p11))
        }
        return tris
    }

    // helpers
    private static func quad(_ v0: Vec3, _ v1: Vec3, _ v2: Vec3, _ v3: Vec3) -> [Tri] {
        [.init(a:v0,b:v1,c:v2), .init(a:v0,b:v2,c:v3)]
    }
    private static func polar(r: Double, theta: Double, z: Double) -> Vec3 {
        .init(x: r * cos(theta), y: r * sin(theta), z: z)
    }
    private static func rotateZ(_ p: Vec3, theta: Double) -> Vec3 {
        .init(x: p.x * cos(theta) - p.y * sin(theta),
              y: p.x * sin(theta) + p.y * cos(theta),
              z: p.z)
    }
    private static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        .init(x: a.y*b.z - a.z*b.y, y: a.z*b.x - a.x*b.z, z: a.x*b.y - a.y*b.x)
    }
    private static func normalize(_ v: Vec3) -> Vec3 {
        let L = max(1e-12, sqrt(v.x*v.x + v.y*v.y + v.z*v.z))
        return .init(x: v.x/L, y: v.y/L, z: v.z/L)
    }
}
