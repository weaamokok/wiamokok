import Metal
import Combine

/// One recorded step in the undo/redo history.
struct HistoryEntry {
    let layerIndex: Int
    let snapshot: MTLTexture   // pixel state of that layer BEFORE the stroke
}

/// Observable undo/redo state — toolbar binds to canUndo/canRedo,
/// canvas taps call undo()/redo(), new strokes call recordStroke().
@MainActor
final class HistoryManager: ObservableObject {

    static let maxSteps = 100

    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    /// Human-readable label for the brief toast ("Undo" / "Redo" / nil = none)
    @Published var toastLabel: String? = nil

    private var undoStack: [HistoryEntry] = []
    private var redoStack: [HistoryEntry] = []

    private let device: MTLDevice
    private weak var commandQueue: MTLCommandQueue?

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device       = device
        self.commandQueue = commandQueue
    }

    // MARK: - Record

    /// Call just before committing a stroke. `currentTexture` is the layer's
    /// texture AS IT STANDS NOW (before the new marks land on it).
    func record(layerIndex: Int, currentTexture: MTLTexture) {
        guard let snap = copy(currentTexture) else { return }
        undoStack.append(HistoryEntry(layerIndex: layerIndex, snapshot: snap))
        if undoStack.count > Self.maxSteps { undoStack.removeFirst() }
        redoStack.removeAll()          // new action invalidates redo branch
        refreshPublished()
    }

    // MARK: - Undo

    /// Restores the active layer to its pre-stroke state and saves the
    /// post-stroke state on the redo stack.
    /// Returns the layer index that was restored (so the caller can update
    /// `layerStack.activeIndex` if needed).
    @discardableResult
    func undo(layers: [CanvasLayer]) -> Int? {
        guard let entry = undoStack.popLast() else { return nil }
        guard layers.indices.contains(entry.layerIndex) else {
            refreshPublished()
            return nil
        }
        let layer = layers[entry.layerIndex]

        // Snapshot current state → redo
        if let redoSnap = copy(layer.texture) {
            redoStack.append(HistoryEntry(layerIndex: entry.layerIndex, snapshot: redoSnap))
        }

        // Restore
        blit(src: entry.snapshot, dst: layer.texture)
        refreshPublished()
        showToast("Undo")
        return entry.layerIndex
    }

    /// Restores the layer to its post-stroke state.
    @discardableResult
    func redo(layers: [CanvasLayer]) -> Int? {
        guard let entry = redoStack.popLast() else { return nil }
        guard layers.indices.contains(entry.layerIndex) else {
            refreshPublished()
            return nil
        }
        let layer = layers[entry.layerIndex]

        // Snapshot current state → undo
        if let undoSnap = copy(layer.texture) {
            undoStack.append(HistoryEntry(layerIndex: entry.layerIndex, snapshot: undoSnap))
        }

        blit(src: entry.snapshot, dst: layer.texture)
        refreshPublished()
        showToast("Redo")
        return entry.layerIndex
    }

    // MARK: - Helpers

    private func refreshPublished() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func showToast(_ label: String) {
        toastLabel = label
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if toastLabel == label { toastLabel = nil }
        }
    }

    private func copy(_ src: MTLTexture) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: src.pixelFormat, width: src.width, height: src.height, mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        guard let dst = device.makeTexture(descriptor: desc),
              let cmd = commandQueue?.makeCommandBuffer(),
              let enc = cmd.makeBlitCommandEncoder()
        else { return nil }
        enc.copy(from: src, to: dst)
        enc.endEncoding()
        cmd.commit()
        return dst
    }

    private func blit(src: MTLTexture, dst: MTLTexture) {
        guard let cmd = commandQueue?.makeCommandBuffer(),
              let enc = cmd.makeBlitCommandEncoder()
        else { return }
        enc.copy(from: src, to: dst)
        enc.endEncoding()
        cmd.commit()
    }
}
