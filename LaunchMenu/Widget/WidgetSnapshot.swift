import Foundation

struct WidgetSnapshot: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var subtitle: String

    init(
        id: UUID = UUID(),
        title: String = "LaunchMenu",
        subtitle: String = "Widget Placeholder"
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}
