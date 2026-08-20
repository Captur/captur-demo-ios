//
//  CapturConfig.swift
//  CapturDemo
//
//  Created by Leonardo Tedone on 22/07/2026.
//

import Foundation

/// Reads the Captur API key from `CapturDemo/Secrets.env` — a gitignored
/// dotenv-style file with a single `CAPTUR_API_KEY=your-key` line — so real
/// keys never reach source control. Without the file the app still builds
/// and runs; preparing a session fails with an authentication error.
enum CapturConfig {
    static let apiKey: String = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "env"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return "" }

        for line in contents.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == "CAPTUR_API_KEY" {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }()

    static var isConfigured: Bool { !apiKey.isEmpty }
}
