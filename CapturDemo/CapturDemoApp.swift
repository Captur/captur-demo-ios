//
//  CapturDemoApp.swift
//  CapturDemo
//

import SwiftUI

@main
struct CapturDemoApp: App {
    @StateObject private var model = CaptureFlowModel()

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
        }
    }
}
