import Foundation

enum SmartCategory: String, CaseIterable, Identifiable {
    case all
    case developmentTools
    case design
    case game
    case social
    case productivity
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.t("category.all")
        case .developmentTools:
            return L10n.t("category.development")
        case .design:
            return L10n.t("category.design")
        case .game:
            return L10n.t("category.game")
        case .social:
            return L10n.t("category.social")
        case .productivity:
            return L10n.t("category.productivity")
        case .other:
            return L10n.t("category.other")
        }
    }
}

struct SmartCategorizer {
    static func category(for item: LaunchItem) -> SmartCategory {
        guard let categoryKeyword = item.keywords.first(where: isLSApplicationCategoryKeyword) else {
            return .other
        }
        return category(forLSApplicationCategoryKeyword: categoryKeyword)
    }

    static func category(forLSApplicationCategoryKeyword rawKeyword: String) -> SmartCategory {
        let suffix = normalizedCategorySuffix(from: rawKeyword)

        if developmentCategorySuffixes.contains(suffix) {
            return .developmentTools
        }
        if designCategorySuffixes.contains(suffix) {
            return .design
        }
        if suffix == "games" || suffix.hasSuffix("-games") {
            return .game
        }
        if socialCategorySuffixes.contains(suffix) {
            return .social
        }
        if productivityCategorySuffixes.contains(suffix) {
            return .productivity
        }

        return .other
    }

    private static let lsCategoryPrefix = "public.app-category."

    private static let developmentCategorySuffixes: Set<String> = [
        "developer-tools"
    ]

    private static let designCategorySuffixes: Set<String> = [
        "graphics-design",
        "photography",
        "video"
    ]

    private static let socialCategorySuffixes: Set<String> = [
        "social-networking"
    ]

    private static let productivityCategorySuffixes: Set<String> = [
        "productivity",
        "business",
        "education",
        "finance",
        "reference",
        "utilities"
    ]

    private static func isLSApplicationCategoryKeyword(_ keyword: String) -> Bool {
        keyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .contains("app-category")
    }

    private static func normalizedCategorySuffix(from rawKeyword: String) -> String {
        let normalized = rawKeyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        if let range = normalized.range(of: lsCategoryPrefix) {
            return String(normalized[range.upperBound...])
        }

        return normalized
    }
}
