import Foundation
import UIKit
import TelegramCore

// MARK: Swiftgram Mod
// Full-screen "milota" emoji rain, started from a profile action row.
final class PeerInfoEmojiRainOverlay: UIView {
    // Profiles (lowercased usernames, without "@") that get the rain button.
    static let enabledUsernames: Set<String> = ["pastavibecoding"]
    static let emojis: [String] = ["🥰", "🥺", "💕", "😻", "🧸"]

    private static let emissionDuration: Double = 3.5
    private static let particleLifetime: Float = 6.0
    private static let imageSide: CGFloat = 128.0

    static func isEnabled(for user: TelegramUser) -> Bool {
        var usernames: [String] = user.usernames.filter { $0.isActive }.map { $0.username }
        if let addressName = user.addressName {
            usernames.append(addressName)
        }
        return usernames.contains(where: { self.enabledUsernames.contains($0.lowercased()) })
    }

    static func play(in hostView: UIView) {
        // One rain at a time; repeated taps while it is running are ignored.
        if hostView.subviews.contains(where: { $0 is PeerInfoEmojiRainOverlay }) {
            return
        }
        let overlay = PeerInfoEmojiRainOverlay(frame: hostView.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(overlay)
        overlay.start()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func start() {
        let cells = PeerInfoEmojiRainOverlay.emojis.compactMap(PeerInfoEmojiRainOverlay.makeCell(emoji:))
        guard !cells.isEmpty else {
            self.removeFromSuperview()
            return
        }

        let emitter = CAEmitterLayer()
        emitter.frame = self.bounds
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: self.bounds.midX, y: -PeerInfoEmojiRainOverlay.imageSide * 0.5)
        emitter.emitterSize = CGSize(width: self.bounds.width * 1.2, height: 1.0)
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = cells
        self.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + PeerInfoEmojiRainOverlay.emissionDuration) { [weak emitter] in
            emitter?.birthRate = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + PeerInfoEmojiRainOverlay.emissionDuration + Double(PeerInfoEmojiRainOverlay.particleLifetime)) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    private static func makeCell(emoji: String) -> CAEmitterCell? {
        guard let image = self.renderEmoji(emoji) else {
            return nil
        }
        let cell = CAEmitterCell()
        cell.contents = image
        cell.birthRate = 3.0
        cell.lifetime = self.particleLifetime
        cell.velocity = 160.0
        cell.velocityRange = 80.0
        cell.yAcceleration = 90.0
        // y grows downwards on iOS, so pi/2 points the emission down.
        cell.emissionLongitude = .pi / 2.0
        cell.emissionRange = .pi / 10.0
        cell.spin = 0.0
        cell.spinRange = 1.5
        // 128 px source rendered at ~36 pt.
        cell.scale = 0.28
        cell.scaleRange = 0.1
        return cell
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
