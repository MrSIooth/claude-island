//
//  Settings.swift
//  ClaudeIsland
//
//  App settings manager using UserDefaults
//

import Foundation

enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let soundEnabled = "soundEnabled"
    }

    // MARK: - Sound

    /// Whether notification sounds are enabled
    static var soundEnabled: Bool {
        get {
            // Default to true if not set
            if defaults.object(forKey: Keys.soundEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.soundEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.soundEnabled)
        }
    }
}
