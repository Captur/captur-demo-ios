//
//  CaptureFlowModel.swift
//  CapturDemo
//

import AVFoundation
import CapturSDK
import Combine
import SwiftUI

/// Drives one photo-capture flow, one SDK call per step.
/// The numbered steps below are the entire Captur SDK lifecycle;
/// `FlowView` shows them to the user as they happen.
@MainActor
final class CaptureFlowModel: ObservableObject {

    /// Where the flow currently is. Each phase maps onto a step in `FlowView`.
    enum Phase {
        case idle
        case preparingSession
        case sessionReady
        case preparingCamera
        case cameraReady
        case cameraOpen
        case finished(CapturFinalDecision)
        case closed(CapturFinalDecision?)
    }

    @Published private(set) var phase: Phase = .idle

    /// Live guidance from the latest `.prediction` event.
    @Published private(set) var livePredictions: String?

    /// The last error, shown as a transient toast; the failed step can be retried.
    @Published private(set) var errorMessage: String?
    private var errorDismissTask: Task<Void, Never>?

    private(set) var session: CapturSession?
    private(set) var cameraController: CapturCameraController?

    // Before everything: create one Captur instance for the lifetime
    // of the app. Initialization is lightweight and synchronous.
    private let captur = Captur(apiKey: CapturConfig.apiKey)

    /// Step 1: Prepare a session for the policy. This authenticates with your
    /// API key and downloads the on-device model — call it early, ahead of capture.
    func prepareSession(for useCase: UseCase) async {
        dismissError()
        phase = .preparingSession
        do {
            session = try await captur.prepareSession(
                policyType: useCase.policyType,
                location: useCase.demoLocation,
                reference: "demo-\(UUID().uuidString)",
                metadata: ["source": "captur-demo-ios"]
            )
            phase = .sessionReady
        } catch CapturSessionError.authenticationFailed {
            showError("Authentication failed. API key is either missing or malformed/expired")
            phase = .idle
        } catch {
            showError(error.localizedDescription)
            phase = .idle
        }
    }

    /// Step 2: Prepare the camera on the session. This loads the models and
    /// returns a `CapturCameraController`. The SDK checks camera permission but
    /// never prompts — the app asks the user first. Every later result arrives
    /// through the single event callback (Step 4).
    func prepareCamera(for useCase: UseCase) async {
        guard let session else { return }
        dismissError()
        phase = .preparingCamera
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            showError("Camera access is required. Enable it in Settings.")
            phase = .sessionReady
            return
        }
        do {
            cameraController = try await session.prepareCamera(
                location: useCase.demoLocation,
                onCapturEvent: { [weak self] event in
                    self?.handleCapturEvents(event)
                }
            )
            phase = .cameraReady
        } catch {
            showError(error.localizedDescription)
            phase = .sessionReady
        }
    }

    /// Step 3: Open the camera. There is no start() call — presenting
    /// `CapturCameraScreen` is what starts the preview and live predictions.
    func openCamera() {
        guard case .cameraReady = phase else { return }
        livePredictions = nil
        phase = .cameraOpen
    }

    // Step 4: Handle events while the camera is open.
    private func handleCapturEvents(_ event: CapturEvents) {
        switch event {
        case .prediction(let prediction):
            // Live, per-frame guidance while the user frames the photo.
            livePredictions = prediction.decision?.title ?? prediction.decision?.value
        case .finalDecision(let finalDecision):
            // The capture outcome: JPEG image + decision + what triggered it.
            // What happens next (display, upload, persist) is up to the app.
            phase = .finished(finalDecision)
        case .failed(let error):
            showError(error.localizedDescription)
            closeCamera()
        @unknown default:
            break
        }
    }

    /// Manual shutter. The SDK can also finalize on its own when the photo
    /// looks consistently good or on timeout (`finalDecision.trigger`).
    func captureImage() async {
        guard let cameraController else { return }
        do {
            try await cameraController.captureImage()
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// Resume capturing on the same open camera after a final decision.
    func retake() {
        guard let cameraController, case .finished = phase else { return }
        do {
            livePredictions = nil
            try cameraController.retake()
            phase = .cameraOpen
        } catch {
            showError(error.localizedDescription)
            closeCamera()
        }
    }

    func toggleTorch() async {
        try? await cameraController?.toggleTorch()
    }

    /// Step 5: Close. Dismissing `CapturCameraScreen` — removing it from the
    /// view hierarchy — is what closes the camera and its session; there is
    /// no close() call. The next attempt starts over from Step 1 with a
    /// fresh session.
    func closeCamera() {
        var finalDecision: CapturFinalDecision?
        if case .finished(let final) = phase { finalDecision = final }
        cameraController = nil
        session = nil
        livePredictions = nil
        phase = .closed(finalDecision)
    }

    func reset() {
        cameraController = nil
        session = nil
        livePredictions = nil
        dismissError()
        phase = .idle
    }

    /// Shows an error as a transient toast that hides itself after a moment.
    private func showError(_ message: String) {
        errorMessage = message
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            errorMessage = nil
        }
    }

    func dismissError() {
        errorDismissTask?.cancel()
        errorMessage = nil
    }
}
