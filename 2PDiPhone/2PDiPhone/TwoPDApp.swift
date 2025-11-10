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
                // Tab 1: Generator
                NavigationStack { ContentView() }
                    .tabItem { Label("Generator", systemImage: "gearshape") }

                // Tab 2: About/Instructions page
                NavigationStack { AboutView() }
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
        }
    }
}
