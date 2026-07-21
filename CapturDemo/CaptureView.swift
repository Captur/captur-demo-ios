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
        VStack {
            HStack {
                closeButton
                Spacer()
                Button {
                    Task { await model.toggleTorch() }
                } label: {
                    Image(systemName: "flashlight.on.fill")
                        .padding(12)
                        .background(.black.opacity(0.5), in: Circle())
                }
            }

            Spacer()

            if let hint = model.livePredictions {
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
        .foregroundStyle(.white)
        .padding()
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
