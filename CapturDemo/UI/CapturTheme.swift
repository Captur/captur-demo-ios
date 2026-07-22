//
//  CapturTheme.swift
//  CapturDemo
//
//  Captur's brand colors and fonts, in one place — values match the Captur
//  design system (as used in CapturDemoSPM). The rest of the app only ever
//  references these names, so restyling means editing this file only.
//  Fonts are registered at runtime, so no Info.plist entries are needed.
//

import CoreText
import SwiftUI

// MARK: - Brand colors

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let capturViolet = Color(hex: 0x4938E2)
    static let capturSuccess = Color(hex: 0x0E9F6E)
    static let capturCrimson = Color(hex: 0xDA2739)
}

// MARK: - Brand fonts

extension Font {
    /// Lexend Deca — headings and UI labels.
    static func capturHeading(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("LexendDeca-Medium", size: size, relativeTo: style)
    }

    /// Lato — body and supporting text.
    static func capturBody(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Lato-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Root modifier

extension View {
    /// Apply once at the root of the view tree: registers the bundled fonts,
    /// sets the brand accent for every control, and makes Lato the default
    /// text font. Presented sheets and covers inherit all of it.
    func capturThemed() -> some View {
        CapturTheme.registerFonts
        return self
            .tint(.capturViolet)
            .font(.capturBody(15))
    }
}

// MARK: - Button style

/// Brand button: Captur violet capsule with a white Lexend Deca label.
/// Usage: `.buttonStyle(.capturProminent)` on a button or a whole container.
struct CapturButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.capturHeading(15, relativeTo: .body))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.capturViolet, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension ButtonStyle where Self == CapturButtonStyle {
    static var capturProminent: CapturButtonStyle { CapturButtonStyle() }
}

enum CapturTheme {
    /// Registers the bundled .ttf files with the font system exactly once.
    static let registerFonts: Void = {
        for name in ["Lato-Regular", "LexendDeca-Medium"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing bundled font: \(name).ttf")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}
