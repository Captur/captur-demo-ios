//
//  CapturDemoApp.swift
//  CapturDemo
//
//  Created by Ahd H A Radwan on 20/07/2026.
//

import CapturSDK
import SwiftUI

@main
struct CapturDemoApp: App {
    let captur = Captur(apiKey: "YOUR_API_KEY")
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
