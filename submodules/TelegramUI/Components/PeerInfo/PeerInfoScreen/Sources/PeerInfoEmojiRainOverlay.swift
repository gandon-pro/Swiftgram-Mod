import Foundation
import UIKit
import TelegramCore

// MARK: Swiftgram Mod
// Full-screen "milota" emoji rain, started from a profile action row.
// Both profile buttons share this effect. Each drop animates only its Y position.
final class PeerInfoEmojiRainOverlay: UIView {
    // Profiles (lowercased usernames, without "@") that get the rain button.
    static let enabledUsernames: Set<String> = ["pastavibecoding"]
    static let emojis: [String] = ["🥰", "🥺", "💕", "😻", "🧸"]

    private static let emissionDuration: Double = 3.5
    private static let dropCount: Int = 70
    private static let minFallDuration: Double = 2.4
    private static let maxFallDuration: Double = 4.2
    private static let minDropSide: CGFloat = 28.0
    private static let maxDropSide: CGFloat = 46.0
    private static let imageSide: CGFloat = 96.0

    static func isEnabled(for user: TelegramUser) -> Bool {
        var usernames: [String] = user.usernames.filter { $0.isActive }.map { $0.username }
        if let addressName = user.addressName {
            usernames.append(addressName)
        }
        return usernames.contains(where: { self.enabledUsernames.contains($0.lowercased()) })
    }

    @discardableResult
    static func play(in hostView: UIView) -> PeerInfoEmojiRainOverlay? {
        // Use the visible window so profile layout cannot cover the first rain.
        let surface: UIView = hostView.window ?? hostView
        surface.layoutIfNeeded()
        guard surface.bounds.width > 0.0, surface.bounds.height > 0.0 else {
            return nil
        }
        // Every tap starts a fresh effect, including taps during an active rain.
        for running in surface.subviews where running is PeerInfoEmojiRainOverlay {
            running.removeFromSuperview()
        }
        let overlay = PeerInfoEmojiRainOverlay(frame: surface.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        surface.addSubview(overlay)
        overlay.start()
        return overlay
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.clipsToBounds = true
        self.layer.zPosition = 1000.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func start() {
        let images = PeerInfoEmojiRainOverlay.emojis.compactMap(PeerInfoEmojiRainOverlay.renderEmoji(_:))
        guard !images.isEmpty else {
            self.removeFromSuperview()
            return
        }

        let reducedMotion = UIAccessibility.isReduceMotionEnabled
        let immediateCount = 6
        // Show a visible first batch synchronously, before scheduling the rest.
        for i in 0 ..< immediateCount {
            self.addDrop(image: images[i % images.count], visibleAtStart: true, reducedMotion: reducedMotion)
        }
        if reducedMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.removeFromSuperview()
            }
            return
        }

        let count = PeerInfoEmojiRainOverlay.dropCount
        let interval = PeerInfoEmojiRainOverlay.emissionDuration / Double(count - immediateCount)
        for i in immediateCount ..< count {
            let image = images[i % images.count]
            let delay = interval * Double(i - immediateCount + 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.addDrop(image: image, visibleAtStart: false, reducedMotion: false)
            }
        }

        let totalDuration = PeerInfoEmojiRainOverlay.emissionDuration + PeerInfoEmojiRainOverlay.maxFallDuration + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    private func addDrop(image: CGImage, visibleAtStart: Bool, reducedMotion: Bool) {
        guard self.superview != nil else { return }
        let bounds = self.bounds
        let side = CGFloat.random(in: PeerInfoEmojiRainOverlay.minDropSide ... PeerInfoEmojiRainOverlay.maxDropSide)
        let margin = min(side / 2.0, bounds.width / 2.0)
        let x = CGFloat.random(in: margin ... max(margin, bounds.width - margin))
        let startY = reducedMotion ? CGFloat.random(in: 0.25 ... 0.75) * bounds.height : (visibleAtStart ? side / 2.0 : -side / 2.0)
        let endY = bounds.height + side
        let duration = reducedMotion ? 0.8 : Double.random(in: PeerInfoEmojiRainOverlay.minFallDuration ... PeerInfoEmojiRainOverlay.maxFallDuration)

        let drop = CALayer()
        drop.contents = image
        drop.contentsGravity = .resizeAspect
        drop.bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        // X stays fixed. Animate Y only so neither drift nor implicit position
        // animation can send the emoji diagonally across the profile.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        drop.position = CGPoint(x: x, y: reducedMotion ? startY : endY)
        if reducedMotion { drop.opacity = 0.0 }
        self.layer.addSublayer(drop)
        CATransaction.commit()

        let animation = CABasicAnimation(keyPath: reducedMotion ? "opacity" : "position.y")
        animation.fromValue = reducedMotion ? 1.0 : startY
        animation.toValue = reducedMotion ? 0.0 : endY
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        drop.add(animation, forKey: "rain")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak drop] in
            drop?.removeFromSuperlayer()
        }
    }

    private static func renderEmoji(_ emoji: String) -> CGImage? {
        let size = CGSize(width: self.imageSide, height: self.imageSide)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let string = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: self.imageSide * 0.8)])
            let textSize = string.size()
            string.draw(at: CGPoint(x: (size.width - textSize.width) / 2.0, y: (size.height - textSize.height) / 2.0))
        }
        return image.cgImage
    }
}
