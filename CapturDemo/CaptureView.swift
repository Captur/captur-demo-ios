//
//  CaptureView.swift
//  CapturDemo
//

import CapturSDK
import SwiftUI

/// The capture screen: the SDK renders the live camera via `CapturCameraScreen`;
/// everything drawn on top (hint, shutter, result) belongs to the app.
struct CaptureView: View {
    @ObservedObject var model: CaptureFlowModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // The camera stays mounted while the result shows, so Retake can
            // resume it. Dismissing this screen is what closes the camera and
            // the session (Step 5).
            if let controller = model.cameraController {
                CapturCameraScreen(capturCameraController: controller)
                    .ignoresSafeArea()

                if case .finished(let finalDecision) = model.phase {
                    resultPanel(finalDecision)
                } else {
                    captureOverlay
                }
            }
        }
        .errorToast(message: model.errorMessage, onTap: { model.dismissError() })
    }

    // MARK: - Capture

    private var captureOverlay: some View {
        GeometryReader { geometry in
            VStack {
                HStack(alignment: .top) {
                    closeButton
                    Spacer()
                    controlsColumn
                }

                Spacer()

                if let prediction = model.livePrediction {
                    predictionsPanel(prediction)
                        .frame(width: geometry.size.width * 0.9)
                }

                if let hint = model.liveHint {
                    Text(hint)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.6), in: Capsule())
                }

                // Manual shutter — the SDK may also finalize on its own.
                Button {
                    Task { await model.captureImage() }
                } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(.white.opacity(0.3)))
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .padding()
        }
    }

    // MARK: - Camera controls

    /// The controller's toggle commands: torch, front/back, lens, zoom.
    private var controlsColumn: some View {
        VStack(spacing: 12) {
            controlButton("flashlight.on.fill") { await model.toggleTorch() }
            controlButton("arrow.triangle.2.circlepath.camera") { await model.togglePosition() }
            controlButton("camera.aperture") { await model.toggleLens() }
            controlButton("plus.magnifyingglass") { await model.toggleZoom() }
        }
    }

    private func controlButton(_ systemImage: String,
                               action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImage)
                .frame(width: 22, height: 22)
                .padding(12)
                .background(.black.opacity(0.5), in: Circle())
        }
    }

    // MARK: - Live predictions

    /// The model's per-frame output: each label with its confidence.
    private func predictionsPanel(_ prediction: CapturPrediction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prediction.model.slug)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))

            ForEach(prediction.labels.sorted { $0.confidence > $1.confidence },
                    id: \.name) { label in
                HStack(spacing: 8) {
                    Text(label.name)
                        .font(.caption2.monospaced())
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    ProgressView(value: min(max(label.confidence, 0), 1))
                        .tint(label.confidence >= 0.5 ? .green : .orange)
                        .frame(width: 56)
                    Text(label.confidence, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Result

    private func resultPanel(_ finalDecision: CapturFinalDecision) -> some View {
        VStack(spacing: 16) {
            if let image = UIImage(data: finalDecision.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            DecisionBadge(decision: finalDecision.decision)

            Text(triggerDescription(finalDecision.trigger))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 12) {
                Button("Retake") { model.retake() }
                    .buttonStyle(.bordered)
                Button("Done") { model.closeCamera() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.85))
        .ignoresSafeArea()
    }

    private var closeButton: some View {
        Button {
            model.closeCamera()
        } label: {
            Image(systemName: "xmark")
                .padding(12)
                .background(.black.opacity(0.5), in: Circle())
        }
    }
}

// MARK: - Shared result helpers (used here and in FlowView's summary)

struct DecisionBadge: View {
    let decision: CapturPredictionDecision?

    var body: some View {
        let (text, color): (String, Color) = switch decision?.value {
        case "PASS": ("Pass", .green)
        case "FAIL": ("Fail", .red)
        case "IMPROVABLE": ("Improvable", .orange)
        case .some(let value): (value, .gray)
        case nil: ("Awaiting decision", .gray)
        }
        Text(decision?.title ?? text)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(color, in: Capsule())
    }
}

func triggerDescription(_ trigger: CapturFinalDecisionTrigger) -> String {
    switch trigger {
    case .manual: return "Captured manually"
    case .continuousGood: return "Auto-captured — photo looked consistently good"
    case .timeout: return "Auto-captured on timeout"
    @unknown default: return "Captured"
    }
}
