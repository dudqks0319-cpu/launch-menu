import SwiftUI

struct SmartTabChipView: View {
    var tab: SmartTabModel
    var isSelected: Bool
    var onSelect: () -> Void = {}

    var body: some View {
        Button(action: onSelect) {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}
