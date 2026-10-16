import Metal
import UIKit

final class CanvasLayer {
    let id: UUID
    var name: String
    var texture: MTLTexture
    var isVisible: Bool = true
    var opacity: Float = 1.0   // 0–1, applied during compositing

    init(id: UUID = UUID(), name: String, texture: MTLTexture) {
        self.id   = id
        self.name = name
        self.texture = texture
    }

    /// Full-resolution PNG of this layer's texture (for disk persistence).
    func pngData() -> Data? {
        thumbnail(size: CGSize(width: texture.width, height: texture.height))
            .flatMap { $0.pngData() }
    }

    /// Render this layer's texture into a UIImage for panel thumbnails.
    /// Runs synchronously — call off the main thread or keep textures small.
    func thumbnail(size: CGSize) -> UIImage? {
        let w = texture.width, h = texture.height
        guard w > 0, h > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow   = w * bytesPerPixel
        var bytes         = [UInt8](repeating: 0, count: h * bytesPerRow)

        // Shared-storage copy so CPU can read it
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat, width: w, height: h, mipmapped: false
        )
        desc.storageMode = .shared
        guard let shared = texture.device.makeTexture(descriptor: desc),
              let queue  = texture.device.makeCommandQueue(),
              let cmd    = queue.makeCommandBuffer(),
              let blit   = cmd.makeBlitCommandEncoder()
        else { return nil }

        blit.copy(from: texture, to: shared)
        blit.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()

        shared.getBytes(&bytes, bytesPerRow: bytesPerRow,
                        from: MTLRegion(origin: .init(x: 0, y: 0, z: 0),
                                        size: .init(width: w, height: h, depth: 1)),
                        mipmapLevel: 0)

        guard let ctx = CGContext(
            data: &bytes,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let cgImg = ctx.makeImage() else { return nil }

        return UIImage(cgImage: cgImg)
    }
}
