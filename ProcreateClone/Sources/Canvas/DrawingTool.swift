import Foundation

enum DrawingTool: String, CaseIterable, Identifiable {
    case brush  = "brush"
    case eraser = "eraser"
    case smudge = "smudge"
    case lasso  = "lasso"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brush:  return "paintbrush.pointed"
        case .eraser: return "eraser"
        case .smudge: return "hand.point.up.left"
        case .lasso:  return "lasso"
        }
    }

    var label: String {
        switch self {
        case .brush:  return "Brush"
        case .eraser: return "Eraser"
        case .smudge: return "Smudge"
        case .lasso:  return "Lasso"
        }
    }
}
