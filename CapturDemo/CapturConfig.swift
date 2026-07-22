//
//  CapturConfig.swift
//  CapturDemo
//
//  Created by Leonardo Tedone on 22/07/2026.
//

enum CapturConfig {
    static let apiKey = "YOUR_CAPTUR_API_KEY"

    static var isConfigured: Bool { !apiKey.isEmpty && apiKey != "YOUR_CAPTUR_API_KEY" }
}
