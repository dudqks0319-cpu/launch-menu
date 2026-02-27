import AppKit
import SwiftUI

struct GridItemCellView: View {
    var item: LaunchItem
    var icon: NSImage?
    var onLaunch: (LaunchItem) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 8) {
            iconView

            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(count: 2) {
            onLaunch(item)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 56, height: 56)
        } else {
            Image(systemName: "app.fill")
                .font(.title2)
                .frame(width: 56, height: 56)
                .foregroundStyle(.secondary)
        }
    }
}
