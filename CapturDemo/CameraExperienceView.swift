//
//  CameraExperienceView.swift
//  CapturDemo
//

import CapturSDK
import SwiftUI
import UIKit

struct CameraExperienceView: View {
    let model: CapturDemoModel
    @Binding var isPresented: Bool

    var body: some View {
        if let cameraController = model.cameraController {
            ZStack {
                CapturCameraScreen(capturCameraController: cameraController)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    if let prediction = model.latestPrediction {
                        PredictionView(prediction: prediction)
                    }

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    }

                    Spacer()
                }
                .padding()

                if let capturedImage = model.capturedImage {
                    CapturedImageView(
                        image: capturedImage,
                        errorMessage: model.errorMessage,
                        onNewSession: {
                            model.resetSession()
                            isPresented = false
                        },
                        onRetake: model.retake
                    )
                }
            }
            .overlay(alignment: .topTrailing) {
                if model.capturedImage == nil {
                    Button {
                        isPresented = false
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Prediction")
                .font(.headline)

            if let decision = prediction.decision {
                Text(decision.title ?? decision.value)
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(prediction.labels.indices, id: \.self) { index in
                HStack {
                    Text(prediction.labels[index].name)
                    Spacer()
                    Text(
                        prediction.labels[index].confidence,
                        format: .percent.precision(.fractionLength(0))
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct CapturedImageView: View {
    let image: UIImage
    let errorMessage: String?
    let onNewSession: () -> Void
    let onRetake: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                }

                HStack(spacing: 12) {
                    Button(action: onNewSession) {
                        Label("New Session", systemImage: "plus.circle")
                    }

                    Button(action: onRetake) {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
