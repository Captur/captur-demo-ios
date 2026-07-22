//
//  ContentView.swift
//  CapturDemo
//
//  Created by Ahd H A Radwan on 20/07/2026.
//

import CapturSDK
import SwiftUI

struct ContentView: View {
    @StateObject private var demo = CapturDemoModel()
    @State private var selectedUseCase: UseCase = .eBikeParking

    var body: some View {
        VStack(spacing: 16) {
            Text("Select a model to load")
                .font(.capturHeading(20, relativeTo: .title3))
            if demo.session == nil {
                Picker("Use case", selection: $selectedUseCase) {
                    ForEach(UseCase.allCases) { useCase in
                        Text(useCase.title).tag(useCase)
                    }
                }
                .pickerStyle(.segmented)

                if demo.isPreparingSession {
                    ProgressView("Preparing session…")
                } else {
                    Button("Prepare Session") {
                        Task { await demo.prepareSession(for: selectedUseCase) }
                    }
                }
            } else {
                successLabel("Session Prepared")

                // prepareCamera is the SDK call; the camera screen presents
                // itself as soon as a controller exists, so one tap does both.
                Button("Open Camera") {
                    Task { await demo.prepareCamera() }
                }
            }

            if let errorMessage = demo.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.capturCrimson)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            Text("CapturSDK \(CapturSDKMetadata.version)")
                .font(.capturBody(12, relativeTo: .caption))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .buttonStyle(.capturProminent)
        .foregroundStyle(Color.black)
        .background(Color.white.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        // Presentation is driven by the model: a camera controller exists
        // exactly while the camera should be on screen. Dismissing (swipe or
        // any close button) resets the flow, matching the SDK rule that an
        // unmounted camera closes its session.
        .fullScreenCover(isPresented: Binding(
            get: { demo.cameraController != nil },
            set: { if !$0 { Task { await demo.resetSession() } } }
        )) {
            CameraExperienceView(model: demo)
        }
    }

    private func successLabel(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .foregroundStyle(Color.capturSuccess)
    }
}

//#Preview {
  //  ContentView()
//}
