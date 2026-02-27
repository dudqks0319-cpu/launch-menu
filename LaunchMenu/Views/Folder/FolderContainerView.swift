import SwiftUI

struct FolderContainerView: View {
    var folder: LaunchFolder

    init(folder: LaunchFolder = LaunchFolder()) {
        self.folder = folder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FolderHeaderView(title: folder.name, itemCount: folder.items.count)

            if folder.items.isEmpty {
                Text("폴더가 비어 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(folder.items) { item in
                    Text(item.title)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
    }
}
