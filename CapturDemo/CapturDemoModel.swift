//
//  CapturDemoModel.swift
//  CapturDemo
//

import AVFoundation
import CapturSDK
import Combine

/// Owns the entire CapturSDK lifecycle for one capture flow:
/// prepare a session → prepare the camera → receive events → retake or reset.
/// Everything the SDK reports flows out through the published properties below.
@MainActor
final class CapturDemoModel: ObservableObject {
    // One Captur instance for the lifetime of the app; initialization is
    // lightweight and synchronous.
    private let captur = Captur(apiKey: CapturConfig.apiKey)

    // Chosen when the session is prepared; the camera reuses its location.
    // The SDK never reads GPS — the app supplies every coordinate.
    private var useCase: UseCase = .eBikeParking

    @Published private(set) var session: CapturSession?
    @Published private(set) var cameraController: CapturCameraController?

    /// Latest `.prediction` — refreshed on every camera frame while capturing.
    @Published private(set) var latestPrediction: CapturPrediction?

    /// The capture outcome: image data, decision, and what triggered it.
    /// Non-nil means a capture finished; uploading or persisting the JPEG
    /// is the app's job, not the SDK's.
    @Published private(set) var finalDecision: CapturFinalDecision?

    @Published private(set) var errorMessage: String?

    /// True while `prepareSession` runs — the heaviest call (it downloads
    /// the policy model), so the UI shows a spinner for it.
    @Published private(set) var isPreparingSession = false

    /// Step 1 — `captur.prepareSession`. Authenticates with the API key and
    /// downloads the policy model for the use case, so call it ahead of
    /// capture. A session is single-use: once its camera closes, prepare a
    /// new one.
    func prepareSession(for useCase: UseCase) async {
        self.useCase = useCase
        errorMessage = nil
        isPreparingSession = true
        defer { isPreparingSession = false }

        do {
            session = try await captur.prepareSession(
                policyType: useCase.policyType,
                location: useCase.demoLocation
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Step 2 — `session.prepareCamera`. Loads the downloaded models and
    /// returns the controller that `CapturCameraScreen` renders. Every later
    /// result — live predictions, the final decision, failures — arrives
    /// through the single event callback passed here.
    func prepareCamera() async {
        guard let session else { return }

        errorMessage = nil
        latestPrediction = nil
        finalDecision = nil

        // The SDK checks camera permission but never prompts for it;
        // without this request it would throw .cameraPermissionUnavailable.
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            errorMessage = "Camera access is required."
            return
        }

        do {
            cameraController = try await session.prepareCamera(
                location: useCase.demoLocation
            ) { [weak self] event in
                self?.handleCapturEvent(event)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Discards the captured result and resumes the still-open camera —
    /// valid only while `CapturCameraScreen` remains mounted.
    func retake() {
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try cameraController.retake()
            latestPrediction = nil
            finalDecision = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Manual shutter. The final image and decision arrive through the
    /// event callback as `.finalDecision`, not as a return value.
    func captureImage() async {
        await performCameraControl { try await $0.captureImage() }
    }

    func toggleTorch() async {
        await performCameraControl { try await $0.toggleTorch() }
    }

    func togglePosition() async {
        await performCameraControl { try await $0.togglePosition() }
    }

    func toggleLens() async {
        await performCameraControl { try await $0.toggleLens() }
    }

    func toggleZoom() async {
        await performCameraControl { try await $0.toggleZoom() }
    }

    /// Unsupported combinations (e.g. torch on the front camera) throw;
    /// the message is surfaced like any other error.
    private func performCameraControl(
        _ control: (CapturCameraController) async throws -> Void
    ) async {
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try await control(cameraController)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Back to the start. Clearing `cameraController` unmounts
    /// `CapturCameraScreen`, and since SDK 0.2.0 the client must also call
    /// `close()` on the controller to finish cleanup — dismounting alone is
    /// no longer enough. The next attempt starts over with a fresh session.
    func resetSession() async {
        let controller = cameraController
        session = nil
        cameraController = nil
        latestPrediction = nil
        finalDecision = nil
        errorMessage = nil
        await controller?.close()
    }

    /// The single channel for everything the camera reports, delivered on
    /// the main actor.
    private func handleCapturEvent(_ event: CapturEvents) {
        switch event {
        case .prediction(let prediction):
            // Per-frame inference while the user frames the photo.
            latestPrediction = prediction

        case .finalDecision(let decision):
            // Capture complete — manual shutter, timeout, or a run of
            // consistently good frames (see decision.trigger).
            finalDecision = decision

        case .failed(let error):
            errorMessage = error.localizedDescription

        @unknown default:
            break
        }
    }
}
