import Foundation

enum SearchPhase: String, Codable {
    case idle
    case searching
    case finished
}

struct SearchState: Equatable, Codable {
    var query: String
    var phase: SearchPhase
    var results: [LaunchItem]

    static var empty: SearchState {
        SearchState(query: "", phase: .idle, results: [])
    }
}
