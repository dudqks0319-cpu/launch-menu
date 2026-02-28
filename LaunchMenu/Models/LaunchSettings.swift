import Foundation

enum LaunchToggleHotkey: String, CaseIterable, Codable {
    case commandL
    case optionSpace
    case f4

    var title: String {
        switch self {
        case .commandL:
            return L10n.t("hotkey.command.l")
        case .optionSpace:
            return L10n.t("hotkey.option.space")
        case .f4:
            return L10n.t("hotkey.f4")
        }
    }

    var displayText: String {
        switch self {
        case .commandL:
            return "Command+L"
        case .optionSpace:
            return "Option+Space"
        case .f4:
            return "F4"
        }
    }
}

enum HotCornerLocation: String, CaseIterable, Codable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var title: String {
        switch self {
        case .topLeft:
            return L10n.t("hotcorner.top.left")
        case .topRight:
            return L10n.t("hotcorner.top.right")
        case .bottomLeft:
            return L10n.t("hotcorner.bottom.left")
        case .bottomRight:
            return L10n.t("hotcorner.bottom.right")
        }
    }
}

enum ThemeAppearanceMode: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system:
            return L10n.t("appearance.mode.system")
        case .light:
            return L10n.t("appearance.mode.light")
        case .dark:
            return L10n.t("appearance.mode.dark")
        }
    }
}

enum BackgroundStyle: String, CaseIterable, Codable {
    case liquidGlass
    case solidBlack
    case customColor

    var title: String {
        switch self {
        case .liquidGlass:
            return L10n.t("background.style.liquid")
        case .solidBlack:
            return L10n.t("background.style.solid.black")
        case .customColor:
            return L10n.t("background.style.custom.color")
        }
    }
}

struct LaunchSettings: Equatable, Codable {
    var toggleHotkey: LaunchToggleHotkey
    var launchAtLoginEnabled: Bool
    var showHiddenApps: Bool
    var searchDebounceMilliseconds: Int
    var gridColumnCount: Int
    var maxRecentItems: Int
    var maxFrequentItems: Int
    var newInstallWindowDays: Int
    var iconCacheItemLimit: Int
    var iconCacheMemoryLimitBytes: Int
    var hotCornerEnabled: Bool
    var hotCornerLocation: HotCornerLocation
    var backgroundStyle: BackgroundStyle
    var backgroundOpacity: Double
    var iconSize: Double
    var showsAppNames: Bool
    var appearanceMode: ThemeAppearanceMode
    var customBackgroundHex: String

    init(
        toggleHotkey: LaunchToggleHotkey = .commandL,
        launchAtLoginEnabled: Bool = false,
        showHiddenApps: Bool = false,
        searchDebounceMilliseconds: Int = 200,
        gridColumnCount: Int = 4,
        maxRecentItems: Int = 12,
        maxFrequentItems: Int = 12,
        newInstallWindowDays: Int = 14,
        iconCacheItemLimit: Int = 240,
        iconCacheMemoryLimitBytes: Int = 64 * 1024 * 1024,
        hotCornerEnabled: Bool = false,
        hotCornerLocation: HotCornerLocation = .topLeft,
        backgroundStyle: BackgroundStyle = .liquidGlass,
        backgroundOpacity: Double = 0.22,
        iconSize: Double = 56,
        showsAppNames: Bool = true,
        appearanceMode: ThemeAppearanceMode = .system,
        customBackgroundHex: String = "#1A1A1A"
    ) {
        self.toggleHotkey = toggleHotkey
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.showHiddenApps = showHiddenApps
        self.searchDebounceMilliseconds = searchDebounceMilliseconds
        self.gridColumnCount = gridColumnCount
        self.maxRecentItems = maxRecentItems
        self.maxFrequentItems = maxFrequentItems
        self.newInstallWindowDays = newInstallWindowDays
        self.iconCacheItemLimit = iconCacheItemLimit
        self.iconCacheMemoryLimitBytes = iconCacheMemoryLimitBytes
        self.hotCornerEnabled = hotCornerEnabled
        self.hotCornerLocation = hotCornerLocation
        self.backgroundStyle = backgroundStyle
        self.backgroundOpacity = min(max(backgroundOpacity, 0), 1)
        self.iconSize = min(max(iconSize, 48), 96)
        self.showsAppNames = showsAppNames
        self.appearanceMode = appearanceMode
        self.customBackgroundHex = customBackgroundHex
    }

    static let `default` = LaunchSettings()
}

extension LaunchSettings {
    private enum CodingKeys: String, CodingKey {
        case toggleHotkey
        case launchAtLoginEnabled
        case showHiddenApps
        case searchDebounceMilliseconds
        case gridColumnCount
        case maxRecentItems
        case maxFrequentItems
        case newInstallWindowDays
        case iconCacheItemLimit
        case iconCacheMemoryLimitBytes
        case hotCornerEnabled
        case hotCornerLocation
        case backgroundStyle
        case backgroundOpacity
        case iconSize
        case showsAppNames
        case appearanceMode
        case customBackgroundHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toggleHotkey = try container.decodeIfPresent(LaunchToggleHotkey.self, forKey: .toggleHotkey) ?? .commandL
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? false
        showHiddenApps = try container.decodeIfPresent(Bool.self, forKey: .showHiddenApps) ?? false
        searchDebounceMilliseconds = try container.decodeIfPresent(Int.self, forKey: .searchDebounceMilliseconds) ?? 200
        gridColumnCount = try container.decodeIfPresent(Int.self, forKey: .gridColumnCount) ?? 4
        maxRecentItems = try container.decodeIfPresent(Int.self, forKey: .maxRecentItems) ?? 12
        maxFrequentItems = try container.decodeIfPresent(Int.self, forKey: .maxFrequentItems) ?? 12
        newInstallWindowDays = try container.decodeIfPresent(Int.self, forKey: .newInstallWindowDays) ?? 14
        iconCacheItemLimit = try container.decodeIfPresent(Int.self, forKey: .iconCacheItemLimit) ?? 240
        iconCacheMemoryLimitBytes = try container.decodeIfPresent(Int.self, forKey: .iconCacheMemoryLimitBytes) ?? 64 * 1024 * 1024
        hotCornerEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotCornerEnabled) ?? false
        hotCornerLocation = try container.decodeIfPresent(HotCornerLocation.self, forKey: .hotCornerLocation) ?? .topLeft
        backgroundStyle = try container.decodeIfPresent(BackgroundStyle.self, forKey: .backgroundStyle) ?? .liquidGlass
        backgroundOpacity = min(max(try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.22, 0), 1)
        iconSize = min(max(try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 56, 48), 96)
        showsAppNames = try container.decodeIfPresent(Bool.self, forKey: .showsAppNames) ?? true
        appearanceMode = try container.decodeIfPresent(ThemeAppearanceMode.self, forKey: .appearanceMode) ?? .system
        customBackgroundHex = try container.decodeIfPresent(String.self, forKey: .customBackgroundHex) ?? "#1A1A1A"
    }
}
