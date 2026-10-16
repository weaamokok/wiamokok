import UIKit
import SwiftUI

final class CanvasViewController: UIViewController {

    var onDismiss: (() -> Void)?

    private var metalCanvas: MetalCanvasView!
    private var toolbarHost: UIHostingController<CanvasToolbarView>!

    private var brushColor: Color = .black   { didSet { applyBrushSettings() } }
    private var brushSize: Float  = 20       { didSet { applyBrushSettings() } }
    private var brushOpacity: Float = 0.85  { didSet { applyBrushSettings() } }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupCanvas()
        setupToolbar()
        setupGestures()
    }

    // MARK: - Setup

    private func setupCanvas() {
        metalCanvas = MetalCanvasView(frame: .zero)
        metalCanvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalCanvas)
        NSLayoutConstraint.activate([
            metalCanvas.topAnchor.constraint(equalTo: view.topAnchor),
            metalCanvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalCanvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalCanvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        applyBrushSettings()
    }

    private func setupToolbar() {
        let toolbar = CanvasToolbarView(
            brushColor:   Binding(get: { self.brushColor },   set: { self.brushColor   = $0 }),
            brushSize:    Binding(get: { self.brushSize },    set: { self.brushSize    = $0 }),
            brushOpacity: Binding(get: { self.brushOpacity }, set: { self.brushOpacity = $0 }),
            layerStack:   metalCanvas.layerStack,
            history:      metalCanvas.history,
            onClose: { [weak self] in self?.onDismiss?() },
            onUndo:  { [weak self] in self?.metalCanvas.undo() },
            onRedo:  { [weak self] in self?.metalCanvas.redo() },
            onClear: { [weak self] in self?.metalCanvas.clearCanvas() }
        )

        toolbarHost = UIHostingController(rootView: toolbar)
        toolbarHost.view.backgroundColor = .clear
        toolbarHost.view.translatesAutoresizingMaskIntoConstraints = false
        toolbarHost.view.isUserInteractionEnabled = true

        addChild(toolbarHost)
        view.addSubview(toolbarHost.view)
        toolbarHost.didMove(toParent: self)

        NSLayoutConstraint.activate([
            toolbarHost.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbarHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarHost.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupGestures() {
        // 2-finger tap → undo  (Procreate standard)
        let twoFinger = UITapGestureRecognizer(target: self, action: #selector(undoGesture))
        twoFinger.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFinger)

        // 3-finger tap → redo
        let threeFinger = UITapGestureRecognizer(target: self, action: #selector(redoGesture))
        threeFinger.numberOfTouchesRequired = 3
        view.addGestureRecognizer(threeFinger)

        // Let drawing touches through even when multi-finger gestures are recognised
        twoFinger.require(toFail: threeFinger)
    }

    // MARK: - Brush sync

    private func applyBrushSettings() {
        guard let canvas = metalCanvas else { return }
        canvas.setBrushColor(UIColor(brushColor))
        canvas.setBrushSize(brushSize)
        canvas.setBrushOpacity(brushOpacity)
    }

    // MARK: - Actions

    @objc private func undoGesture() { metalCanvas.undo() }
    @objc private func redoGesture() { metalCanvas.redo() }
}
