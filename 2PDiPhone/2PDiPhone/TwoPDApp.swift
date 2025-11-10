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
                // Tab 1: your generator
                NavigationStack { ContentView() }
                    .tabItem { Label("Generator", systemImage: "gearshape") }

                // Tab 2: your About/Instructions page
                NavigationStack { AboutView() }
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
        }
    }
}
