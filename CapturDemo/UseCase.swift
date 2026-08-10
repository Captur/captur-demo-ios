//
//  UseCase.swift
//  CapturDemo
//
//  Created by Leonardo Tedone on 22/07/2026.
//

import CapturSDK

/// The demo use cases, one per policy type bundled with the CapturSDK.
enum UseCase: String, CaseIterable, Identifiable {
    case eBikeParking
    case eScooterParking
    case packageDelivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eBikeParking: return "E-bike parking"
        case .eScooterParking: return "E-scooter parking"
        case .packageDelivery: return "Package delivery"
        }
    }

    /// The Captur policy that validates the photo.
    var policyType: String {
        switch self {
        case .eBikeParking: return "eBike"
        case .eScooterParking: return "eScooter"
        case .packageDelivery: return "package"
        }
    }
    /// The SDK never reads GPS itself — the app supplies the capture location.
    /// A real app would use CoreLocation; the demo uses fixed coordinates.
    var demoLocation: CapturLocation {
        switch self {
        case .eBikeParking:
            return CapturLocation(latitude: 51.5074, longitude: -0.1278) // London
        case .eScooterParking:
            return CapturLocation(latitude: 48.8566, longitude: 2.3522) // Paris
        case .packageDelivery:
            return CapturLocation(latitude: 43.6532, longitude: -79.3832) // Toronto
        }
    }
}
