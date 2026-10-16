import simd
import UIKit

/// One "stamp" of the brush — a single disc/ellipse drawn at a point along the stroke.
struct BrushStamp {
    let x: Float        // canvas points
    let y: Float
    let size: Float     // diameter in canvas points
    let opacity: Float  // 0–1
    let r: Float        // brush colour
    let g: Float
    let b: Float
    let azimuth: Float  // radians — pencil tip direction
    let altitude: Float // radians — pencil tilt from surface (π/2 = upright)
}

/// Uniform block matching the layout expected by Shaders.metal.
struct BrushUniforms {
    var position: SIMD2<Float>
    var size: Float
    var opacity: Float
    var color: SIMD4<Float>
    var ndcScale: SIMD2<Float>  // 2 / drawableWidth,  2 / drawableHeight
    var azimuth: Float          // pencil azimuth in radians (0 = right, CCW)
    var altitude: Float         // pencil altitude in radians (π/2 = upright, 0 = flat)
}

extension BrushStamp {
    func uniforms(drawableSize: CGSize, scale: Float) -> BrushUniforms {
        let ndcX = (x * scale / Float(drawableSize.width))  * 2 - 1
        let ndcY = 1 - (y * scale / Float(drawableSize.height)) * 2
        return BrushUniforms(
            position: SIMD2(ndcX, ndcY),
            size: size * scale / Float(drawableSize.width) * 2,
            opacity: opacity,
            color: SIMD4(r, g, b, opacity),
            ndcScale: SIMD2(
                2 / Float(drawableSize.width),
                2 / Float(drawableSize.height)
            ),
            azimuth: azimuth,
            altitude: altitude
        )
    }
}
