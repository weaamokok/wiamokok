import Metal
import UIKit

/// Converts incoming TouchPoints into BrushStamp arrays for the renderer.
final class BrushEngine {

    private(set) var currentStrokeStamps: [BrushStamp] = []

    // Public settings — written by the toolbar / tool picker, read each stroke
    var activeTool: DrawingTool = .brush
    var brushColor: UIColor = .black
    var brushSize: Float = 20        // points diameter
    var brushOpacity: Float = 0.85
    var spacing: Float = 0.22        // fraction of brush diameter between stamps

    private var lastPoint: TouchPoint?

    init(device: MTLDevice) {}

    func addPoints(_ points: [TouchPoint]) {
        for point in points {
            if let last = lastPoint {
                interpolateStamps(from: last, to: point)
            } else {
                placeStamp(at: point)
            }
            lastPoint = point
        }
    }

    func clearCurrentStroke() {
        currentStrokeStamps.removeAll(keepingCapacity: true)
        lastPoint = nil
    }

    // MARK: - Stamp placement

    private func placeStamp(at point: TouchPoint) {
        let (r, g, b) = rgb(from: brushColor)
        // Pressure scales the per-stamp size within ±40% of base size
        let stampSize = brushSize * (0.6 + point.pressure * 0.8)
        let stamp = BrushStamp(
            x: point.x,
            y: point.y,
            size: stampSize,
            opacity: brushOpacity * Double(point.pressure + 0.2).clamped(to: 0.1...1.0),
            r: r, g: g, b: b,
            azimuth: point.azimuth,
            altitude: point.altitude
        )
        currentStrokeStamps.append(stamp)
    }

    private func interpolateStamps(from a: TouchPoint, to b: TouchPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dist = sqrt(dx * dx + dy * dy)
        let avgSize = brushSize * (0.6 + (a.pressure + b.pressure) / 2 * 0.8)
        let step = max(avgSize * spacing, 1)
        guard dist > 0 else { return }

        let steps = max(Int(dist / step), 1)
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            let pt = TouchPoint(
                x: a.x + dx * t,
                y: a.y + dy * t,
                pressure: a.pressure + (b.pressure - a.pressure) * t,
                size: a.size + (b.size - a.size) * t,
                azimuth: a.azimuth + (b.azimuth - a.azimuth) * t,
                altitude: a.altitude + (b.altitude - a.altitude) * t
            )
            placeStamp(at: pt)
        }
    }

    // MARK: - Helpers

    private func rgb(from color: UIColor) -> (Float, Float, Float) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Float {
        Float(Swift.min(Swift.max(self, range.lowerBound), range.upperBound))
    }
}
