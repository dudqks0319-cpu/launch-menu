import Foundation

protocol SearchService {
    func search(query: String, in items: [LaunchItem]) async -> [LaunchItem]
}

struct BasicSearchService: SearchService {
    func search(query: String, in items: [LaunchItem]) async -> [LaunchItem] {
        let normalizedQuery = SearchNormalizer.normalize(query)
        guard normalizedQuery.isEmpty == false else {
            return items
        }

        let queryInitials = HangulInitialMatcher.extractInitials(from: normalizedQuery)
        let queryIsConsonantOnly = HangulInitialMatcher.isConsonantQuery(normalizedQuery)
        let ranked = items.compactMap { item -> (item: LaunchItem, score: Int)? in
            let score = bestScore(
                for: item,
                query: normalizedQuery,
                queryInitials: queryInitials,
                queryIsConsonantOnly: queryIsConsonantOnly
            )
            guard score > 0 else {
                return nil
            }
            return (item: item, score: score)
        }

        return ranked.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.item.title.localizedStandardCompare(rhs.item.title) == .orderedAscending
        }
        .map(\.item)
    }

    private func bestScore(
        for item: LaunchItem,
        query: String,
        queryInitials: String,
        queryIsConsonantOnly: Bool
    ) -> Int {
        var best = 0
        for candidate in searchableCandidates(for: item) {
            best = max(
                best,
                score(
                    query: query,
                    queryInitials: queryInitials,
                    queryIsConsonantOnly: queryIsConsonantOnly,
                    candidate: candidate
                )
            )
        }
        return best
    }

    private func searchableCandidates(for item: LaunchItem) -> [String] {
        var values = [item.title]
        values.append(contentsOf: item.keywords)
        if let bundleIdentifier = item.bundleIdentifier {
            values.append(bundleIdentifier)
        }
        if let executableName = item.executableName {
            values.append(executableName)
        }
        return values
            .map(SearchNormalizer.normalize)
            .filter { $0.isEmpty == false }
    }

    private func score(
        query: String,
        queryInitials: String,
        queryIsConsonantOnly: Bool,
        candidate: String
    ) -> Int {
        let collapsedCandidate = SearchNormalizer.collapseSpaces(candidate)
        let collapsedQuery = SearchNormalizer.collapseSpaces(query)
        let initials = HangulInitialMatcher.extractInitials(from: collapsedCandidate)

        if collapsedCandidate == collapsedQuery {
            return 1_200
        }
        if collapsedCandidate.hasPrefix(collapsedQuery) {
            return 1_000 - min(200, collapsedCandidate.count - collapsedQuery.count)
        }
        if let containsIndex = collapsedCandidate.range(of: collapsedQuery)?.lowerBound {
            let distance = collapsedCandidate.distance(from: collapsedCandidate.startIndex, to: containsIndex)
            return 840 - min(distance, 180)
        }

        if queryIsConsonantOnly, initials.hasPrefix(collapsedQuery) {
            return 780
        }
        if queryIsConsonantOnly, initials.contains(collapsedQuery) {
            return 730
        }
        if queryInitials.isEmpty == false, initials.contains(queryInitials) {
            return 680
        }

        if let fuzzy = FuzzyMatcher.subsequenceScore(needle: collapsedQuery, haystack: collapsedCandidate) {
            return 500 + fuzzy
        }
        if queryIsConsonantOnly,
           let fuzzyInitials = FuzzyMatcher.subsequenceScore(needle: collapsedQuery, haystack: initials) {
            return 420 + fuzzyInitials
        }

        return 0
    }
}

private enum SearchNormalizer {
    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }

    static func collapseSpaces(_ value: String) -> String {
        value.replacingOccurrences(of: " ", with: "")
    }
}

private enum HangulInitialMatcher {
    private static let baseScalar: UInt32 = 0xAC00
    private static let endScalar: UInt32 = 0xD7A3
    private static let initialStep: UInt32 = 21 * 28
    private static let initials = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]
    private static let consonants: Set<Character> = Set("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")

    static func extractInitials(from value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for scalar in value.unicodeScalars {
            let scalarValue = scalar.value
            if scalarValue >= baseScalar, scalarValue <= endScalar {
                let index = Int((scalarValue - baseScalar) / initialStep)
                result += initials[index]
            } else {
                result.append(Character(scalar))
            }
        }
        return result
    }

    static func isConsonantQuery(_ value: String) -> Bool {
        guard value.isEmpty == false else {
            return false
        }
        return value.allSatisfy { consonants.contains($0) || $0 == " " }
    }
}

private enum FuzzyMatcher {
    static func subsequenceScore(needle: String, haystack: String) -> Int? {
        guard needle.isEmpty == false, haystack.isEmpty == false else {
            return nil
        }

        var searchStart = haystack.startIndex
        var score = 0
        var consecutiveStreak = 0

        for character in needle {
            guard let matchIndex = haystack[searchStart...].firstIndex(of: character) else {
                return nil
            }

            let gap = haystack.distance(from: searchStart, to: matchIndex)
            if gap == 0 {
                consecutiveStreak += 1
                score += 20 + (consecutiveStreak * 4)
            } else {
                consecutiveStreak = 0
                score += max(4, 16 - gap)
            }

            searchStart = haystack.index(after: matchIndex)
        }

        return max(1, score)
    }
}
