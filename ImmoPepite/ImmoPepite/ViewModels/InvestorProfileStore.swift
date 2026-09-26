import Foundation
import Observation

/// Profil investisseur partagé par toute l'app, persisté dans `UserDefaults`.
@Observable
@MainActor
final class InvestorProfileStore {
    private static let storageKey = "investorProfile.v1"

    var profile: InvestorProfile {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(InvestorProfile.self, from: data) {
            profile = stored
        } else {
            profile = .default
        }
    }

    func reset() {
        profile = .default
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
