//
//  UseCase.swift
//  CapturDemo
//

import CapturSDK

/// The two demo use cases, one per policy type bundled with CapturSDK 0.1.0.
enum UseCase: String, CaseIterable, Identifiable {
    case eBikeParking
    case packageDelivery

    var id: String { rawValue }

    /// The Captur policy that validates the photo.
    var policyType: String {
        switch self {
        case .eBikeParking: return "eBike"
        case .packageDelivery: return "package"
        }
    }

    var title: String {
        switch self {
        case .eBikeParking: return "E-bike parking"
        case .packageDelivery: return "Package delivery"
        }
    }

    var subtitle: String {
        switch self {
        case .eBikeParking: return "Verify an e-bike is parked correctly"
        case .packageDelivery: return "Verify a package was dropped off"
        }
    }

    var systemImage: String {
        switch self {
        case .eBikeParking: return "bicycle"
        case .packageDelivery: return "shippingbox"
        }
    }

    /// The SDK never reads GPS itself — the app supplies the capture location.
    /// A real app would use CoreLocation; the demo uses fixed coordinates.
    var demoLocation: CapturLocation {
        switch self {
        case .eBikeParking:
            return CapturLocation(latitude: 51.5074, longitude: -0.1278) // London
        case .packageDelivery:
            return CapturLocation(latitude: 43.6532, longitude: -79.3832) // Toronto
        }
    }
}
