//
//  ContentView.swift
//  CapturDemo
//
//  Created by Ahd H A Radwan on 20/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var demo = CapturDemoModel()
    @State private var isCameraPresented = false

    var body: some View {
        VStack(spacing: 16) {
            switch demo.step {
            case .session:
                Button("Prepare Session") {
                    Task { await demo.prepareSession() }
                }

            case .camera:
                successLabel("Session Prepared")

                Button("Prepare Camera") {
                    Task { await demo.prepareCamera() }
                }

            case .ready:
                successLabel("Camera Prepared")

                Button("Present Camera") {
                    isCameraPresented = true
                }
            }

            if let errorMessage = demo.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fullScreenCover(isPresented: $isCameraPresented, onDismiss: {
            if demo.capturedImage == nil {
                demo.resetSession()
            }
        }) {
            CameraExperienceView(
                model: demo,
                isPresented: $isCameraPresented
            )
        }
    }

    private func successLabel(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }
}

#Preview {
    ContentView()
}
