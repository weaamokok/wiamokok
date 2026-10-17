import Metal
import UIKit

/// Converts incoming TouchPoints into BrushStamp arrays for the renderer.
final class BrushEngine {

    private(set) var currentStrokeStamps: [BrushStamp] = []

    // Public settings — written by toolbar / studio sheet, read each stroke
    var activeTool: DrawingTool = .brush
    var brushColor: UIColor = .black
    var brushSize: Float = 20        // points diameter
    var brushOpacity: Float = 0.85
    var activePreset: BrushPreset = .round {
        didSet {
            spacing = activePreset.spacing
            softness = activePreset.softness
        }
    }
    var spacing: Float = BrushPreset.round.spacing
    var softness: Float = BrushPreset.round.softness

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

    /// Produce speculative stamps for predicted points without mutating stroke state.
    func previewStamps(for points: [TouchPoint]) -> [BrushStamp] {
        guard let anchor = lastPoint ?? points.first else { return [] }
        var result: [BrushStamp] = []
        var prev = anchor
        for point in points {
            result.append(contentsOf: stamps(from: prev, to: point))
            prev = point
        }
        return result
    }

    // MARK: - Stamp placement

    private func placeStamp(at point: TouchPoint) {
        currentStrokeStamps.append(contentsOf: stamp(at: point))
    }

    private func interpolateStamps(from a: TouchPoint, to b: TouchPoint) {
        currentStrokeStamps.append(contentsOf: stamps(from: a, to: b))
    }

    // MARK: - Pure stamp generation (no mutation)

    private func stamp(at point: TouchPoint) -> [BrushStamp] {
        let (r, g, b) = rgb(from: brushColor)
        let preset = activePreset
        let basePressureSize = brushSize * (0.6 + point.pressure * 0.8)
        let jitterScale = preset.sizeJitter > 0
            ? 1.0 + Float.random(in: -preset.sizeJitter...preset.sizeJitter)
            : 1.0
        let stampSize = basePressureSize * jitterScale

        let baseOpacity = brushOpacity * Double(point.pressure + 0.2).clamped(to: 0.1...1.0)
        let opacityShift = preset.opacityJitter > 0
            ? Float.random(in: -preset.opacityJitter...preset.opacityJitter)
            : 0
        let stampOpacity = (baseOpacity + opacityShift).clamped(to: 0.03...1.0)

        return [BrushStamp(
            x: point.x, y: point.y,
            size: stampSize, opacity: stampOpacity,
            r: r, g: g, b: b,
            azimuth: point.azimuth, altitude: point.altitude,
            softness: softness
        )]
    }

    private func stamps(from a: TouchPoint, to b: TouchPoint) -> [BrushStamp] {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dist = sqrt(dx * dx + dy * dy)
        let avgSize = brushSize * (0.6 + (a.pressure + b.pressure) / 2 * 0.8)
        let step = max(avgSize * spacing, 1)
        guard dist > 0 else { return [] }

        let steps = max(Int(dist / step), 1)
        return (1...steps).flatMap { i -> [BrushStamp] in
            let t = Float(i) / Float(steps)
            let pt = TouchPoint(
                x: a.x + dx * t,
                y: a.y + dy * t,
                pressure: a.pressure + (b.pressure - a.pressure) * t,
                size: a.size + (b.size - a.size) * t,
                azimuth: a.azimuth + (b.azimuth - a.azimuth) * t,
                altitude: a.altitude + (b.altitude - a.altitude) * t
            )
            return stamp(at: pt)
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

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
