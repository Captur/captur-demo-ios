//
//  CameraControlsView.swift
//  CapturDemo
//

import SwiftUI

/// The in-camera controls: the manual shutter plus the controller's
/// hardware toggles (torch, front/back, lens, zoom). Layout and styling
/// only — every tap calls straight into the model.
struct CameraControlsView: View {
    let model: CapturDemoModel

    var body: some View {
        HStack(spacing: 24) {
            controlButton("flashlight.on.fill") { await model.toggleTorch() }
            controlButton("arrow.triangle.2.circlepath.camera") { await model.togglePosition() }

            shutterButton

            controlButton("camera.aperture") { await model.toggleLens() }
            controlButton("plus.magnifyingglass") { await model.toggleZoom() }
        }
    }

    private var shutterButton: some View {
        Button {
            Task { await model.captureImage() }
        } label: {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
                .frame(width: 72, height: 72)
                .background(Circle().fill(.white.opacity(0.3)))
        }
    }

    private func controlButton(_ systemImage: String,
                               action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .padding(10)
                .background(.black.opacity(0.5), in: Circle())
        }
    }
}
