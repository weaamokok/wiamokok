import SwiftUI

struct SelectionOverlayView: View {
    @ObservedObject var state: SelectionState
    let onDone:   () -> Void
    let onCancel: () -> Void

    var body: some View {
        if state.isActive {
            ZStack(alignment: .bottom) {
                selectionRect
                actionBar
            }
        }
    }

    // Dashed bounding rect drawn over the canvas
    private var selectionRect: some View {
        GeometryReader { geo in
            let b = state.currentBounds
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color.accentColor)
                .frame(width: b.width, height: b.height)
                .position(x: b.midX, y: b.midY)
        }
    }

    // Done / Cancel pill at the bottom
    private var actionBar: some View {
        HStack(spacing: 16) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color(.systemGray2), in: Capsule())
            }
            Button(action: onDone) {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .padding(.bottom, 32)
    }
}
