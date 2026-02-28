import AppKit
import SwiftUI

struct FolderHeaderView: View {
    var folder: LaunchFolder
    var iconProvider: (LaunchItem) -> NSImage?
    var onRename: (String) -> Void

    @State private var isEditingName = false
    @State private var draftName: String
    @FocusState private var isNameFieldFocused: Bool

    init(
        folder: LaunchFolder = LaunchFolder(),
        iconProvider: @escaping (LaunchItem) -> NSImage? = { _ in nil },
        onRename: @escaping (String) -> Void = { _ in }
    ) {
        self.folder = folder
        self.iconProvider = iconProvider
        self.onRename = onRename
        _draftName = State(initialValue: folder.name)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FolderIconView(
                folderName: folder.name,
                items: folder.items,
                iconProvider: iconProvider,
                showsName: false
            )

            VStack(alignment: .leading, spacing: 6) {
                if isEditingName {
                    TextField(L10n.t("folder.name.placeholder"), text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            commitNameEdit()
                        }
                } else {
                    Text(folder.name)
                        .font(.headline)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            beginNameEdit()
                        }
                }

                Text(L10n.f("folder.app.count", folder.items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEditingName {
                HStack(spacing: 8) {
                    Button(L10n.t("common.cancel")) {
                        cancelNameEdit()
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.t("common.done")) {
                        commitNameEdit()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button {
                    beginNameEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
            }
        }
        .onChange(of: folder.name) { _, newValue in
            if isEditingName == false {
                draftName = newValue
            }
        }
    }

    private func beginNameEdit() {
        draftName = folder.name
        isEditingName = true
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func cancelNameEdit() {
        draftName = folder.name
        isEditingName = false
        isNameFieldFocused = false
    }

    private func commitNameEdit() {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            cancelNameEdit()
            return
        }

        isEditingName = false
        isNameFieldFocused = false

        guard trimmedName != folder.name else { return }
        onRename(trimmedName)
    }
}

struct FolderIconView: View {
    var folderName: String
    var items: [LaunchItem]
    var iconProvider: (LaunchItem) -> NSImage?
    var showsName: Bool

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    init(
        folderName: String,
        items: [LaunchItem],
        iconProvider: @escaping (LaunchItem) -> NSImage? = { _ in nil },
        showsName: Bool = true
    ) {
        self.folderName = folderName
        self.items = items
        self.iconProvider = iconProvider
        self.showsName = showsName
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)

                LazyVGrid(columns: gridColumns, spacing: 4) {
                    ForEach(0..<9, id: \.self) { index in
                        miniIconCell(at: index)
                    }
                }
                .padding(8)
            }
            .frame(width: 76, height: 76)

            if showsName {
                Text(folderName)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 88)
            }
        }
    }

    @ViewBuilder
    private func miniIconCell(at index: Int) -> some View {
        if index < items.count, let icon = iconProvider(items[index]) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else if index < items.count {
            Image(systemName: "app.fill")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.quaternary.opacity(0.2))
        }
    }
}
