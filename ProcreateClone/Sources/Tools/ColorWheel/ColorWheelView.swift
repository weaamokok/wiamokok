import SwiftUI

/// Procreate-style color picker: outer hue ring + inner S×B square.
struct ColorWheelView: View {
    @Binding var color: Color

    // Internal HSB state
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1

    private let ringWidth: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerR = size / 2
            let innerR = outerR - ringWidth - 4

            ZStack {
                // ── Hue ring ────────────────────────────────────────────────
                HueRing(outerRadius: outerR, innerRadius: outerR - ringWidth)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let angle = atan2(
                                    v.location.y - centre.y,
                                    v.location.x - centre.x
                                )
                                var h = Double(angle) / (2 * .pi)
                                if h < 0 { h += 1 }
                                hue = h
                                updateColor()
                            }
                    )

                // Hue indicator dot on ring
                let hueAngle = Angle(degrees: hue * 360 - 90)
                let dotR = outerR - ringWidth / 2
                Circle()
                    .fill(Color(hue: hue, saturation: 1, brightness: 1))
                    .frame(width: ringWidth - 4, height: ringWidth - 4)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
                    .offset(
                        x: dotR * cos(CGFloat(hueAngle.radians)),
                        y: dotR * sin(CGFloat(hueAngle.radians))
                    )

                // ── Saturation × Brightness square ──────────────────────────
                SBSquare(hue: hue, size: innerR * 2 * 0.78)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let sqSize = innerR * 2 * 0.78
                                let origin = CGPoint(
                                    x: centre.x - sqSize / 2,
                                    y: centre.y - sqSize / 2
                                )
                                saturation = (v.location.x - origin.x) / sqSize
                                brightness = 1 - (v.location.y - origin.y) / sqSize
                                saturation = saturation.clamped(0, 1)
                                brightness = brightness.clamped(0, 1)
                                updateColor()
                            }
                    )

                // SB indicator dot
                let sqSize = innerR * 2 * 0.78
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
                    .offset(
                        x: (saturation * sqSize - sqSize / 2),
                        y: ((1 - brightness) * sqSize - sqSize / 2)
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { syncFromColor() }
        .onChange(of: color) { _ in syncFromColor() }
    }

    private func updateColor() {
        color = Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private func syncFromColor() {
        let ui = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h)
        saturation = Double(s)
        brightness = Double(b)
    }
}

// MARK: - Hue ring

private struct HueRing: View {
    let outerRadius: CGFloat
    let innerRadius: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let steps = 360
            for i in 0..<steps {
                let start = Angle(degrees: Double(i) - 0.6)
                let end   = Angle(degrees: Double(i) + 0.6)
                var path = Path()
                path.addArc(center: centre, radius: outerRadius,
                            startAngle: start, endAngle: end, clockwise: false)
                path.addArc(center: centre, radius: innerRadius,
                            startAngle: end, endAngle: start, clockwise: true)
                path.closeSubpath()
                ctx.fill(path, with: .color(Color(hue: Double(i) / 360,
                                                   saturation: 1, brightness: 1)))
            }
        }
    }
}

// MARK: - Saturation × Brightness square

private struct SBSquare: View {
    let hue: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            // White → pure hue (saturation axis, left to right)
            LinearGradient(
                colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)],
                startPoint: .leading, endPoint: .trailing
            )
            // Transparent → black (brightness axis, top to bottom)
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}
