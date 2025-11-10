import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header / Branding
                HStack(spacing: 12) {
                    Image(systemName: "ruler")
                        .font(.system(size: 34, weight: .semibold))
                    VStack(alignment: .leading) {
                        Text("2PD Generator")
                            .font(.title.bold())
                        Text(appVersionString())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                // About
                SectionHeader("About")
                Text("""
2PD Generator is a simple, offline iOS tool that creates a printable wheel for **two-point discrimination** testing. Enter **any 8 distances (mm)** and the app generates an **STL** you can save, AirDrop, or send to your slicer.

This app is inspired by the open-source project **2PD** (anthonyshadid/2PD) and re-implements the modeler natively in Swift to run fully on-device (no OpenSCAD or server).
""")

                // Intended Use
                SectionHeader("Intended Use")
                Text("""
Designed for **education, research prototyping, and demonstration**. This app has **not** been evaluated or cleared as a medical device. For clinical use, obtain approval per your institution’s policies and applicable regulations.
""")

                // Quick Start
                SectionHeader("Quick Start")
                BulletList(items: [
                    "Open the app and enter **8 distances** in millimeters (e.g., 2, 3, 4, 5, 8, 12, 18, 25).",
                    "Tap **Generate STL**. A share sheet appears.",
                    "Choose **Save to Files**, AirDrop, email, or open in your slicer.",
                    "3D-print the wheel (see Printing Guide)."
                ])

                // Printing Guide
                SectionHeader("Printing Guide")
                BulletList(items: [
                    "Material: PLA or PETG.",
                    "Layer height: 0.16–0.20 mm; smaller tips benefit from finer layers.",
                    "Walls: 2–3 perimeters; Infill: 20–40%.",
                    "Orientation: print **flat** (wheel lying on the bed).",
                    "Check tip integrity; lightly deburr if needed.",
                    "Color/labels: you can add labels with a marker or request an engraved-text build."
                ])

                // Cleaning & Handling
                SectionHeader("Cleaning & Handling")
                BulletList(items: [
                    "Wipe with 70% isopropyl alcohol before and after demonstration.",
                    "Avoid harsh sterilization/heat; printed plastics can deform.",
                    "Inspect tips regularly; discontinue use if damaged."
                ])

                // Validation & Accuracy
                SectionHeader("Validation & Accuracy")
                Text("""
Distances are modeled directly from your inputs. Final printed distances can vary due to **printer calibration**, **shrinkage**, **slicer settings**, and **post-processing**. If accuracy matters, verify with calipers and tune your printer steps-per-mm and flow rate. Consider re-printing critical heads based on measurements.
""")

                // Parameters (defaults)
                SectionHeader("Model Parameters (Defaults)")
                ParameterGrid(parameters: [
                    ("Wheel radius", "35.0 mm"),
                    ("Hub radius", "14.0 mm"),
                    ("Thickness", "3.0 mm"),
                    ("Tip radius", "0.7 mm"),
                    ("Tip length", "3.0 mm"),
                    ("Facets", "48")
                ])
                Text("Need different ergonomics or labeling? Ask us to enable **engraved text**, **alternative tip profiles**, or **extra heads**.")

                // Troubleshooting
                SectionHeader("Troubleshooting")
                BulletList(items: [
                    "“Please enter 8 numeric distances” → ensure all 8 fields are numbers (use dot or comma as decimal).",
                    "STL won’t open → try saving to Files first, then import into your slicer.",
                    "Tips too fragile → increase tip radius or print with more perimeters.",
                    "Distances off → calibrate printer (X/Y steps), reduce elephant’s foot (use brim, z-offset tuning), and re-measure."
                ])

                // FAQ
                SectionHeader("FAQ")
                FAQItem(q: "What units are used?", a: "Millimeters (mm). STL is unitless, but we follow mm convention.")
                FAQItem(q: "Can I get labels on each head?", a: "Yes. We can add engraved numerals or tick marks in a future update.")
                FAQItem(q: "Does this need the internet?", a: "No. All modeling is done on-device.")
                FAQItem(q: "Can I share directly to my slicer?", a: "Use the share sheet → Open in your slicer app or Save to Files, then import.")

                // Privacy
                SectionHeader("Privacy")
                Text("""
The app does not collect analytics or personal data. Generated files are stored temporarily on-device until you export or delete them.
""")

                // Attribution & License
                SectionHeader("Attribution")
                Text("""
Based on ideas from the open-source project **2PD** (anthonyshadid/2PD). All trademarks and references belong to their respective owners.
""")

                // Contributors
                SectionHeader("Contributors")
                Text("""
                **Keyvon Rashidi**  
                

                **Anthony Shadid**  
                
                """)
                
                // Legal
                SectionHeader("Disclaimer")
                Text("""
This software is provided “as is,” without warranties of any kind. Not for diagnostic use unless validated and approved by your institution. Use at your own risk.
""")
            }
            .padding(20)
        }
        .navigationTitle("About & Instructions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Helpers
    private func appVersionString() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }
}

// MARK: - UI Bits

fileprivate struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }
}

fileprivate struct BulletList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    Text(item)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

fileprivate struct ParameterGrid: View {
    let parameters: [(String, String)]
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(parameters.enumerated()), id: \.offset) { _, pair in
                HStack {
                    Text(pair.0)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(pair.1)
                        .font(.callout)
                }
                Divider()
            }
        }
    }
}

fileprivate struct FAQItem: View {
    let q: String, a: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(q).font(.subheadline.bold())
            Text(a)
        }
        .padding(.vertical, 4)
    }
}
