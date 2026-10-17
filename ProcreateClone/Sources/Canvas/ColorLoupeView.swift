import UIKit

/// Floating color swatch displayed while the eyedropper tool samples a color.
/// Shows above the touch point with a white-bordered circle filled with the sampled color.
final class ColorLoupeView: UIView {

    private let outerRing = UIView()
    private let swatch    = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        isUserInteractionEnabled = false

        let size: CGFloat = 72
        bounds = CGRect(x: 0, y: 0, width: size, height: size)

        outerRing.frame = bounds
        outerRing.layer.cornerRadius = size / 2
        outerRing.layer.borderWidth  = 3
        outerRing.layer.borderColor  = UIColor.white.cgColor
        outerRing.layer.shadowColor  = UIColor.black.cgColor
        outerRing.layer.shadowOpacity = 0.45
        outerRing.layer.shadowRadius  = 6
        outerRing.layer.shadowOffset  = .zero
        outerRing.clipsToBounds = false
        addSubview(outerRing)

        let inset: CGFloat = 4
        swatch.frame = CGRect(x: inset, y: inset, width: size - inset*2, height: size - inset*2)
        swatch.layer.cornerRadius = swatch.bounds.width / 2
        swatch.clipsToBounds = true
        outerRing.addSubview(swatch)
    }

    func setColor(_ color: UIColor) {
        swatch.backgroundColor = color
        var brightness: CGFloat = 0
        color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        outerRing.layer.borderColor = (brightness > 0.75 ? UIColor.gray : UIColor.white).cgColor
    }

    /// Re-centers the loupe above the given view-space touch point.
    func moveTo(_ point: CGPoint) {
        center = CGPoint(x: point.x, y: point.y - 88)
    }
}
