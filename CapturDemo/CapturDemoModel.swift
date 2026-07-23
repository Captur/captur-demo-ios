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

    /// Whether the camera screen is on screen. Separate from
    /// `cameraController`: dismissing the camera keeps the controller alive
    /// so the same camera can be resumed later.
    @Published private(set) var isCameraPresented = false

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
            isCameraPresented = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-presents the camera screen with the existing controller. A session
    /// allows one camera at a time — preparing a second one throws
    /// `.cameraAlreadyActive` — so resuming means remounting the same one.
    func resumeCamera() {
        guard cameraController != nil else { return }

        errorMessage = nil
        latestPrediction = nil
        isCameraPresented = true
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
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try await cameraController.captureImage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Camera hardware controls. Unsupported combinations (e.g. torch on the
    // front camera) throw; the message is surfaced like any other error.

    func toggleTorch() async {
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try await cameraController.toggleTorch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePosition() async {
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try await cameraController.togglePosition()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLens() async {
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try await cameraController.toggleLens()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleZoom() async {
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try await cameraController.toggleZoom()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Hides the camera without ending anything: the controller stays alive
    /// and the session still counts it as its active camera, so the same
    /// camera can be resumed with `resumeCamera()`.
    func dismissCamera() {
        isCameraPresented = false
        latestPrediction = nil
        errorMessage = nil
    }

    /// Ends the flow for good — only the review screen offers this. Clearing
    /// `cameraController` unmounts `CapturCameraScreen`, and since SDK 0.2.0
    /// the client must also call `close()` on the controller, which closes
    /// the session with it. The next attempt starts over with a fresh one.
    func closeSession() async {
        let controller = cameraController
        isCameraPresented = false
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
