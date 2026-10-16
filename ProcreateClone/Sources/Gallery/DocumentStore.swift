import Metal
import UIKit

/// Reads and writes per-layer PNG files to ApplicationSupport.
/// SwiftData handles model persistence; this handles the raw pixel data.
@MainActor
final class DocumentStore {
    static let shared = DocumentStore()
    private init() {}

    // MARK: - Save

    func save(document: DrawingDocument, layers: [CanvasLayer], thumbnail: UIImage?) {
        let dir = document.directoryURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        document.layerCount = layers.count
        document.modifiedAt = Date()
        if let thumb = thumbnail {
            document.thumbnailData = thumb.jpegData(compressionQuality: 0.72)
        }
        for (i, layer) in layers.enumerated() {
            if let data = layer.pngData() {
                try? data.write(to: dir.appending(path: "layer_\(i).png"), options: .atomic)
            }
        }
    }

    // MARK: - Load

    func loadTextures(for document: DrawingDocument,
                      device: MTLDevice,
                      width: Int, height: Int) -> [MTLTexture]? {
        var result: [MTLTexture] = []
        for i in 0..<document.layerCount {
            let url = document.directoryURL.appending(path: "layer_\(i).png")
            guard let data  = try? Data(contentsOf: url),
                  let image = UIImage(data: data),
                  let tex   = makeTexture(from: image, device: device, w: width, h: height)
            else { return nil }
            result.append(tex)
        }
        return result.isEmpty ? nil : result
    }

    // MARK: - Delete

    func delete(document: DrawingDocument) {
        try? FileManager.default.removeItem(at: document.directoryURL)
    }

    // MARK: - Private helpers

    private func makeTexture(from image: UIImage, device: MTLDevice, w: Int, h: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        guard let tex = device.makeTexture(descriptor: desc) else { return nil }

        guard let cgImg = image.cgImage,
              let ctx   = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return nil }
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let ptr = ctx.data else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h),
                    mipmapLevel: 0, withBytes: ptr, bytesPerRow: w * 4)
        return tex
    }
}
