//
//  CapturConfig.swift
//  CapturDemo
//

/// Captur provides one API key per app. Paste yours below to run the demo.
/// Never commit a real key to source control.
enum CapturConfig {
    static let apiKey = "YOUR_CAPTUR_API_KEY"

    static var isConfigured: Bool { !apiKey.isEmpty && apiKey != "YOUR_CAPTUR_API_KEY" }
}
