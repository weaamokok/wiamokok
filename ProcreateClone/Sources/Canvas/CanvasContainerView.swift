import SwiftUI

/// SwiftUI wrapper that hosts the UIKit CanvasViewController.
struct CanvasContainerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CanvasViewController {
        let vc = CanvasViewController()
        vc.onDismiss = { [weak vc] in vc?.dismiss(animated: true) }
        return vc
    }

    func updateUIViewController(_ uiViewController: CanvasViewController, context: Context) {}
}
