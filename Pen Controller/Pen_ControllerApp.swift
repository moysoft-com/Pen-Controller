//
//  Pen_ControllerApp.swift
//  Pen Controller
//
//  Created by Lian on 11.01.26.
//

import SwiftUI

@main
struct Pen_ControllerApp: App {
    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("Pen Consumer", systemImage: "pencil.and.ruler") {
            ContentView()
                .frame(width: 320)
        }
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
