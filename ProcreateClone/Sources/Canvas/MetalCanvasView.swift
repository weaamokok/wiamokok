import MetalKit
import UIKit

/// GPU-accelerated drawing surface with multi-layer compositing.
///
/// Render loop each frame:
///   1. Clear composite texture to white.
///   2. For each visible layer (bottom → top): blit layer texture onto composite (alpha-blended, opacity applied).
///      If this is the active layer, draw the in-progress stroke stamps on top before moving on.
///   3. Blit composite to the drawable.
final class MetalCanvasView: MTKView {

    // MARK: - Metal objects

    private var commandQueue: MTLCommandQueue!
    private var blitPipeline:  MTLRenderPipelineState!   // canvas layer → composite
    private var stampPipeline: MTLRenderPipelineState!   // brush stamps → layer/composite

    /// Scratch texture that accumulates all layers before being shown.
    private var compositeTexture: MTLTexture?

    // MARK: - App objects

    private(set) var layerStack: LayerStack!
    private(set) var history: HistoryManager!
    private var brushEngine: BrushEngine!
    private var inputHandler: TouchInputHandler!

    // MARK: - Init

    override init(frame: CGRect, device: MTLDevice?) {
        let gpu = device ?? MTLCreateSystemDefaultDevice()!
        super.init(frame: frame, device: gpu)
        configure(gpu: gpu)
    }

    required init(coder: NSCoder) {
        let gpu = MTLCreateSystemDefaultDevice()!
        super.init(coder: coder)
        configure(gpu: gpu)
    }

    private func configure(gpu: MTLDevice) {
        self.device             = gpu
        self.colorPixelFormat   = .bgra8Unorm
        self.clearColor         = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        self.enableSetNeedsDisplay = false
        self.isPaused           = false
        self.preferredFramesPerSecond = 60
        self.isMultipleTouchEnabled   = true

        commandQueue = gpu.makeCommandQueue()!
        buildPipelines(gpu: gpu)

        layerStack  = LayerStack(device: gpu)
        history     = HistoryManager(device: gpu, commandQueue: commandQueue)
        brushEngine = BrushEngine(device: gpu)

        inputHandler = TouchInputHandler()
        inputHandler.onStrokeUpdate = { [weak self] pts in self?.brushEngine.addPoints(pts) }
        inputHandler.onStrokeEnd    = { [weak self] in self?.commitCurrentStroke() }
    }

    // MARK: - Pipelines

    private func buildPipelines(gpu: MTLDevice) {
        guard let lib = gpu.makeDefaultLibrary() else {
            fatalError("Metal default library not found.")
        }

        // Blit pipeline — alpha-blended so layers composite correctly
        let blitDesc = MTLRenderPipelineDescriptor()
        blitDesc.vertexFunction   = lib.makeFunction(name: "blitVertexShader")
        blitDesc.fragmentFunction = lib.makeFunction(name: "blitFragmentShader")
        blitDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        blitDesc.colorAttachments[0].isBlendingEnabled = true
        blitDesc.colorAttachments[0].sourceRGBBlendFactor        = .sourceAlpha
        blitDesc.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        blitDesc.colorAttachments[0].sourceAlphaBlendFactor      = .sourceAlpha
        blitDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        blitPipeline = try! gpu.makeRenderPipelineState(descriptor: blitDesc)

        // Stamp pipeline — pre-multiplied alpha
        let stampDesc = MTLRenderPipelineDescriptor()
        stampDesc.vertexFunction   = lib.makeFunction(name: "stampVertexShader")
        stampDesc.fragmentFunction = lib.makeFunction(name: "stampFragmentShader")
        stampDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        stampDesc.colorAttachments[0].isBlendingEnabled = true
        stampDesc.colorAttachments[0].sourceRGBBlendFactor        = .one
        stampDesc.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        stampDesc.colorAttachments[0].sourceAlphaBlendFactor      = .one
        stampDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        stampPipeline = try! gpu.makeRenderPipelineState(descriptor: stampDesc)
    }

    // MARK: - Layout / texture init

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let w = Int(bounds.width  * contentScaleFactor)
        let h = Int(bounds.height * contentScaleFactor)
        guard compositeTexture == nil || compositeTexture!.width != w else { return }

