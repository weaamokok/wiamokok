import SwiftUI

struct BrushStudioView: View {
    @Binding var preset: BrushPreset
    @Binding var brushSize: Float
    @Binding var brushOpacity: Float
    @Binding var softness: Float
    @Binding var spacing: Float

    var body: some View {
        VStack(spacing: 0) {
            // ── Handle ───────────────────────────────────────────────────────
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("Brush Studio")
                .font(.headline)
                .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    presetPicker
                    preview
                    sliders
                }
                .padding(20)
            }
        }
    }

    // MARK: - Preset picker

    private var presetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BrushPreset.all) { p in
                    PresetCard(p: p, isSelected: preset.id == p.id) {
                        preset = p
                        softness = p.softness
                        spacing  = p.spacing
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Live preview (simulated stamp row)

    private var preview: some View {
        Canvas { ctx, size in
            let cy = size.height / 2
            let diam = CGFloat(brushSize).clamped(8, 58)
            let step = max(diam * CGFloat(spacing), 4)
            let count = max(Int((size.width - diam) / step), 1)
            let startX = (size.width - CGFloat(count - 1) * step) / 2

            for i in 0..<count {
                let x = startX + CGFloat(i) * step
                let jY = CGFloat(Float.random(in: -0.15...0.15)) * diam * CGFloat(preset.opacityJitter + 0.01)
                let sv = CGFloat(1 + Float.random(in: -preset.sizeJitter...preset.sizeJitter))
                let d  = diam * sv
                let alpha = Double(brushOpacity) * (1 - Double(Float.random(in: 0...preset.opacityJitter)))

                // Radial gradient via EllipticalGradient trick:
                // Draw concentric circles to fake softness
                let steps = 6
                for s in (0..<steps).reversed() {
                    let t = CGFloat(s) / CGFloat(steps - 1)      // 0 = centre, 1 = edge
                    let r = d / 2 * (t * 0.5 + 0.5)
                    let softFraction = CGFloat(softness)
                    let a = alpha * Double(1 - smoothstep(1 - softFraction, 1, t))
                    let rect = CGRect(x: x - r, y: cy - r + jY, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(.black.opacity(a / Double(steps))))
                }
            }
        }
        .frame(height: 80)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    private func smoothstep(_ lo: CGFloat, _ hi: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - lo) / (hi - lo)))
        return t * t * (3 - 2 * t)
    }

    // MARK: - Sliders

    private var sliders: some View {
        VStack(spacing: 18) {
            StudioSlider(label: "Size", value: $brushSize, range: 2...80, format: { "\(Int($0)) pt" })
            StudioSlider(label: "Opacity", value: $brushOpacity, range: 0.05...1, format: { "\(Int($0 * 100))%" })
            StudioSlider(label: "Softness", value: $softness, range: 0...1, format: { String(format: "%.2f", $0) })
            StudioSlider(label: "Spacing", value: $spacing, range: 0.03...0.8, format: { String(format: "%.2f", $0) })
        }
    }
}

// MARK: - Preset card

private struct PresetCard: View {
    let p: BrushPreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                        .frame(width: 56, height: 56)
                    Image(systemName: p.icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                Text(p.name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .frame(width: 72)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

// MARK: - Slider row

private struct StudioSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let format: (Float) -> String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Slider(value: $value, in: range)
            Text(format(value))
                .font(.subheadline.monospacedDigit())
                .frame(width: 54, alignment: .trailing)
        }
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(Swift.max(self, lo), hi) }
}
