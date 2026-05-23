//
//  AboutView.swift
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                HStack(spacing: 14) {
                    Image(systemName: "ruler")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2PD Generator")
                            .font(.title2.bold())
                        Text(versionString())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // About
                InfoSection("About") {
                    Text("A compact, offline tool for generating printable two-point discrimination wheels. Enter the 8 distances you want, tap Generate, and share the STL with your slicer.")
                }

                InfoSection("Intended Use") {
                    Text("Built for education, research prototyping, and demonstration. This app has not been evaluated or cleared as a medical device. For clinical use, confirm compliance with your institution's policies and applicable regulations.")
                }

                InfoSection("Quick Start") {
                    BulletList(items: [
                        "Enter 8 distances in millimeters.",
                        "Tap Generate STL.",
                        "Save to Files, AirDrop, or open in your slicer.",
                        "Print flat on the bed (see Printing Guide)."
                    ])
                }

                InfoSection("Printing Guide") {
                    BulletList(items: [
                        "Material: PLA or PETG.",
                        "Layer height: 0.16–0.20 mm.",
                        "2–3 perimeter walls, 20–40% infill.",
                        "Orient the wheel flat on the print bed.",
                        "Inspect tip integrity; lightly deburr if needed."
                    ])
                }

                InfoSection("Cleaning & Handling") {
                    BulletList(items: [
                        "Wipe with 70% isopropyl alcohol before and after use.",
                        "Avoid heat and harsh solvents; printed plastic can deform.",
                        "Retire the wheel if any tips are broken or deformed."
                    ])
                }

                InfoSection("Model Parameters") {
                    ParameterGrid(parameters: [
                        ("Wheel diameter", "40 mm flat-to-flat"),
                        ("Body thickness", "3 mm"),
                        ("Prong length", "7 mm"),
                        ("Prong thickness", "1.4 mm"),
                        ("Hub diameter", "17 mm"),
                        ("Labels", "Raised, top face"),
                        ("Lanyard hole", "Ø 3.5 mm, corner")
                    ])
                }

                InfoSection("Accuracy") {
                    Text("Distances are modeled from your inputs. Final printed values depend on printer calibration, material shrinkage, and slicer settings. Verify with calipers and tune flow rate if accuracy is critical.")
                }

                InfoSection("Troubleshooting") {
                    BulletList(items: [
                        "\"At least 3 distances\" error — check that all 8 fields contain numbers (comma or period as decimal separator).",
                        "STL won't open in slicer — try saving to Files first, then import.",
                        "Tips too fragile — increase infill or print with more perimeter walls.",
                        "Distances off — calibrate X/Y steps and check for elephant's foot."
                    ])
                }

                InfoSection("Privacy") {
                    Text("No analytics or personal data are collected. Generated files are stored temporarily on-device until you export or delete them.")
                }

                InfoSection("Attribution") {
                    Text("Inspired by the open-source 2PD project (anthonyshadid/2PD). The on-device STL modeler is a native Swift reimplementation.")
                }

                InfoSection("Contributors") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Keyvon Rashidi")
                        Text("Anthony Shadid")
                    }
                    .foregroundStyle(.secondary)
                }

                InfoSection("Disclaimer") {
                    Text("Provided as-is, without warranties of any kind. Not for diagnostic use unless validated and approved by your institution.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            .padding(20)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func versionString() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }
}

// MARK: - Components

private struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            content
        }
    }
}

private struct BulletList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("·")
                        .foregroundStyle(.secondary)
                        .fontWeight(.bold)
                    Text(item)
                }
            }
        }
    }
}

private struct ParameterGrid: View {
    let parameters: [(String, String)]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(parameters.enumerated()), id: \.offset) { idx, pair in
                HStack {
                    Text(pair.0)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(pair.1)
                        .font(.callout.monospacedDigit())
                }
                .padding(.vertical, 7)
                if idx < parameters.count - 1 {
                    Divider()
                }
            }
        }
    }
}
