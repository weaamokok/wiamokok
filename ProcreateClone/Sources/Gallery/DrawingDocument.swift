import SwiftData
import Foundation

@Model
final class DrawingDocument {
    var id: UUID = UUID()
    var title: String = "Untitled"
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var layerCount: Int = 1
    @Attribute(.externalStorage) var thumbnailData: Data?

    init(title: String = "Untitled") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.layerCount = 1
    }

    var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "wia-draw/\(id.uuidString)", directoryHint: .isDirectory)
    }
}
