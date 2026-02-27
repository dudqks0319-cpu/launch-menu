import Foundation

struct LaunchItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var bundleIdentifier: String?
    var bundleURL: URL?
    var executableName: String?
    var installedAt: Date?
    var lastModifiedAt: Date?
    var isSystemApp: Bool
    var isHidden: Bool
    var keywords: [String]

    init(
        id: UUID = UUID(),
        title: String = "Placeholder App",
        bundleIdentifier: String? = nil,
        bundleURL: URL? = nil,
        executableName: String? = nil,
        installedAt: Date? = nil,
        lastModifiedAt: Date? = nil,
        isSystemApp: Bool = false,
        isHidden: Bool = false,
        keywords: [String] = []
    ) {
        self.id = id
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
        self.executableName = executableName
        self.installedAt = installedAt
        self.lastModifiedAt = lastModifiedAt
        self.isSystemApp = isSystemApp
        self.isHidden = isHidden
        self.keywords = keywords
    }
}

extension LaunchItem {
    var appPath: String? {
        bundleURL?.path
    }

    var stableIdentifier: String {
        if let bundleIdentifier, bundleIdentifier.isEmpty == false {
            return "bundle:\(bundleIdentifier.lowercased())"
        }
        if let appPath, appPath.isEmpty == false {
            return "path:\(appPath.lowercased())"
        }
        return "title:\(title.lowercased())"
    }
}

extension LaunchItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case bundleIdentifier
        case bundleURL
        case executableName
        case installedAt
        case lastModifiedAt
        case isSystemApp
        case isHidden
        case keywords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Placeholder App"
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        bundleURL = try container.decodeIfPresent(URL.self, forKey: .bundleURL)
        executableName = try container.decodeIfPresent(String.self, forKey: .executableName)
        installedAt = try container.decodeIfPresent(Date.self, forKey: .installedAt)
        lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt)
        isSystemApp = try container.decodeIfPresent(Bool.self, forKey: .isSystemApp) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encodeIfPresent(bundleURL, forKey: .bundleURL)
        try container.encodeIfPresent(executableName, forKey: .executableName)
        try container.encodeIfPresent(installedAt, forKey: .installedAt)
        try container.encodeIfPresent(lastModifiedAt, forKey: .lastModifiedAt)
        try container.encode(isSystemApp, forKey: .isSystemApp)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(keywords, forKey: .keywords)
    }
}
