import Metal

/// Ordered list of canvas layers with an active-layer pointer.
/// MetalCanvasView owns one LayerStack and queries it each render frame.
@MainActor
final class LayerStack: ObservableObject {

    @Published private(set) var layers: [CanvasLayer] = []
    @Published private(set) var activeIndex: Int = 0

    private let device: MTLDevice
    private var textureWidth:  Int = 0
    private var textureHeight: Int = 0

    var activeLayer: CanvasLayer? { layers.indices.contains(activeIndex) ? layers[activeIndex] : nil }
    var count: Int { layers.count }

    init(device: MTLDevice) {
        self.device = device
    }

    // MARK: - Texture size

    func setCanvasSize(width: Int, height: Int) {
        guard width != textureWidth || height != textureHeight else { return }
        textureWidth  = width
        textureHeight = height
        // Resize all existing layer textures (create new, blit old content)
        for (i, layer) in layers.enumerated() {
            let newTex = makeTexture(transparent: true)
            blitInto(dst: newTex, src: layer.texture)
            layers[i].texture = newTex
        }
        // Seed first layer as white background if stack is empty
        if layers.isEmpty { addLayer(name: "Background") }
    }

    // MARK: - Layer operations

    func addLayer(name: String? = nil) {
        let idx   = layers.count + 1
        let label = name ?? "Layer \(idx)"
        let tex   = makeTexture(transparent: layers.count > 0)
        if layers.isEmpty {
            // Background is opaque white
            clearToWhite(tex)
        }
        let layer = CanvasLayer(name: label, texture: tex)
        layers.append(layer)
        activeIndex = layers.count - 1
    }

    func deleteLayer(at index: Int) {
        guard layers.count > 1, layers.indices.contains(index) else { return }
        layers.remove(at: index)
        activeIndex = Swift.min(activeIndex, layers.count - 1)
    }

    func toggleVisibility(at index: Int) {
        guard layers.indices.contains(index) else { return }
        layers[index].isVisible.toggle()
    }

    func setOpacity(_ opacity: Float, at index: Int) {
        guard layers.indices.contains(index) else { return }
        layers[index].opacity = opacity
    }

    func setBlendMode(_ mode: LayerBlendMode, at index: Int) {
        guard layers.indices.contains(index) else { return }
        layers[index].blendMode = mode
    }

    func setActive(_ index: Int) {
        guard layers.indices.contains(index) else { return }
        activeIndex = index
    }

    /// Replace all layers with the given textures (used when loading a saved document).
    func replaceAll(textures: [MTLTexture], names: [String]) {
        guard !textures.isEmpty else { return }
        layers = zip(textures, names).map { tex, name in CanvasLayer(name: name, texture: tex) }
        activeIndex = 0
    }

    func move(from source: IndexSet, to destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
        // Re-locate active layer after move
        if let moved = source.first {
            if moved == activeIndex {
                activeIndex = destination > moved ? destination - 1 : destination
            }
        }
    }

    // MARK: - Texture helpers

    func makeTexture(transparent: Bool) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width:  textureWidth,
            height: textureHeight,
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        let tex = device.makeTexture(descriptor: desc)!
        if transparent { clearToTransparent(tex) } else { clearToWhite(tex) }
        return tex
    }

    private func clearToTransparent(_ tex: MTLTexture) {
        clearTexture(tex, color: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0))
    }

    private func clearToWhite(_ tex: MTLTexture) {
        clearTexture(tex, color: MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1))
    }

    private func clearTexture(_ tex: MTLTexture, color: MTLClearColor) {
        guard let queue = device.makeCommandQueue(),
              let cmd   = queue.makeCommandBuffer()
        else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = tex
        pass.colorAttachments[0].loadAction  = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor  = color
        cmd.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        cmd.commit()
    }

    private func blitInto(dst: MTLTexture, src: MTLTexture) {
        guard let queue = device.makeCommandQueue(),
              let cmd   = queue.makeCommandBuffer(),
              let blit  = cmd.makeBlitCommandEncoder()
        else { return }
        let w = Swift.min(src.width,  dst.width)
        let h = Swift.min(src.height, dst.height)
        blit.copy(from: src, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: .init(x: 0, y: 0, z: 0),
                  sourceSize: .init(width: w, height: h, depth: 1),
                  to: dst, destinationSlice: 0, destinationLevel: 0,
                  destinationOrigin: .init(x: 0, y: 0, z: 0))
        blit.endEncoding()
        cmd.commit()
    }
}
