import Foundation

protocol SettingsStorage {
    func load() -> LaunchSettings
    func save(_ settings: LaunchSettings)
    func reset()
}

extension SettingsStorage {
    func reset() {
        save(.default)
    }
}

final class InMemorySettingsStorage: SettingsStorage {
    private var current: LaunchSettings

    init(initialValue: LaunchSettings = .default) {
        self.current = initialValue
    }

    func load() -> LaunchSettings {
        current
    }

    func save(_ settings: LaunchSettings) {
        current = settings
    }

    func reset() {
        current = .default
    }
}

final class UserDefaultsSettingsStorage: SettingsStorage {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fallbackSettings: LaunchSettings

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "launchmenu.settings.v1",
        fallbackSettings: LaunchSettings = .default
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.fallbackSettings = fallbackSettings
    }

    func load() -> LaunchSettings {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return fallbackSettings
        }
        return (try? decoder.decode(LaunchSettings.self, from: data)) ?? fallbackSettings
    }

    func save(_ settings: LaunchSettings) {
        guard let data = try? encoder.encode(settings) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    func reset() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
