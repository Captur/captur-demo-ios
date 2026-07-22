//
//  CameraExperienceView.swift
//  CapturDemo
//

import CapturSDK
import SwiftUI
import UIKit

struct CameraExperienceView: View {
    @ObservedObject var model: CapturDemoModel

    var body: some View {
        if let cameraController = model.cameraController {
            GeometryReader { geometry in
                ZStack {
                    CapturCameraScreen(capturCameraController: cameraController)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        if let errorMessage = model.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.capturCrimson.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                        }

                        Spacer()

                        // Prediction sits at the bottom, kept compact so the
                        // camera preview stays unobstructed.
                        if let prediction = model.latestPrediction {
                            PredictionView(prediction: prediction)
                                .frame(width: geometry.size.width * 0.9)
                        }

                        if model.finalDecision == nil {
                            CameraControlsView(model: model)
                        }
                    }
                    .padding()

                    if let finalDecision = model.finalDecision {
                        CapturedImageView(
                            image: UIImage(data: finalDecision.imageData),
                            errorMessage: model.errorMessage,
                            onNewSession: { Task { await model.resetSession() } },
                            onRetake: model.retake
                        )
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if model.finalDecision == nil {
                    Button {
                        Task { await model.resetSession() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding()
                }
            }
        }
    }
}

private struct PredictionView: View {
    let prediction: CapturPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let decision = prediction.decision {
                Text(decision.title ?? decision.value)
                    .font(.capturHeading(12, relativeTo: .caption))
            }

            ForEach(prediction.labels, id: \.name) { label in
                HStack {
                    Text(label.name)
                    Spacer(minLength: 12)
                    Text(label.confidence, format: .percent.precision(.fractionLength(0)))
                }
                .font(.capturBody(11, relativeTo: .caption2))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CapturedImageView: View {
    let image: UIImage?
    let errorMessage: String?
    let onNewSession: () -> Void
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                    .padding(.horizontal, 24)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color.capturCrimson)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button(action: onNewSession) {
                    Label("New Session", systemImage: "plus.circle")
                }

                Button(action: onRetake) {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                }
            }
            .buttonStyle(.capturProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .environment(\.colorScheme, .light)
    }
}
