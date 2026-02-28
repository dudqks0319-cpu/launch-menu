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
