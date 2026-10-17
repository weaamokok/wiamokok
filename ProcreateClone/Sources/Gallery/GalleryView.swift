import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DrawingDocument.modifiedAt, order: .reverse) private var documents: [DrawingDocument]

    @State private var openDocument: DrawingDocument?

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("Wia Draw")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { newDrawing() } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            .fullScreenCover(item: $openDocument) { doc in
                CanvasContainerView(document: doc)
            }
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("No drawings yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button(action: newDrawing) {
                Label("New Drawing", systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(documents) { doc in
                    DrawingCard(document: doc)
                        .onTapGesture { openDocument = doc }
                        .contextMenu {
                            Button("Rename") { rename(doc) }
                            Button("Delete", role: .destructive) { delete(doc) }
                        }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Actions

    private func newDrawing() {
        let doc = DrawingDocument()
        modelContext.insert(doc)
        openDocument = doc
    }

    private func delete(_ doc: DrawingDocument) {
        DocumentStore.shared.delete(document: doc)
        modelContext.delete(doc)
    }

    private func rename(_ doc: DrawingDocument) {
        // Simple alert-based rename — present via UIKit since SwiftUI alerts with text field are verbose
        let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = doc.title }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let name = alert.textFields?.first?.text, !name.isEmpty {
                doc.title = name
            }
        })
        UIApplication.shared.firstKeyWindow?.rootViewController?.topMost.present(alert, animated: true)
    }
}

// MARK: - Card

private struct DrawingCard: View {
    let document: DrawingDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailView
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            Text(document.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Text(document.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let data = document.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color(.systemGray6)
                Image(systemName: "paintbrush.pointed")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
            }
        }
    }
}

// MARK: - UIKit helpers

private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

private extension UIViewController {
    var topMost: UIViewController {
        presentedViewController.map { $0.topMost } ?? self
    }
}
