import UIKit
import SwiftUI

final class CanvasViewController: UIViewController {

    var onDismiss: (() -> Void)?
    var document: DrawingDocument?

    private var metalCanvas: MetalCanvasView!
    private var toolbarHost: UIHostingController<CanvasToolbarView>!

    private var brushColor: Color = .black   { didSet { applyBrushSettings() } }
    private var brushSize: Float  = 20       { didSet { applyBrushSettings() } }
    private var brushOpacity: Float = 0.85  { didSet { applyBrushSettings() } }
    private var activeTool: DrawingTool = .brush { didSet { metalCanvas.setActiveTool(activeTool) } }
    private var activePreset: BrushPreset = .round { didSet { metalCanvas.setActivePreset(activePreset) } }
    private var softness: Float = BrushPreset.round.softness { didSet { metalCanvas.setSoftness(softness) } }
    private var spacing: Float  = BrushPreset.round.spacing  { didSet { metalCanvas.setSpacing(spacing)  } }

    private var autosaveTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupCanvas()
        setupToolbar()
        setupGestures()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autosaveTimer?.invalidate()
        saveDocument()
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

        // Load saved layers once the canvas has a pixel size
        metalCanvas.onCanvasSized = { [weak self] w, h in
            self?.loadDocumentIfNeeded(canvasWidth: w, height: h)
        }
        metalCanvas.onStrokeCommitted = { [weak self] in
            self?.scheduleAutosave()
        }
    }

    private func setupToolbar() {
        let toolbar = CanvasToolbarView(
            brushColor:   Binding(get: { self.brushColor },   set: { self.brushColor   = $0 }),
            brushSize:    Binding(get: { self.brushSize },    set: { self.brushSize    = $0 }),
            brushOpacity: Binding(get: { self.brushOpacity }, set: { self.brushOpacity = $0 }),
            activeTool:   Binding(get: { self.activeTool },   set: { self.activeTool   = $0 }),
            activePreset: Binding(get: { self.activePreset }, set: { self.activePreset = $0 }),
            softness:     Binding(get: { self.softness },     set: { self.softness     = $0 }),
            spacing:      Binding(get: { self.spacing },      set: { self.spacing      = $0 }),
            layerStack:   metalCanvas.layerStack,
            history:      metalCanvas.history,
            onClose:  { [weak self] in self?.onDismiss?() },
            onUndo:   { [weak self] in self?.metalCanvas.undo() },
            onRedo:   { [weak self] in self?.metalCanvas.redo() },
            onClear:  { [weak self] in self?.metalCanvas.clearCanvas() },
            onExport: { [weak self] in self?.exportPNG() }
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
        let twoFinger = UITapGestureRecognizer(target: self, action: #selector(undoGesture))
        twoFinger.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFinger)

        let threeFinger = UITapGestureRecognizer(target: self, action: #selector(redoGesture))
        threeFinger.numberOfTouchesRequired = 3
        view.addGestureRecognizer(threeFinger)

        twoFinger.require(toFail: threeFinger)
    }

    // MARK: - Document load

    private func loadDocumentIfNeeded(canvasWidth w: Int, height h: Int) {
        guard let doc = document,
              let gpu = metalCanvas.device
        else { return }
        let store = DocumentStore.shared
        guard let textures = store.loadTextures(for: doc, device: gpu, width: w, height: h)
        else { return }

        let names = (0..<textures.count).map { i in i == 0 ? "Background" : "Layer \(i)" }
        Task { @MainActor in
            self.metalCanvas.layerStack.replaceAll(textures: textures, names: names)
        }
    }

    // MARK: - Autosave

    func scheduleAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.saveDocument()
        }
    }

    private func saveDocument() {
        guard let doc = document else { return }
        let layers    = metalCanvas.layerStack.layers
        let thumbnail = metalCanvas.renderCompositeImage()
        DocumentStore.shared.save(document: doc, layers: layers, thumbnail: thumbnail)
    }

    // MARK: - Export

    private func exportPNG() {
        guard let image = metalCanvas.renderCompositeImage(),
              let data  = image.pngData()
        else { return }

        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "\(document?.title ?? "drawing").png")
        try? data.write(to: tmp)

        let vc = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        present(vc, animated: true)
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
