import SwiftUI
import SwiftData

@main
struct ProcreateCloneApp: App {
    var body: some Scene {
        WindowGroup {
            GalleryView()
        }
        .modelContainer(for: DrawingDocument.self)
    }
}
