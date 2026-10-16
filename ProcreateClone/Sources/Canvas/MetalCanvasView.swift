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
    private var blitPipeline:       MTLRenderPipelineState!
    private var stampPipeline:      MTLRenderPipelineState!
    private var erasePipeline:      MTLRenderPipelineState!
    private var smudgePipeline:     MTLRenderPipelineState!
    private var selExtractPipeline: MTLRenderPipelineState!  // lasso extract
    private var selClearPipeline:   MTLRenderPipelineState!  // lasso clear

    private var compositeTexture: MTLTexture?
    private var smudgePickupTexture: MTLTexture?

    // MARK: - App objects

    private(set) var layerStack: LayerStack!
    private(set) var history: HistoryManager!
    private var brushEngine: BrushEngine!
    private var inputHandler: TouchInputHandler!
    private(set) var selectionState = SelectionState()

    // MARK: - Lasso input state

    private var lassoPoints: [CGPoint] = []
    private let lassoShapeLayer = CAShapeLayer()

    /// Fired once after the canvas first gets a valid size (width, height in pixels).
    var onCanvasSized: ((Int, Int) -> Void)?
    private var hasFiredSized = false
    /// Fired after each stroke is committed to a layer texture.
    var onStrokeCommitted: (() -> Void)?

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
        inputHandler.onStrokeBegin  = { [weak self] in self?.handleStrokeBegin() }
        inputHandler.onStrokeUpdate = { [weak self] pts in self?.brushEngine.addPoints(pts) }
        inputHandler.onStrokeEnd    = { [weak self] in self?.commitCurrentStroke() }

        setupLassoLayer()
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

        // Erase pipeline — cuts alpha from destination
        let eraseDesc = MTLRenderPipelineDescriptor()
        eraseDesc.vertexFunction   = lib.makeFunction(name: "stampVertexShader")
        eraseDesc.fragmentFunction = lib.makeFunction(name: "eraseFragmentShader")
        eraseDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        eraseDesc.colorAttachments[0].isBlendingEnabled = true
        eraseDesc.colorAttachments[0].sourceRGBBlendFactor        = .zero
        eraseDesc.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        eraseDesc.colorAttachments[0].sourceAlphaBlendFactor      = .zero
        eraseDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        erasePipeline = try! gpu.makeRenderPipelineState(descriptor: eraseDesc)

        // Smudge pipeline — pre-multiplied alpha (same blend, different fragment)
        let smudgeDesc = MTLRenderPipelineDescriptor()
        smudgeDesc.vertexFunction   = lib.makeFunction(name: "stampVertexShader")
        smudgeDesc.fragmentFunction = lib.makeFunction(name: "smudgeFragmentShader")
        smudgeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        smudgeDesc.colorAttachments[0].isBlendingEnabled = true
        smudgeDesc.colorAttachments[0].sourceRGBBlendFactor        = .one
        smudgeDesc.colorAttachments[0].destinationRGBBlendFactor   = .oneMinusSourceAlpha
        smudgeDesc.colorAttachments[0].sourceAlphaBlendFactor      = .one
        smudgeDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        smudgePipeline = try! gpu.makeRenderPipelineState(descriptor: smudgeDesc)

        // Selection extract — direct write (no blending)
        let selExtDesc = MTLRenderPipelineDescriptor()
        selExtDesc.vertexFunction   = lib.makeFunction(name: "blitVertexShader")
        selExtDesc.fragmentFunction = lib.makeFunction(name: "selectionExtractFragmentShader")
        selExtDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        selExtDesc.colorAttachments[0].isBlendingEnabled = false
        selExtractPipeline = try! gpu.makeRenderPipelineState(descriptor: selExtDesc)

        // Selection clear — direct write (no blending)
        let selClrDesc = MTLRenderPipelineDescriptor()
        selClrDesc.vertexFunction   = lib.makeFunction(name: "blitVertexShader")
        selClrDesc.fragmentFunction = lib.makeFunction(name: "selectionClearFragmentShader")
        selClrDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        selClrDesc.colorAttachments[0].isBlendingEnabled = false
        selClearPipeline = try! gpu.makeRenderPipelineState(descriptor: selClrDesc)
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
            if !self.hasFiredSized {
                self.hasFiredSized = true
                self.onCanvasSized?(w, h)
            }
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

        let layers   = layerStack.layers
        let activeI  = layerStack.activeIndex
        let stamps   = brushEngine.currentStrokeStamps
        let activeTool = brushEngine.activeTool
        let dSize    = CGSize(width: self.drawableSize.width, height: self.drawableSize.height)
        let scale    = Float(contentScaleFactor)

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
                    let pipeline: MTLRenderPipelineState
                    switch activeTool {
                    case .eraser: pipeline = erasePipeline
                    case .smudge: pipeline = smudgePipeline
                    default:      pipeline = stampPipeline
                    }
                    enc.setRenderPipelineState(pipeline)
                    if activeTool == .smudge, let pickup = smudgePickupTexture {
                        enc.setFragmentTexture(pickup, index: 0)
                    }
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

        // ── Pass 2b: Blit floating selection content onto composite ─────────
        if selectionState.isActive, let content = selectionState.contentTexture {
            let selPass = MTLRenderPassDescriptor()
            selPass.colorAttachments[0].texture     = composite
            selPass.colorAttachments[0].loadAction  = .load
            selPass.colorAttachments[0].storeAction = .store

            if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: selPass) {
                enc.setRenderPipelineState(blitPipeline)
                var selQuad = selectionQuadNDC(viewSize: CGSize(width: drawableSize.width, height: drawableSize.height))
                enc.setVertexBytes(&selQuad, length: selQuad.count * MemoryLayout<Float>.stride, index: 0)
                enc.setFragmentTexture(content, index: 0)
                var opacity: Float = 1.0
                enc.setFragmentBytes(&opacity, length: MemoryLayout<Float>.stride, index: 1)
                enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                enc.endEncoding()
            }
        }

        // ── Pass 3: Blit compositeTexture to the drawable ────────────────────
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

    // MARK: - Stroke begin / commit

    private func handleStrokeBegin() {
        // For smudge: snapshot the active layer so the shader can sample it
        guard brushEngine.activeTool == .smudge,
              let layer = layerStack.activeLayer else {
            smudgePickupTexture = nil
            return
        }
        smudgePickupTexture = copyTexture(layer.texture)
    }

    private func commitCurrentStroke() {
        let stamps = brushEngine.currentStrokeStamps
        guard !stamps.isEmpty, let layer = layerStack.activeLayer else {
            brushEngine.clearCurrentStroke()
            smudgePickupTexture = nil
            return
        }

        history.record(layerIndex: layerStack.activeIndex, currentTexture: layer.texture)

        guard let cmdBuf = commandQueue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = layer.texture
        pass.colorAttachments[0].loadAction  = .load
        pass.colorAttachments[0].storeAction = .store

        let activeTool = brushEngine.activeTool
        let pipeline: MTLRenderPipelineState
        switch activeTool {
        case .eraser: pipeline = erasePipeline
        case .smudge: pipeline = smudgePipeline
        default:      pipeline = stampPipeline
        }

        if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: pass) {
            enc.setRenderPipelineState(pipeline)
            if activeTool == .smudge, let pickup = smudgePickupTexture {
                enc.setFragmentTexture(pickup, index: 0)
            }
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
        smudgePickupTexture = nil
        onStrokeCommitted?()
    }

    private func copyTexture(_ src: MTLTexture) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: src.pixelFormat, width: src.width, height: src.height, mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        guard let dst = device!.makeTexture(descriptor: desc),
              let cmd = commandQueue.makeCommandBuffer(),
              let enc = cmd.makeBlitCommandEncoder()
        else { return nil }
        enc.copy(from: src, to: dst)
        enc.endEncoding()
        cmd.commit()
        return dst
    }

    // MARK: - Public API

    func setBrushColor(_ color: UIColor)    { brushEngine.brushColor   = color   }
    func setBrushSize(_ size: Float)        { brushEngine.brushSize    = size    }
    func setBrushOpacity(_ opacity: Float)  { brushEngine.brushOpacity = opacity }
    func setActiveTool(_ tool: DrawingTool)     { brushEngine.activeTool   = tool    }
    func setActivePreset(_ p: BrushPreset)      { brushEngine.activePreset = p       }
    func setSoftness(_ s: Float)                { brushEngine.softness     = s       }
    func setSpacing(_ s: Float)                 { brushEngine.spacing      = s       }

    /// Renders a flat composite of all visible layers and returns it as a UIImage.
    func renderCompositeImage() -> UIImage? {
        guard let composite = compositeTexture else { return nil }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: composite.width, height: composite.height, mipmapped: false)
        desc.storageMode = .shared
        desc.usage = [.shaderRead]
        guard let shared = device!.makeTexture(descriptor: desc),
              let cmd  = commandQueue.makeCommandBuffer(),
              let blit = cmd.makeBlitCommandEncoder()
        else { return nil }
        blit.copy(from: composite, to: shared)
        blit.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()

        let w = composite.width, h = composite.height
        let bpr = w * 4
        var bytes = [UInt8](repeating: 0, count: h * bpr)
        shared.getBytes(&bytes, bytesPerRow: bpr,
                        from: MTLRegion(origin: .init(x: 0, y: 0, z: 0),
                                        size: .init(width: w, height: h, depth: 1)),
                        mipmapLevel: 0)
        guard let ctx = CGContext(
            data: &bytes, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let cgImg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cgImg, scale: contentScaleFactor, orientation: .up)
    }

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

    // MARK: - Lasso layer setup

    private func setupLassoLayer() {
        lassoShapeLayer.strokeColor = UIColor.white.cgColor
        lassoShapeLayer.fillColor   = UIColor(white: 1, alpha: 0.08).cgColor
        lassoShapeLayer.lineWidth   = 1.5
        lassoShapeLayer.lineDashPattern = [6, 4]
        lassoShapeLayer.isHidden    = true
        layer.addSublayer(lassoShapeLayer)
    }

    private func updateLassoCAPath() {
        guard lassoPoints.count > 1 else { return }
        let p = UIBezierPath()
        p.move(to: lassoPoints[0])
        lassoPoints.dropFirst().forEach { p.addLine(to: $0) }
        lassoShapeLayer.path = p.cgPath
    }

    // MARK: - Touch forwarding

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if brushEngine.activeTool == .lasso {
            guard let t = touches.first else { return }
            lassoPoints = [t.preciseLocation(in: self)]
            lassoShapeLayer.isHidden = false
            updateLassoCAPath()
        } else {
            inputHandler.touchesBegan(touches, with: event, in: self)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if brushEngine.activeTool == .lasso {
            guard let t = touches.first else { return }
            let all = event?.coalescedTouches(for: t) ?? [t]
            all.forEach { lassoPoints.append($0.preciseLocation(in: self)) }
            updateLassoCAPath()
        } else {
            inputHandler.touchesMoved(touches, with: event, in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if brushEngine.activeTool == .lasso {
            lassoShapeLayer.isHidden = true
            if lassoPoints.count > 4 { beginSelection() }
            lassoPoints = []
        } else {
            inputHandler.touchesEnded(touches, with: event, in: self)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if brushEngine.activeTool == .lasso {
            lassoShapeLayer.isHidden = true
            lassoPoints = []
        } else {
            inputHandler.touchesEnded(touches, with: event, in: self)
        }
    }

    // MARK: - Selection operations

    private func beginSelection() {
        guard let activeLayer = layerStack.activeLayer, lassoPoints.count > 4 else { return }
        let texW = activeLayer.texture.width
        let texH = activeLayer.texture.height
        let scale = contentScaleFactor

        // Build closed path in VIEW POINTS
        let path = UIBezierPath()
        path.move(to: lassoPoints[0])
        lassoPoints.dropFirst().forEach { path.addLine(to: $0) }
        path.close()

        let ptBounds = path.bounds
        guard ptBounds.width > 2, ptBounds.height > 2 else { return }

        // Rasterize mask to CPU buffer in PIXEL coordinates
        guard var maskBytes = rasterizeMask(path: path.cgPath,
                                            scale: scale,
                                            width: texW, height: texH)
        else { return }

        // Upload mask as R8 texture
        let maskDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm, width: texW, height: texH, mipmapped: false)
        maskDesc.storageMode = .shared
        maskDesc.usage = [.shaderRead]
        guard let maskTex = device!.makeTexture(descriptor: maskDesc) else { return }
        maskTex.replace(region: MTLRegionMake2D(0, 0, texW, texH),
                        mipmapLevel: 0, withBytes: &maskBytes, bytesPerRow: texW)

        // Create content texture
        let contentDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: texW, height: texH, mipmapped: false)
        contentDesc.usage = [.renderTarget, .shaderRead]
        contentDesc.storageMode = .private
        guard let contentTex = device!.makeTexture(descriptor: contentDesc) else { return }

        // Snapshot layer before cut (for cancel)
        let snapshot = copyTexture(activeLayer.texture)

        runExtractionPass(src: activeLayer.texture, mask: maskTex, dst: contentTex)
        let isBackground = layerStack.activeIndex == 0
        runClearPass(dst: activeLayer.texture, mask: maskTex, isBackground: isBackground)

        Task { @MainActor in
            self.selectionState.contentTexture = contentTex
            self.selectionState.originalBounds = ptBounds
            self.selectionState.transform      = .identity
            self.selectionState.preCutSnapshot = snapshot
            self.selectionState.isActive       = true
        }
    }

    private func rasterizeMask(path: CGPath, scale: CGFloat, width: Int, height: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: width * height)
        guard let ctx = CGContext(
            data: &bytes, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.addPath(path)
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillPath()
        return bytes
    }

    private func runExtractionPass(src: MTLTexture, mask: MTLTexture, dst: MTLTexture) {
        guard let cmd = commandQueue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = dst
        pass.colorAttachments[0].loadAction  = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor  = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        if let enc = cmd.makeRenderCommandEncoder(descriptor: pass) {
            enc.setRenderPipelineState(selExtractPipeline)
            var quad: [Float] = [-1, 1, 0, 0,  1, 1, 1, 0,  -1, -1, 0, 1,  1, -1, 1, 1]
            enc.setVertexBytes(&quad, length: quad.count * MemoryLayout<Float>.stride, index: 0)
            enc.setFragmentTexture(src,  index: 0)
            enc.setFragmentTexture(mask, index: 1)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
        }
        cmd.commit(); cmd.waitUntilCompleted()
    }

    private func runClearPass(dst: MTLTexture, mask: MTLTexture, isBackground: Bool) {
        guard let cmd = commandQueue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = dst
        pass.colorAttachments[0].loadAction  = .load
        pass.colorAttachments[0].storeAction = .store
        if let enc = cmd.makeRenderCommandEncoder(descriptor: pass) {
            enc.setRenderPipelineState(selClearPipeline)
            var quad: [Float] = [-1, 1, 0, 0,  1, 1, 1, 0,  -1, -1, 0, 1,  1, -1, 1, 1]
            enc.setVertexBytes(&quad, length: quad.count * MemoryLayout<Float>.stride, index: 0)
            enc.setFragmentTexture(mask, index: 0)
            var fill: SIMD4<Float> = isBackground
                ? SIMD4(1, 1, 1, 1)
                : SIMD4(0, 0, 0, 0)
            enc.setFragmentBytes(&fill, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
        }
        cmd.commit(); cmd.waitUntilCompleted()
    }

    func commitSelection() {
        guard selectionState.isActive,
              let content    = selectionState.contentTexture,
              let activeLayer = layerStack.activeLayer
        else { return }
        history.record(layerIndex: layerStack.activeIndex, currentTexture: activeLayer.texture)
        // Blit content at transformed quad onto active layer
        guard let cmd = commandQueue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture     = activeLayer.texture
        pass.colorAttachments[0].loadAction  = .load
        pass.colorAttachments[0].storeAction = .store
        if let enc = cmd.makeRenderCommandEncoder(descriptor: pass) {
            enc.setRenderPipelineState(blitPipeline)
            let texSize = CGSize(width: activeLayer.texture.width, height: activeLayer.texture.height)
            var q = selectionQuadNDC(viewSize: texSize, useContentScaleFactor: false)
            enc.setVertexBytes(&q, length: q.count * MemoryLayout<Float>.stride, index: 0)
            enc.setFragmentTexture(content, index: 0)
            var op: Float = 1
            enc.setFragmentBytes(&op, length: MemoryLayout<Float>.stride, index: 1)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            enc.endEncoding()
        }
        cmd.commit(); cmd.waitUntilCompleted()
        selectionState.reset()
    }

    func cancelSelection() {
        guard selectionState.isActive else { return }
        // Restore layer from pre-cut snapshot
        if let snap = selectionState.preCutSnapshot, let layer = layerStack.activeLayer {
            blit(src: snap, dst: layer.texture)
        }
        selectionState.reset()
    }

    private func blit(src: MTLTexture, dst: MTLTexture) {
        guard let cmd  = commandQueue.makeCommandBuffer(),
              let blit = cmd.makeBlitCommandEncoder()
        else { return }
        blit.copy(from: src, to: dst)
        blit.endEncoding()
        cmd.commit()
    }

    /// Build NDC quad (TL, TR, BL, BR) for the selection at its current transform.
    private func selectionQuadNDC(viewSize: CGSize, useContentScaleFactor: Bool = true) -> [Float] {
        let scale = useContentScaleFactor ? contentScaleFactor : 1
        let b = selectionState.originalBounds
        let t = selectionState.transform
        let corners: [(CGPoint, CGPoint)] = [
            (CGPoint(x: b.minX, y: b.minY).applying(t), CGPoint(x: 0, y: 0)),
            (CGPoint(x: b.maxX, y: b.minY).applying(t), CGPoint(x: 1, y: 0)),
            (CGPoint(x: b.minX, y: b.maxY).applying(t), CGPoint(x: 0, y: 1)),
            (CGPoint(x: b.maxX, y: b.maxY).applying(t), CGPoint(x: 1, y: 1)),
        ]
        return corners.flatMap { (world, uv) -> [Float] in
            let ndcX = Float(world.x * scale / viewSize.width)  * 2 - 1
            let ndcY = 1 - Float(world.y * scale / viewSize.height) * 2
            return [ndcX, ndcY, Float(uv.x), Float(uv.y)]
        }
    }
}
