import Foundation

enum LayerBlendMode: UInt32, CaseIterable, Identifiable {
    case normal     = 0
    case multiply   = 1
    case screen     = 2
    case overlay    = 3
    case softLight  = 4
    case colorDodge = 5
    case colorBurn  = 6
    case difference = 7

    var id: UInt32 { rawValue }

    var displayName: String {
        switch self {
        case .normal:     return "Normal"
        case .multiply:   return "Multiply"
        case .screen:     return "Screen"
        case .overlay:    return "Overlay"
        case .softLight:  return "Soft Light"
        case .colorDodge: return "Color Dodge"
        case .colorBurn:  return "Color Burn"
        case .difference: return "Difference"
        }
    }
}
