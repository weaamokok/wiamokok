import simd

/// One "stamp" of the brush — a single disc drawn at a point along the stroke.
struct BrushStamp {
    let x: Float       // canvas pixels
    let y: Float
    let size: Float    // diameter in canvas pixels
    let opacity: Float // 0–1
    let r: Float       // brush colour
    let g: Float
    let b: Float
}

/// Uniform block matching the layout expected by Shaders.metal.
struct BrushUniforms {
    var position: SIMD2<Float>
    var size: Float
    var opacity: Float
    var color: SIMD4<Float>
    var ndcScale: SIMD2<Float>  // 2 / drawableWidth,  2 / drawableHeight
}

extension BrushStamp {
    func uniforms(drawableSize: CGSize, scale: Float) -> BrushUniforms {
        // Convert UIKit points → Metal NDC (origin bottom-left in Metal, top-left in UIKit)
        let ndcX = (x * scale / Float(drawableSize.width))  * 2 - 1
        let ndcY = 1 - (y * scale / Float(drawableSize.height)) * 2
        return BrushUniforms(
            position: SIMD2(ndcX, ndcY),
            size: size * scale / Float(drawableSize.width) * 2,   // NDC half-width
            opacity: opacity,
            color: SIMD4(r, g, b, opacity),
            ndcScale: SIMD2(
                2 / Float(drawableSize.width),
                2 / Float(drawableSize.height)
            )
        )
    }
}
