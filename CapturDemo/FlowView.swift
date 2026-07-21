//
//  FlowView.swift
//  CapturDemo
//

import CapturSDK
import SwiftUI

/// The five steps of the Captur SDK lifecycle, as shown to the user.
/// Each one maps to a numbered comment in `CaptureFlowModel`.
enum DemoStep: Int, CaseIterable, Identifiable {
    case prepareSession = 1
    case prepareCamera
    case openCamera
    case handleEvents
    case close

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .prepareSession: return "Prepare the session"
        case .prepareCamera: return "Prepare the camera"
        case .openCamera: return "Open the camera"
        case .handleEvents: return "Handle events"
        case .close: return "Close"
        }
    }

    var code: String {
        switch self {
        case .prepareSession: return "try await captur.prepareSession(policyType:location:)"
        case .prepareCamera: return "try await session.prepareCamera(location:onCapturEvent:)"
        case .openCamera: return "CapturCameraScreen(capturCameraController:)"
        case .handleEvents: return ".prediction  ·  .finalDecision  ·  .failed"
        case .close: return "// dismiss CapturCameraScreen"
        }
    }

    var detail: String {
        switch self {
        case .prepareSession:
            return "Authenticates with your API key and downloads the on-device model. Call it early, ahead of capture."
        case .prepareCamera:
            return "Loads the models and returns a camera controller. The app must hold camera permission — the SDK checks but never prompts."
        case .openCamera:
            return "Presenting this SwiftUI view is what starts the preview and live predictions — there is no start() call."
        case .handleEvents:
            return "Every result arrives through the single callback: live guidance per frame, then the final decision with the JPEG image."
        case .close:
            return "Removing the view from the hierarchy closes the camera and the session — there is no close() call. Each attempt uses a fresh session."
        }
    }
}

/// Walks through the SDK lifecycle one step at a time, so each call
/// and its effect are visible.
struct FlowView: View {
    @ObservedObject var model: CaptureFlowModel
    let useCase: UseCase

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(DemoStep.allCases) { step in
                    stepRow(step)
                }

                if case .closed(let finalDecision) = model.phase {
                    summaryCard(finalDecision)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) { actionButton.padding() }
        .errorToast(message: model.errorMessage, onTap: { model.dismissError() })
        .navigationTitle(useCase.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.reset() }
        // The camera screen is presented while the phase is "open" or showing
        // a final decision; dismissing it closes the camera (Step 5).
        .fullScreenCover(isPresented: Binding(
            get: {
                switch model.phase {
                case .cameraOpen, .finished: return true
                default: return false
                }
            },
            set: { if !$0 { model.closeCamera() } }
        )) {
            CaptureView(model: model)
        }
    }

    // MARK: - Step status

    private enum StepStatus {
        case pending, running, done
    }

    private func status(of step: DemoStep) -> StepStatus {
        let doneCount: Int
        var running: DemoStep?
        switch model.phase {
        case .idle: doneCount = 0
        case .preparingSession: doneCount = 0; running = .prepareSession
        case .sessionReady: doneCount = 1
        case .preparingCamera: doneCount = 1; running = .prepareCamera
        case .cameraReady: doneCount = 2
        case .cameraOpen: doneCount = 3; running = .handleEvents
        case .finished: doneCount = 4
        case .closed: doneCount = 5
        }
        if step == running { return .running }
        return step.rawValue <= doneCount ? .done : .pending
    }

    // MARK: - Rows

    private func stepRow(_ step: DemoStep) -> some View {
        let status = status(of: step)
        return HStack(alignment: .top, spacing: 12) {
            statusIcon(status, number: step.rawValue)
            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.headline)
                Text(step.code)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(.quaternary.opacity(status == .running ? 0.6 : 0.3),
                    in: RoundedRectangle(cornerRadius: 16))
        .opacity(status == .pending ? 0.55 : 1)
    }

    @ViewBuilder
    private func statusIcon(_ status: StepStatus, number: Int) -> some View {
        switch status {
        case .pending:
            Image(systemName: "\(number).circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
    }

    // MARK: - Result summary

    private func summaryCard(_ finalDecision: CapturFinalDecision?) -> some View {
        VStack(spacing: 12) {
            if let finalDecision {
                if let image = UIImage(data: finalDecision.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                DecisionBadge(decision: finalDecision.decision)
                Text(triggerDescription(finalDecision.trigger))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("The session is closed. A new attempt starts again from Step 1.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Action button

    @ViewBuilder
    private var actionButton: some View {
        switch model.phase {
        case .idle:
            primaryButton("Step 1 · Prepare the session") {
                Task { await model.prepareSession(for: useCase) }
            }
        case .preparingSession, .preparingCamera:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        case .sessionReady:
            primaryButton("Step 2 · Prepare the camera") {
                Task { await model.prepareCamera(for: useCase) }
            }
        case .cameraReady:
            primaryButton("Step 3 · Open the camera") {
                model.openCamera()
            }
        case .cameraOpen, .finished:
            EmptyView() // the camera screen is presented full screen
        case .closed:
            primaryButton("Start over") {
                model.reset()
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Error toast

/// A transient error toast sliding in from the top. The model hides it
/// automatically after a few seconds; tapping dismisses it right away.
extension View {
    func errorToast(message: String?, onTap: @escaping () -> Void) -> some View {
        overlay(alignment: .top) {
            if let message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 8, y: 4)
                    .padding(.horizontal)
                    .onTapGesture(perform: onTap)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: message)
    }
}
