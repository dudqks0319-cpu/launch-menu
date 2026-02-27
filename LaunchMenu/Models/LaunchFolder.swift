import Foundation

struct LaunchFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var items: [LaunchItem]

    init(
        id: UUID = UUID(),
        name: String = "Untitled Folder",
        items: [LaunchItem] = []
    ) {
        self.id = id
        self.name = name
        self.items = items
    }
}
