import SwiftUI

struct WidgetPlaceholderView: View {
    var snapshot: WidgetSnapshot

    init(snapshot: WidgetSnapshot = WidgetSnapshot()) {
        self.snapshot = snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.title)
                .font(.headline)
            Text(snapshot.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}
