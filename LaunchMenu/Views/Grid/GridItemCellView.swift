import AppKit
import SwiftUI

struct GridItemCellView: View {
    var item: LaunchItem
    var icon: NSImage?
    var isSelected: Bool = false
    var isEditing: Bool = false
    var onSelect: () -> Void = {}
    var onEnterEditing: () -> Void = {}
    var onLaunch: (LaunchItem) -> Void = { _ in }
    var onRevealInFinder: (LaunchItem) -> Void = { _ in }
    var onAddToDock: (LaunchItem) -> Void = { _ in }
    var onUninstall: (LaunchItem) -> Void = { _ in }
    var onHide: (LaunchItem) -> Void = { _ in }
    var onRename: (LaunchItem) -> Void = { _ in }
    var iconSize: CGFloat = 56
    var showsAppName: Bool = true
    @State private var jigglePhase = false
    @State private var jiggleDelay = Double.random(in: 0...0.08)

    var body: some View {
        VStack(spacing: 8) {
            iconView

            if showsAppName {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: max(88, iconSize + 32))
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.95) : Color.clear, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .rotationEffect(isEditing ? .degrees(jigglePhase ? 2 : -2) : .zero)
        .animation(
            isEditing
            ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true).delay(jiggleDelay)
            : .easeOut(duration: 0.12),
            value: jigglePhase
        )
        .onTapGesture(count: 2) {
            guard isEditing == false else { return }
            onLaunch(item)
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    onSelect()
                }
        )
        .onLongPressGesture(minimumDuration: 0.5) {
            onEnterEditing()
        }
        .contextMenu {
            Button(L10n.t("context.open.app")) {
                onLaunch(item)
            }
            Button(L10n.t("context.reveal.finder")) {
                onRevealInFinder(item)
            }
            Button(L10n.t("context.add.dock")) {
                onAddToDock(item)
            }
            Divider()
            Button(L10n.t("context.uninstall.app"), role: .destructive) {
                onUninstall(item)
            }
            .disabled(item.isSystemApp)
            Divider()
            Button(L10n.t("context.hide.app")) {
                onHide(item)
            }
            Button(L10n.t("context.rename.app")) {
                onRename(item)
            }
        }
        .onAppear {
            jigglePhase = isEditing
        }
        .onChange(of: isEditing) { _, newValue in
            jigglePhase = newValue
            if newValue == false {
                jiggleDelay = Double.random(in: 0...0.08)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
        } else {
            Image(systemName: "app.fill")
                .font(.title2)
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(.secondary)
        }
    }
}
