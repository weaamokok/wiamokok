import SwiftUI

struct BrushPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String          // SF Symbol
    let softness: Float       // 0 = hard, 1 = airbrush
    let spacing: Float        // fraction of diameter between stamps
    let defaultSize: Float    // diameter in points
    let defaultOpacity: Float
    let sizeJitter: Float     // ± random fraction of stamp size (0 = none)
    let opacityJitter: Float  // ± random fraction of opacity (0 = none)

    // MARK: - Built-in presets

    static let round = BrushPreset(
        id: "round", name: "Round",
        icon: "circle.fill",
        softness: 0.35, spacing: 0.22,
        defaultSize: 20, defaultOpacity: 0.85,
        sizeJitter: 0, opacityJitter: 0
    )

    static let inkPen = BrushPreset(
        id: "inkpen", name: "Ink Pen",
        icon: "pencil.tip",
        softness: 0.04, spacing: 0.07,
        defaultSize: 8, defaultOpacity: 1.0,
        sizeJitter: 0, opacityJitter: 0
    )

    static let marker = BrushPreset(
        id: "marker", name: "Marker",
        icon: "highlighter",
        softness: 0.60, spacing: 0.04,
        defaultSize: 28, defaultOpacity: 0.65,
        sizeJitter: 0, opacityJitter: 0
    )

    static let watercolor = BrushPreset(
        id: "watercolor", name: "Watercolor",
        icon: "drop.fill",
        softness: 0.88, spacing: 0.32,
        defaultSize: 36, defaultOpacity: 0.38,
        sizeJitter: 0.18, opacityJitter: 0.18
    )

    static let chalk = BrushPreset(
        id: "chalk", name: "Chalk",
        icon: "squiggle.horizontal",
        softness: 0.20, spacing: 0.48,
        defaultSize: 20, defaultOpacity: 0.78,
        sizeJitter: 0.28, opacityJitter: 0.30
    )

    static let all: [BrushPreset] = [.round, .inkPen, .marker, .watercolor, .chalk]
}
