import Metal
import CoreGraphics

/// Shared observable state for the floating selection (lasso extract + transform).
@MainActor
final class SelectionState: ObservableObject {
    @Published var isActive: Bool = false
    /// Cumulative move + scale transform in canvas POINT coordinates.
    @Published var transform: CGAffineTransform = .identity

    /// The pixel region that was cut from the active layer.
    var contentTexture: MTLTexture?
    /// Bounding box of the lasso path in canvas POINT coordinates (pre-transform).
    var originalBounds: CGRect = .zero
    /// Snapshot of the active layer taken just before the cut (for cancel).
    var preCutSnapshot: MTLTexture?

    /// Bounding box after applying the current transform (in canvas POINT coordinates).
    var currentBounds: CGRect { originalBounds.applying(transform) }

    func reset() {
        isActive        = false
        transform       = .identity
        contentTexture  = nil
        originalBounds  = .zero
        preCutSnapshot  = nil
    }
}