        compositeTexture = makePrivateTexture(width: w, height: h)
        Task { @MainActor in
            layerStack.setCanvasSize(width: w, height: h)
        }
    }

    private func makePrivateTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        return device!.makeTexture(descriptor: desc)!
    }

    // MARK: - Render loop

    override func draw(_ rect: CGRect) {
        guard
            let composite = compositeTexture,
            let drawable  = currentDrawable,
            let cmdBuf    = commandQueue.makeCommandBuffer()
        else { return }

        let layers  = layerStack.layers
        let activeI = layerStack.activeIndex
        let stamps  = brushEngine.currentStrokeStamps
        let dSize   = CGSize(width: self.drawableSize.width, height: self.drawableSize.height)
        let scale   = Float(contentScaleFactor)

        // ── Pass 1: Composite all layers into compositeTexture ───────────────
        let compPass = MTLRenderPassDescriptor()
        compPass.colorAttachments[0].texture     = composite
        compPass.colorAttachments[0].loadAction  = .clear
        compPass.colorAttachments[0].storeAction = .store
        compPass.colorAttachments[0].clearColor  = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)

        if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: compPass) {
            var quad: [Float] = [-1, 1, 0, 0,  1, 1, 1, 0,  -1, -1, 0, 1,  1, -1, 1, 1]

            for (i, layer) in layers.enumerated() {
                guard layer.isVisible else { continue }

                // Blit this layer's texture
                enc.setRenderPipelineState(blitPipeline)
                enc.setVertexBytes(&quad, length: quad.count * MemoryLayout<Float>.stride, index: 0)
                enc.setFragmentTexture(layer.texture, index: 0)
                var opacity = layer.opacity
                enc.setFragmentBytes(&opacity, length: MemoryLayout<Float>.stride, index: 1)
                enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

                // If active layer, draw in-progress stamps on top
                if i == activeI, !stamps.isEmpty {
                    enc.setRenderPipelineState(stampPipeline)
                    for stamp in stamps {
                        var u = stamp.uniforms(drawableSize: dSize, scale: scale)
                        enc.setVertexBytes(&u,   length: MemoryLayout<BrushUniforms>.stride, index: 0)
                        enc.setFragmentBytes(&u, length: MemoryLayout<BrushUniforms>.stride, index: 0)
                        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                    }
                }
            }
            enc.endEncoding()
        }

        // ── Pass 2: Blit compositeTexture to the drawable ────────────────────
        guard let passDesc = currentRenderPassDescriptor,
              let finalEnc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc)
        else {
            cmdBuf.commit()
            return
        }

        finalEnc.setRenderPipelineState(blitPipeline)
        var quad: [Float] = [-1, 1, 0, 0,  1, 1, 1, 0,  -1, -1, 0, 1,  1, -1, 1, 1]
        finalEnc.setVertexBytes(&quad, length: quad.count * MemoryLayout<Float>.stride, index: 0)
        finalEnc.setFragmentTexture(composite, index: 0)
        var fullOpacity: Float = 1.0
        finalEnc.setFragmentBytes(&fullOpacity, length: MemoryLayout<Float>.stride, index: 1)
        finalEnc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        finalEnc.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    // MARK: - Stroke commit

    private func commitCurrentStroke() {
        let stamps = brushEngine.currentStrokeStamps
        guard !stamps.isEmpty, let layer = layerStack.activeLayer else {
            brushEngine.clearCurrentStroke()
            return
        }

        // Record pre-stroke state for undo (HistoryManager snapshots internally)
        history.record(layerIndex: layerStack.activeIndex, currentTexture: layer.texture)

        // Render stamps onto the active layer texture
        guard let cmdBuf = commandQueue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = layer.texture
        pass.colorAttachments[0].loadAction  = .load
        pass.colorAttachments[0].storeAction = .store

        if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: pass) {
            enc.setRenderPipelineState(stampPipeline)
            let dSize = CGSize(width: layer.texture.width, height: layer.texture.height)
            for stamp in stamps {
                var u = stamp.uniforms(drawableSize: dSize, scale: 1.0)
                enc.setVertexBytes(&u,   length: MemoryLayout<BrushUniforms>.stride, index: 0)
                enc.setFragmentBytes(&u, length: MemoryLayout<BrushUniforms>.stride, index: 0)
                enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            enc.endEncoding()
        }
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        brushEngine.clearCurrentStroke()
    }

    // MARK: - Public API

    func setBrushColor(_ color: UIColor)    { brushEngine.brushColor   = color   }
    func setBrushSize(_ size: Float)        { brushEngine.brushSize    = size    }
    func setBrushOpacity(_ opacity: Float)  { brushEngine.brushOpacity = opacity }

    func undo() {
        brushEngine.clearCurrentStroke()
        history.undo(layers: layerStack.layers)
    }

    func redo() {
        brushEngine.clearCurrentStroke()
        history.redo(layers: layerStack.layers)
    }

    func clearCanvas() {
        guard let layer = layerStack.activeLayer else { return }
        history.record(layerIndex: layerStack.activeIndex, currentTexture: layer.texture)
        clearLayerTexture(layer.texture, isBackground: layerStack.activeIndex == 0)
        brushEngine.clearCurrentStroke()
    }

    private func clearLayerTexture(_ tex: MTLTexture, isBackground: Bool) {
        guard let cmd  = commandQueue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = tex
        pass.colorAttachments[0].loadAction  = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor  = isBackground
            ? MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
            : MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        cmd.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        cmd.commit()
    }

    // MARK: - Touch forwarding

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.touchesBegan(touches, with: event, in: self)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.touchesMoved(touches, with: event, in: self)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.touchesEnded(touches, with: event, in: self)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        inputHandler.touchesEnded(touches, with: event, in: self)
    }
}
