import SwiftUI

struct FolderHeaderView: View {
    var title: String
    var itemCount: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(itemCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
