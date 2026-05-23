//
//  ContentView.swift
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var fields = Array(repeating: "", count: 8)
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var errorText: String?

    private var filledCount: Int {
        fields.filter {
            Double($0.replacingOccurrences(of: ",", with: ".")
                      .trimmingCharacters(in: .whitespaces)) != nil
        }.count
    }

    var body: some View {
        Form {
            Section {
                ForEach(0..<8, id: \.self) { i in
                    HStack(spacing: 10) {
                        Text("\(i + 1)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 18, alignment: .trailing)
                        TextField("–", text: $fields[i])
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("mm")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                }
            } header: {
                Text("Distances")
            } footer: {
                if filledCount > 0 && filledCount < 8 {
                    Text("\(filledCount) of 8 entered")
                }
            }

            Section {
                Button(action: generate) {
                    Label("Generate STL", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(filledCount < 3)
            }

            if let errorText {
                Section {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("2PD Generator")
        .sheet(isPresented: $showShare) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
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
