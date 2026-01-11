//
//  ContentView.swift
//  Pen Controller
//
//  Created by Lian on 11.01.26.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            InputProducerView()
        } else {
            VStack(spacing: 12) {
                Text("Unsupported Device")
                    .font(.title2)
                    .bold()
                Text("This app runs as an Input Producer on iPadOS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        #elseif os(macOS)
        InputConsumerView()
        #else
        Text("Unsupported Platform")
            .padding()
        #endif
    }
}

#Preview {
    ContentView()
}
