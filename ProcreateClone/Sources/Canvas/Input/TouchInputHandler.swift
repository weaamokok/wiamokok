import UIKit

struct TouchPoint {
    let x: Float
    let y: Float
    let pressure: Float   // 0–1, normalised from UITouch.force / maximumPossibleForce
    let size: Float       // derived from pressure
    let azimuth: Float    // pencil azimuth angle in radians
    let altitude: Float   // pencil altitude (tilt) in radians
}

final class TouchInputHandler {

    var onStrokeUpdate: (([TouchPoint]) -> Void)?
    var onStrokeEnd: (() -> Void)?

    /// Process began touches — start a new stroke.
    func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touches.first else { return }
        let pts = coalesced(touch: touch, event: event, view: view)
        onStrokeUpdate?(pts)
    }

    /// Process moved touches — extend current stroke.
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let touch = touches.first else { return }
        let pts = coalesced(touch: touch, event: event, view: view)
        onStrokeUpdate?(pts)
    }

    /// Process ended touches — commit the stroke.
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        onStrokeEnd?()
    }

    // MARK: - Helpers

    private func coalesced(touch: UITouch, event: UIEvent?, view: UIView) -> [TouchPoint] {
        let all = event?.coalescedTouches(for: touch) ?? [touch]
        return all.map { t in
            let loc = t.preciseLocation(in: view)
            let pressure = t.type == .pencil
                ? Float(t.force / max(t.maximumPossibleForce, 0.001))
                : Float(0.5)  // finger gets a fixed mid pressure
            let clamped = min(max(pressure, 0.05), 1.0)
            return TouchPoint(
                x: Float(loc.x),
                y: Float(loc.y),
                pressure: clamped,
                size: 4 + clamped * 28,   // 4–32 px range for Sprint 1
                azimuth: Float(touch.type == .pencil ? touch.azimuthAngle(in: view) : 0),
                altitude: Float(touch.type == .pencil ? touch.altitudeAngle : .pi / 2)
            )
        }
    }
}
