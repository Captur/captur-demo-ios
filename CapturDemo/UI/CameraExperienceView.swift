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

                    // Only the decision's reason code is surfaced to the user;
                    // per-label output is not shown (and leaves the SDK in 0.3.0).
                    if let prediction = model.latestPrediction {
                        PredictionView(prediction: prediction)
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
                        onNewSession: { Task { await model.closeSession() } },
                        onRetake: model.retake
                    )
                }
            }
            .overlay(alignment: .topTrailing) {
                if model.finalDecision == nil {
                    // X only dismisses the camera; the session stays open
                    // and can be resumed from the start screen.
                    Button {
                        model.dismissCamera()
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
        if let reasonCode = prediction.decision?.reasonCode {
            Text("Reason code: " + reasonCode)
                .font(.capturHeading(12, relativeTo: .caption))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
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
