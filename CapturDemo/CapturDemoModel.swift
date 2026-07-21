//
//  CapturDemoModel.swift
//  CapturDemo
//

import AVFoundation
import CapturSDK
import Observation
import UIKit

@MainActor
@Observable
final class CapturDemoModel {
    enum Step {
        case session
        case camera
        case ready
    }

    private let captur = Captur(apiKey: "captur-workspace-697553f4a3d02d97a5a25614.0832c852-cda0-429f-948a-ccc766461361")
    private let location = CapturLocation(latitude: 51.5074, longitude: -0.1278)

    private(set) var session: CapturSession?
    private(set) var cameraController: CapturCameraController?
    private(set) var latestPrediction: CapturPrediction?
    private(set) var capturedImage: UIImage?
    private(set) var errorMessage: String?

    var step: Step {
        if cameraController != nil { return .ready }
        if session != nil { return .camera }
        return .session
    }

    func prepareSession() async {
        errorMessage = nil

        do {
            session = try await captur.prepareSession(
                policyType: "eBike",
                location: location
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareCamera() async {
        guard let session else { return }

        errorMessage = nil
        latestPrediction = nil
        capturedImage = nil

        guard await AVCaptureDevice.requestAccess(for: .video) else {
            errorMessage = "Camera access is required."
            return
        }

        do {
            cameraController = try await session.prepareCamera(
                location: location
            ) { [weak self] event in
                self?.handleCapturEvent(event)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retake() {
        guard let cameraController else { return }

        errorMessage = nil

        do {
            try cameraController.retake()
            latestPrediction = nil
            capturedImage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetSession() {
        session = nil
        cameraController = nil
        latestPrediction = nil
        capturedImage = nil
        errorMessage = nil
    }

    private func handleCapturEvent(_ event: CapturEvents) {
        switch event {
        case .prediction(let prediction):
            latestPrediction = prediction

        case .finalDecision(let finalDecision):
            latestPrediction = finalDecision.prediction

            guard let image = UIImage(data: finalDecision.imageData) else {
                errorMessage = "The captured image could not be decoded."
                return
            }

            capturedImage = image

        case .failed(let error):
            errorMessage = error.localizedDescription

        @unknown default:
            break
        }
    }
}
