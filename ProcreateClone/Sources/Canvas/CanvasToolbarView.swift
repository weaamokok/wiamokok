import SwiftUI

struct CanvasToolbarView: View {

    @Binding var brushColor: Color
    @Binding var brushSize: Float
    @Binding var brushOpacity: Float
    @Binding var activeTool: DrawingTool
    @Binding var activePreset: BrushPreset
    @Binding var softness: Float
    @Binding var spacing: Float
    @ObservedObject var layerStack: LayerStack
    @ObservedObject var history: HistoryManager

    var onClose: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onClear: () -> Void
    var onExport: () -> Void

    @State private var showColorPicker = false
    @State private var showLayers = false
    @State private var showBrushStudio = false

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Left size rail ───────────────────────────────────────────────
            BrushSizeRail(size: $brushSize)
                .frame(width: 44)
                .padding(.leading, 12)
                .padding(.top, 100)

            // ── Tool picker (bottom-left) ────────────────────────────────────
            ToolPickerView(activeTool: $activeTool)
                .padding(.leading, 12)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 32)

            // ── Top bar ─────────────────────────────────────────────────────
            HStack(spacing: 0) {
                // Color swatch
                Button { showColorPicker.toggle() } label: {
                    Circle()
                        .fill(brushColor)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                .accessibilityLabel("Brush color")
                .accessibilityHint("Opens color picker")
                .padding(.leading, 68)

                // Brush studio
                Button { showBrushStudio.toggle() } label: {
                    Image(systemName: activePreset.icon)
                        .font(.system(size: 17))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Brush studio")
                .accessibilityHint("Opens brush settings for \(activePreset.name)")

                Spacer()

                // Layers
                Button { showLayers = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 18))
                        Text("\(layerStack.count)")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.primary)
                    .frame(height: 44)
                    .padding(.horizontal, 8)
                }
                .accessibilityLabel("Layers")
                .accessibilityValue("\(layerStack.count) layer\(layerStack.count == 1 ? "" : "s")")
                .accessibilityHint("Opens layers panel")

                // Undo — dimmed when unavailable
                toolbarButton(icon: "arrow.uturn.backward", label: "Undo", enabled: history.canUndo) { onUndo() }

                // Redo
                toolbarButton(icon: "arrow.uturn.forward", label: "Redo", enabled: history.canRedo) { onRedo() }

                // Clear
                toolbarButton(icon: "trash", label: "Clear layer", enabled: true) { onClear() }

                // Export / share
                toolbarButton(icon: "square.and.arrow.up", label: "Export drawing", enabled: true) { onExport() }

                // Close
                toolbarButton(icon: "xmark.circle.fill", label: "Close canvas", enabled: true) { onClose() }
                    .padding(.trailing, 16)
            }
            .frame(height: 52)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // ── Undo / Redo toast ────────────────────────────────────────────
            if let label = history.toastLabel {
                UndoToast(label: label)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .animation(.spring(response: 0.3), value: label)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: history.toastLabel)
        // Sheets
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheet(color: $brushColor, opacity: $brushOpacity)
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLayers) {
            LayerPanelView(stack: layerStack)
        }
        .sheet(isPresented: $showBrushStudio) {
            BrushStudioView(
                preset: $activePreset,
                brushSize: $brushSize,
                brushOpacity: $brushOpacity,
                softness: $softness,
                spacing: $spacing
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func toolbarButton(icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(enabled ? .primary : .tertiary)
                .frame(width: 44, height: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

// MARK: - Toast

private struct UndoToast: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.72), in: Capsule())
    }
}

// MARK: - Vertical brush size rail

private struct BrushSizeRail: View {
    @Binding var size: Float

    private let minSize: Float = 2
    private let maxSize: Float = 80
    private let railHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.primary)
                .frame(width: CGFloat(size).clamped(4, 40),
                       height: CGFloat(size).clamped(4, 40))
                .animation(.spring(response: 0.2), value: size)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 6)
                        .frame(maxWidth: .infinity)

                    Capsule()
                        .fill(Color.primary.opacity(0.5))
                        .frame(width: 6, height: geo.size.height * CGFloat((size - minSize) / (maxSize - minSize)))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: railHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let pct = Float(1 - v.location.y / geo.size.height)
                            size = minSize + pct.clamped(0, 1) * (maxSize - minSize)
                        }
                )
            }
            .frame(width: 44, height: railHeight)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Color picker sheet

private struct ColorPickerSheet: View {
    @Binding var color: Color
    @Binding var opacity: Float

    var body: some View {
        VStack(spacing: 20) {
            Text("Colour")
                .font(.headline)
                .padding(.top, 8)

            ColorWheelView(color: $color)
                .frame(width: 260, height: 260)

            HStack {
                Text("Opacity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(value: $opacity, in: 0.05...1)
                    .tint(color)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Helpers

private extension Float {
    func clamped(_ lo: Float, _ hi: Float) -> Float { Swift.min(Swift.max(self, lo), hi) }
}

private extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(Swift.max(self, lo), hi) }
}
