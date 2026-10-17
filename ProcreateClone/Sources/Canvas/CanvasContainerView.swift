import SwiftUI

/// SwiftUI wrapper that hosts the UIKit CanvasViewController.
struct CanvasContainerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var document: DrawingDocument

    func makeUIViewController(context: Context) -> CanvasViewController {
        let vc = CanvasViewController()
        vc.document  = document
        vc.onDismiss = { [weak vc] in vc?.dismiss(animated: true) }
        return vc
    }

    func updateUIViewController(_ uiViewController: CanvasViewController, context: Context) {}
}
