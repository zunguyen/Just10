import Foundation
import Observation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class AppSettings {
    var theme: AppTheme = .system { didSet { saveTheme() } }
    var hasShownQuitConfirmation: Bool = false { didSet { saveQuitFlag() } }

    private let themeKey = "menubard.theme"
    private let quitFlagKey = "menubard.hasShownQuitConfirmation"

    init() {
        if let raw = UserDefaults.standard.string(forKey: themeKey),
           let value = AppTheme(rawValue: raw) {
            theme = value
        }
        hasShownQuitConfirmation = UserDefaults.standard.bool(forKey: quitFlagKey)
    }

    private func saveTheme() {
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }

    private func saveQuitFlag() {
        UserDefaults.standard.set(hasShownQuitConfirmation, forKey: quitFlagKey)
    }
}
