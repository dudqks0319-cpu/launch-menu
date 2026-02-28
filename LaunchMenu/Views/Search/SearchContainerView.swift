import AppKit
import SwiftUI

struct SearchContainerView: View {
    @Binding private var query: String
    var results: [LaunchItem]
    var showsResultList: Bool
    var onLaunch: (LaunchItem) -> Void
    var iconProvider: (LaunchItem) -> NSImage?

    init(
        query: Binding<String>,
        results: [LaunchItem],
        showsResultList: Bool = true,
        onLaunch: @escaping (LaunchItem) -> Void = { _ in },
        iconProvider: @escaping (LaunchItem) -> NSImage? = { _ in nil }
    ) {
        _query = query
        self.results = results
        self.showsResultList = showsResultList
        self.onLaunch = onLaunch
        self.iconProvider = iconProvider
    }

    init(state: SearchState = .empty, initialQuery: String = "") {
        let initialText = initialQuery.isEmpty ? state.query : initialQuery
        _query = .constant(initialText)
        self.results = state.results
        self.showsResultList = true
        self.onLaunch = { _ in }
        self.iconProvider = { _ in nil }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(L10n.t("search.placeholder"), text: $query)
                    .textFieldStyle(.plain)

                if query.isEmpty == false {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )

            if showsResultList {
                SearchResultListView(
                    results: results,
                    onLaunch: onLaunch,
                    iconProvider: iconProvider
                )
                .frame(maxHeight: 220)
            }
        }
    }
}
