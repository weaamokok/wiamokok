import UIKit
import SwiftUI

final class CanvasViewController: UIViewController {

    var onDismiss: (() -> Void)?

    private var metalCanvas: MetalCanvasView!
    private var toolbar: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupMetalCanvas()
        setupToolbar()
    }

    private func setupMetalCanvas() {
        metalCanvas = MetalCanvasView(frame: .zero)
        metalCanvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalCanvas)

        NSLayoutConstraint.activate([
            metalCanvas.topAnchor.constraint(equalTo: view.topAnchor),
            metalCanvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalCanvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalCanvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupToolbar() {
        toolbar = UIView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        toolbar.layer.cornerRadius = 16
        toolbar.layer.shadowColor = UIColor.black.cgColor
        toolbar.layer.shadowOpacity = 0.15
        toolbar.layer.shadowRadius = 8
        view.addSubview(toolbar)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let undoButton = UIButton(type: .system)
        undoButton.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal)
        undoButton.tintColor = .label
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)

        let clearButton = UIButton(type: .system)
        clearButton.setImage(UIImage(systemName: "trash"), for: .normal)
        clearButton.tintColor = .systemRed
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [closeButton, undoButton, clearButton])
        stack.axis = .horizontal
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stack)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            toolbar.heightAnchor.constraint(equalToConstant: 52),

            stack.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
        ])

        // Two-finger tap = undo
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(undoTapped))
        twoFingerTap.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerTap)
    }

    @objc private func closeTapped() {
        onDismiss?()
    }

    @objc private func undoTapped() {
        metalCanvas.undo()
    }

    @objc private func clearTapped() {
        metalCanvas.clearCanvas()
    }
}
