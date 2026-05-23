//
//  TwoPDApp.swift
//  2PDiPhone
//
//  Created by Keyvon R on 11/9/25.
//

import SwiftUI

@main
struct TwoPDApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { ContentView() }
                    .tabItem { Label("Generator", systemImage: "hexagon") }

                NavigationStack { AboutView() }
                    .tabItem { Label("About", systemImage: "book") }
            }
        }
    }
}
