import UIKit

struct TouchPoint {
    let x: Float
    let y: Float
    let pressure: Float   // 0–1, normalised from UITouch.force / maximumPossibleForce
    let size: Float       // derived from pressure
    let azimuth: Float    // pencil azimuth angle in radians
    let altitude: Float   // pencil altitude (tilt) in radians
}

@MainActor
final class TouchInputHandler {

    var onStrokeBegin: (() -> Void)?
    var onStrokeUpdate: (([TouchPoint]) -> Void)?
    /// Called with predicted (speculative) points; caller should render them
    /// speculatively and discard on the next real update.
    var onStrokePredicted: (([TouchPoint]) -> Void)?
    var onStrokeEnd: (() -> Void)?

    /// Process began touches — start a new stroke.
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touches.first else { return }
        onStrokeBegin?()
        let pts = coalesced(touch: touch, event: event, view: view)
        onStrokeUpdate?(pts)
    }

    /// Process moved touches — extend current stroke.
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touches.first else { return }
        // Deliver real (coalesced) points first
        let real = coalesced(touch: touch, event: event, view: view)
        onStrokeUpdate?(real)
        // Then speculative predicted points so rendering races ahead of the stylus
        if let predicted = event?.predictedTouches(for: touch), !predicted.isEmpty {
            let pts = predicted.map { makeTouchPoint($0, primary: touch, view: view) }
            onStrokePredicted?(pts)
        }
    }

    /// Process ended touches — commit the stroke.
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        onStrokeEnd?()
    }

    // MARK: - Helpers

    private func coalesced(touch: UITouch, event: UIEvent?, view: UIView) -> [TouchPoint] {
        let all = event?.coalescedTouches(for: touch) ?? [touch]
        return all.map { makeTouchPoint($0, primary: touch, view: view) }
    }

    private func makeTouchPoint(_ t: UITouch, primary: UITouch, view: UIView) -> TouchPoint {
        let loc = t.preciseLocation(in: view)
        let pressure = t.type == .pencil
            ? Float(t.force / max(t.maximumPossibleForce, 0.001))
            : Float(0.5)
        let clamped = min(max(pressure, 0.05), 1.0)
        return TouchPoint(
            x: Float(loc.x),
            y: Float(loc.y),
            pressure: clamped,
            size: 4 + clamped * 28,
            azimuth: Float(primary.type == .pencil ? primary.azimuthAngle(in: view) : 0),
            altitude: Float(primary.type == .pencil ? primary.altitudeAngle : .pi / 2)
        )
    }
}
