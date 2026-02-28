import Foundation

enum SmartTabKind: String, CaseIterable, Codable {
    case all
    case recent
    case frequent
    case newlyInstalled
}

struct SmartTabModel: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var systemImage: String
    var predicateDescription: String
    var kind: SmartTabKind

    init(
        id: String? = nil,
        title: String = "",
        systemImage: String = "square.grid.2x2",
        predicateDescription: String? = nil,
        kind: SmartTabKind = .all
    ) {
        self.kind = kind
        self.id = id ?? kind.rawValue
        self.title = title
        self.systemImage = systemImage
        self.predicateDescription = predicateDescription ?? kind.rawValue
    }
}

extension SmartTabModel {
    static var all: SmartTabModel {
        SmartTabModel(
            title: L10n.t("tab.all"),
            systemImage: "square.grid.2x2",
            predicateDescription: "all"
        )
    }

    static var recent: SmartTabModel {
        SmartTabModel(
            title: L10n.t("tab.recent"),
            systemImage: "clock.fill",
            kind: .recent
        )
    }

    static var frequent: SmartTabModel {
        SmartTabModel(
            title: L10n.t("tab.frequent"),
            systemImage: "flame.fill",
            kind: .frequent
        )
    }

    static var newlyInstalled: SmartTabModel {
        SmartTabModel(
            title: L10n.t("tab.new"),
            systemImage: "sparkles",
            kind: .newlyInstalled
        )
    }
}

struct SmartTabSection: Identifiable, Hashable, Codable {
    let tab: SmartTabModel
    var items: [LaunchItem]

    var id: String {
        tab.id
    }
}
