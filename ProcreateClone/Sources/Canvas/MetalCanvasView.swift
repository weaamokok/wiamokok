import MetalKit
import UIKit

/// GPU-accelerated drawing surface.
/// Two render pipelines:
///   • blitPipeline   – composites the persistent canvas texture to the screen.
///   • stampPipeline  – draws individual brush stamps on top (alpha-blended).
final class MetalCanvasView: MTKView {

    // MARK: - Metal objects

    private var commandQueue: MTLCommandQueue!
    private var blitPipeline: MTLRenderPipelineState!
    private var stampPipeline: MTLRenderPipelineState!

    /// Persistent canvas (all committed strokes live here).
    private var canvasTexture: MTLTexture?

    // MARK: - App objects

    private var brushEngine: BrushEngine!
    private var inputHandler: TouchInputHandler!
    private var undoStack: [MTLTexture] = []

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

        brushEngine  = BrushEngine(device: gpu)
        inputHandler = TouchInputHandler()

        inputHandler.onStrokeUpdate = { [weak self] points in
            self?.brushEngine.addPoints(points)
        }
        inputHandler.onStrokeEnd = { [weak self] in
            self?.commitCurrentStroke()
        }
    }

    // MARK: - Pipeline construction

    private func buildPipelines(gpu: MTLDevice) {
        guard let lib = gpu.makeDefaultLibrary() else {
            fatalError("Metal default library not found — ensure Shaders.metal is in the target.")
        }

        // ── Blit pipeline (canvas texture → screen) ─────────────────────────
        let blitDesc = MTLRenderPipelineDescriptor()
        blitDesc.vertexFunction   = lib.makeFunction(name: "blitVertexShader")
        blitDesc.fragmentFunction = lib.makeFunction(name: "blitFragmentShader")
        blitDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        // No blending needed — canvas is opaque background
        blitPipeline = try! gpu.makeRenderPipelineState(descriptor: blitDesc)

        // ── Stamp pipeline (brush discs → screen, alpha-blended) ─────────────
        let stampDesc = MTLRenderPipelineDescriptor()
        stampDesc.vertexFunction   = lib.makeFunction(name: "stampVertexShader")
        stampDesc.fragmentFunction = lib.makeFunction(name: "stampFragmentShader")
        stampDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        stampDesc.colorAttachments[0].isBlendingEnabled = true
        // Pre-multiplied alpha blending
        stampDesc.colorAttachments[0].sourceRGBBlendFactor        = .one
        stampDesc.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        stampDesc.colorAttachments[0].sourceAlphaBlendFactor      = .one
        stampDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        stampPipeline = try! gpu.makeRenderPipelineState(descriptor: stampDesc)
    }

    // MARK: - Canvas texture lifecycle

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        let w = Int(bounds.width  * contentScaleFactor)
        let h = Int(bounds.height * contentScaleFactor)
        if canvasTexture == nil || canvasTexture!.width != w || canvasTexture!.height != h {
            let old = canvasTexture
            canvasTexture = makeBlanкTexture(width: w, height: h)
            // If we had a canvas, copy what fits (resize keeps existing art).
            if let src = old {
                blitTexture(src: src, dst: canvasTexture!)
            }
        }
    }

    private func makeBlanкTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        let tex = device!.makeTexture(descriptor: desc)!
        // Fill with white
        guard let cmd = commandQueue.makeCommandBuffer() else { return tex }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = tex
        pass.colorAttachments[0].loadAction  = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor  = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        cmd.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        cmd.commit()
        return tex
    }

    // MARK: - MTKView render loop

    override func draw(_ rect: CGRect) {
        guard
            let canvas   = canvasTexture,
            let drawable = currentDrawable,
            let passDesc = currentRenderPassDescriptor,
            let cmdBuf   = commandQueue.makeCommandBuffer()
        else { return }

        passDesc.colorAttachments[0].clearColor  = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        passDesc.colorAttachments[0].loadAction  = .clear
        passDesc.colorAttachments[0].storeAction = .store

        guard let enc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else { return }

        // 1. Blit committed canvas
        enc.setRenderPipelineState(blitPipeline)
        var quad: [Float] = [
            -1,  1, 0, 0,
             1,  1, 1, 0,
            -1, -1, 0, 1,
             1, -1, 1, 1,
        ]
        enc.setVertexBytes(&quad, length: quad.count * MemoryLayout<Float>.stride, index: 0)
        enc.setFragmentTexture(canvas, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        // 2. Draw in-progress stroke stamps on top
        let stamps = brushEngine.currentStrokeStamps
        if !stamps.isEmpty {
            enc.setRenderPipelineState(stampPipeline)
            let dSize = CGSize(width: drawableSize.width, height: drawableSize.height)
            let scale = Float(contentScaleFactor)
            for stamp in stamps {
                var u = stamp.uniforms(drawableSize: dSize, scale: scale)
                enc.setVertexBytes(&u,   length: MemoryLayout<BrushUniforms>.stride, index: 0)
                enc.setFragmentBytes(&u, length: MemoryLayout<BrushUniforms>.stride, index: 0)
                enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }

        enc.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    // MARK: - Stroke commit

    private func commitCurrentStroke() {
        let stamps = brushEngine.currentStrokeStamps
        guard !stamps.isEmpty, let canvas = canvasTexture else {
            brushEngine.clearCurrentStroke()
            return
        }

        // Save undo snapshot
        if let snap = copyTexture(canvas) {
            undoStack.append(snap)
            if undoStack.count > 100 { undoStack.removeFirst() }
        }

        // Render stamps permanently onto canvasTexture
        guard let cmdBuf = commandQueue.makeCommandBuffer() else { return }
        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture     = canvas
        passDesc.colorAttachments[0].loadAction  = .load
        passDesc.colorAttachments[0].storeAction = .store

        if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) {
            enc.setRenderPipelineState(stampPipeline)
            let dSize = CGSize(width: canvas.width, height: canvas.height)
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

    // MARK: - Utilities

    private func copyTexture(_ src: MTLTexture) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: src.pixelFormat, width: src.width, height: src.height, mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        guard let dst = device?.makeTexture(descriptor: desc),
              let cmd = commandQueue.makeCommandBuffer()
        else { return nil }
        blitTexture(src: src, dst: dst, commandBuffer: cmd)
        cmd.commit()
        return dst
    }

    private func blitTexture(src: MTLTexture, dst: MTLTexture, commandBuffer: MTLCommandBuffer? = nil) {
        let cmd = commandBuffer ?? commandQueue.makeCommandBuffer()!
        guard let enc = cmd.makeBlitCommandEncoder() else { return }
        let w = min(src.width,  dst.width)
        let h = min(src.height, dst.height)
        enc.copy(from: src, sourceSlice: 0, sourceLevel: 0,
                 sourceOrigin: .init(x: 0, y: 0, z: 0),
                 sourceSize: .init(width: w, height: h, depth: 1),
                 to: dst, destinationSlice: 0, destinationLevel: 0,
                 destinationOrigin: .init(x: 0, y: 0, z: 0))
        enc.endEncoding()
        if commandBuffer == nil { cmd.commit() }
    }

    // MARK: - Public API

    func setBrushColor(_ color: UIColor) { brushEngine.brushColor = color }
    func setBrushSize(_ size: Float)     { brushEngine.brushSize  = size  }
    func setBrushOpacity(_ opacity: Float) { brushEngine.brushOpacity = opacity }

    func undo() {
        guard let snap = undoStack.popLast(), let canvas = canvasTexture else { return }
        blitTexture(src: snap, dst: canvas)
        brushEngine.clearCurrentStroke()
    }

    func clearCanvas() {
        guard let canvas = canvasTexture else { return }
        if let snap = copyTexture(canvas) { undoStack.append(snap) }
        guard let cmd = commandQueue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = canvas
        pass.colorAttachments[0].loadAction  = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor  = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        cmd.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        cmd.commit()
        brushEngine.clearCurrentStroke()
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
