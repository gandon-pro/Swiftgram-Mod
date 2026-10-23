import Foundation
import UIKit
import TelegramCore

// MARK: Swiftgram Mod
// Full-screen "milota" emoji rain, started from a profile action row.
// Every drop is a plain CALayer driven by explicit CABasicAnimations, so the
// effect does not depend on CAEmitterLayer timing or the host layer timeline.
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

    // Returns a short diagnostic line describing what was started (shown in a toast).
    @discardableResult
    static func play(in hostView: UIView) -> String {
        let size = "\(Int(hostView.bounds.width))x\(Int(hostView.bounds.height))"
        // One rain at a time; repeated taps while it is running are ignored.
        if let running = hostView.subviews.first(where: { $0 is PeerInfoEmojiRainOverlay }) {
            hostView.bringSubviewToFront(running)
            return "already running, host \(size)"
        }
        let overlay = PeerInfoEmojiRainOverlay(frame: hostView.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(overlay)
        let images = overlay.start()
        return "host \(size), window \(hostView.window != nil ? "yes" : "no"), images \(images)"
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
        self.layer.zPosition = 1000.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func start() -> Int {
        let images = PeerInfoEmojiRainOverlay.emojis.compactMap(PeerInfoEmojiRainOverlay.renderEmoji(_:))
        guard !images.isEmpty, self.bounds.width > 0.0, self.bounds.height > 0.0 else {
            self.removeFromSuperview()
            return images.count
        }

        let count = PeerInfoEmojiRainOverlay.dropCount
        let interval = PeerInfoEmojiRainOverlay.emissionDuration / Double(count)
        for i in 0 ..< count {
            let image = images[i % images.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                self?.addDrop(image: image)
            }
        }

        let totalDuration = PeerInfoEmojiRainOverlay.emissionDuration + PeerInfoEmojiRainOverlay.maxFallDuration + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            self?.removeFromSuperview()
        }
        return images.count
    }

    private func addDrop(image: CGImage) {
        let bounds = self.bounds
        let side = CGFloat.random(in: PeerInfoEmojiRainOverlay.minDropSide ... PeerInfoEmojiRainOverlay.maxDropSide)
        let x = CGFloat.random(in: 0.0 ... bounds.width)
        let startY = -side
        let endY = bounds.height + side
        let drift = CGFloat.random(in: -40.0 ... 40.0)
        let duration = Double.random(in: PeerInfoEmojiRainOverlay.minFallDuration ... PeerInfoEmojiRainOverlay.maxFallDuration)

        let drop = CALayer()
        drop.contents = image
        drop.contentsGravity = .resizeAspect
        drop.bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        // Model value is the final state, so nothing flashes back when the animation ends.
        drop.position = CGPoint(x: x + drift, y: endY)
        self.layer.addSublayer(drop)

        let fall = CABasicAnimation(keyPath: "position")
        fall.fromValue = NSValue(cgPoint: CGPoint(x: x, y: startY))
        fall.toValue = NSValue(cgPoint: CGPoint(x: x + drift, y: endY))
        fall.duration = duration
        fall.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0.0
        spin.toValue = Double.random(in: -Double.pi ... Double.pi)
        spin.duration = duration

        // A group's duration does not scale its children's durations. Keep
        // both animations running until the drop reaches the bottom.
        let group = CAAnimationGroup()
        group.animations = [fall, spin]
        group.duration = duration
        group.isRemovedOnCompletion = true
        drop.add(group, forKey: "rain")

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
