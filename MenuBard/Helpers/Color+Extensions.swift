import SwiftUI
import AppKit

extension Color {
    /// Main app background. Light: #f5f5f3 / Dark: #000000
    static let appBackground = Color(nsColor: NSColor(
        light: NSColor(red: 0.961, green: 0.961, blue: 0.953, alpha: 1),
        dark: .black
    ))

    /// Row hover background. Light: #f5f5f3 / Dark: #404040
    static let hoverBackground = Color(nsColor: NSColor(
        light: NSColor(red: 0.961, green: 0.961, blue: 0.953, alpha: 1),
        dark: NSColor(red: 0.251, green: 0.251, blue: 0.251, alpha: 1)
    ))
}

extension NSColor {
    /// Convenience initializer for light/dark adaptive colors.
    convenience init(light: NSColor, dark: NSColor) {
        self.init(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }
}
