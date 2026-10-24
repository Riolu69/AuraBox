//
//  Theme.swift
//  SceneBox
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Design tokens in native Apple Style. 
/// Automatically supports Light and Dark modes.
enum Theme {
    // MARK: Colour

    #if os(macOS)
    static let background = Color(NSColor.windowBackgroundColor)
    static let surface = Color(NSColor.controlBackgroundColor)
    static let elevated = Color(NSColor.windowBackgroundColor)
    static let hairline = Color(NSColor.separatorColor)
    static let textSecondary = Color(NSColor.secondaryLabelColor)
    static let textTertiary = Color(NSColor.tertiaryLabelColor)
    static let success = Color(NSColor.systemGreen)
    static let warning = Color(NSColor.systemOrange)
    static let danger = Color(NSColor.systemRed)
    #else
    static let background = Color(UIColor.systemBackground)
    static let surface = Color(UIColor.secondarySystemBackground)
    static let elevated = Color(UIColor.tertiarySystemBackground)
    static let hairline = Color(UIColor.separator)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
    static let success = Color(UIColor.systemGreen)
    static let warning = Color(UIColor.systemOrange)
    static let danger = Color(UIColor.systemRed)
    #endif

    // Apple Blue as default accent color
    static let defaultAccentHex = "007AFF"

    // Parsed once.
    static let accent: Color = Color(hex: defaultAccentHex)
    static let onAccent: Color = accent.contrastingForeground

    // Apple's standard system palette
    static let accentPresets: [String] = [
        "007AFF", // Blue
        "34C759", // Green
        "5856D6", // Indigo
        "FF3B30", // Red
        "FF9500", // Orange
        "FFCC00", // Yellow
        "AF52DE", // Purple
        "FF2D55", // Pink
        "32ADE6", // Cyan
        "00C7BE", // Teal
        "8E8E93", // Gray
    ]

    // MARK: Shape (radius follows hierarchy: the bigger the thing, the rounder)

    static let posterCorner: CGFloat = 10
    static let rowCorner: CGFloat = 14
    static let cardCorner: CGFloat = 18
    static let posterAspect: CGFloat = 2.0 / 3.0

    // MARK: Motion (only in answer to a touch)

    /// Presses and toggles.
    static let snappy = Animation.snappy(duration: 0.22)
    /// Expanding, collapsing, switching sections.
    static let smooth = Animation.smooth(duration: 0.32)
}

// MARK: - Type

extension Font {
    /// Standard SF Pro display type (Apple native look).
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    /// Section title adapted for dynamic Light/Dark text.
    func sectionTitleStyle() -> some View {
        font(.display(24, weight: .bold))
            .foregroundStyle(.primary) // Автоматически черный днем и белый ночью
            .accessibilityAddTraits(.isHeader)
    }
}