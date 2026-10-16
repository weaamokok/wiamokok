import Metal

/// Converts incoming TouchPoints into BrushStamp arrays for the renderer.
/// Sprint 1: simple round brush with pressure → size mapping.
final class BrushEngine {

    private(set) var currentStrokeStamps: [BrushStamp] = []

    // Brush settings (will be exposed to UI in Sprint 8)
    var brushColor: (r: Float, g: Float, b: Float) = (0, 0, 0)
    var baseOpacity: Float = 0.8
    var spacing: Float = 0.2  // fraction of brush size between stamps

    private var lastPoint: TouchPoint?

    init(device: MTLDevice) {}

    /// Append new touch points from the input handler.
    func addPoints(_ points: [TouchPoint]) {
        for point in points {
            if let last = lastPoint {
                interpolateStamps(from: last, to: point)
            } else {
                // First point of stroke
                placeStamp(at: point)
            }
            lastPoint = point
        }
    }

    /// Called when a stroke finishes (finger/pencil lifted).
    func clearCurrentStroke() {
        currentStrokeStamps.removeAll(keepingCapacity: true)
        lastPoint = nil
    }

    // MARK: - Stamp placement

    private func placeStamp(at point: TouchPoint) {
        let stamp = BrushStamp(
            x: point.x,
            y: point.y,
            size: point.size,
            opacity: baseOpacity,
            r: brushColor.r,
            g: brushColor.g,
            b: brushColor.b
        )
        currentStrokeStamps.append(stamp)
    }

    /// Linearly interpolate stamps between two touch points so the stroke looks continuous.
    private func interpolateStamps(from a: TouchPoint, to b: TouchPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dist = sqrt(dx * dx + dy * dy)
        let avgSize = (a.size + b.size) / 2
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
}
