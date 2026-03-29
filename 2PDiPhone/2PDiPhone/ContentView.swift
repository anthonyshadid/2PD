//2PD
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//


import SwiftUI
import UniformTypeIdentifiers


// MARK: - UI

struct ContentView: View {
    @State private var fields = Array(repeating: "", count: 8)
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var errorText: String?

    var body: some View {
        Form {
            Section {
                ForEach(0..<8, id: \.self) { i in
                    TextField("Distance \(i+1)", text: $fields[i])
                        .keyboardType(.decimalPad)
                }
            } header: {
                HStack {
                    Text("Enter any 8 custom distances (mm)")
                    Spacer()
                    Button("Clear") {
                        fields = Array(repeating: "", count: 8)
                        errorText = nil
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                }
            }
            Section {
                Button("Generate STL") { generate() }
                    .buttonStyle(.borderedProminent)

                Button("Fine Preset (0,2,3,4,5,6,7,8)") {
                    fields = ["0","2","3","4","5","6","7","8"]; generate()
                }

                Button("Broad Preset (0,9,10,11,12,13,14,15)") {
                    fields = ["0","9","10","11","12","13","14","15"]; generate()
                }
            }
            if let errorText { Text(errorText).foregroundStyle(.red) }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .navigationTitle("2PD Generator")
    }

    private func generate() {
        errorText = nil
        let distances = fields
            .map { $0.replacingOccurrences(of: ",", with: ".") }
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

        do {
            let url = try generateSCADCompatSTL(distancesMM: distances)
            shareURL = url
            showShare = true
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
