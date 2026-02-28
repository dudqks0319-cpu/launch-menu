import AppKit
import SwiftUI

struct SearchResultListView: View {
    var results: [LaunchItem]
    var onLaunch: (LaunchItem) -> Void = { _ in }
    var iconProvider: (LaunchItem) -> NSImage? = { _ in nil }

    var body: some View {
        Group {
            if results.isEmpty {
                Text(L10n.t("search.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List(results) { item in
                    HStack(spacing: 10) {
                        if let icon = iconProvider(item) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.body)
                            Text(item.bundleIdentifier ?? L10n.t("common.hyphen"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onLaunch(item)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
