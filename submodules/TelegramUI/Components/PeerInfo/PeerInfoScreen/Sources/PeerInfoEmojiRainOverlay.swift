import Foundation
import UIKit

private final class PeerInfoEmojiRainDisplayLinkTarget: NSObject {
    weak var overlay: PeerInfoEmojiRainOverlay?

    @objc func tick(_ link: CADisplayLink) {
        self.overlay?.advance(to: link.timestamp)
    }
}

// The canvas belongs to the profile. Particle trajectories are expressed in
// window coordinates and converted back each frame to cancel parent transforms.
final class PeerInfoEmojiRainOverlay: UIView {
    private struct Drop {
        let image: UIImage
        let x: CGFloat
        let side: CGFloat
        let startY: CGFloat
        let endY: CGFloat
        let birth: CFTimeInterval
        let duration: Double
    }

    private static let emissionDuration = 3.5
    private static let dropCount = 70
    private static let immediateCount = 6
    private static let maxFallDuration = 4.2
    private static let emojis = ["🥰", "🥺", "💕", "😻", "🧸"]

    private var drops: [Drop] = []
    private var images: [UIImage] = []
    private let displayLinkTarget = PeerInfoEmojiRainDisplayLinkTarget()
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0.0
    private var frameTime: CFTimeInterval = 0.0
    private var emitted = 0
    private var reducedMotion = false
    private weak var coordinateView: UIView?
    private var emissionBounds = CGRect.zero

    @discardableResult
    static func play(in hostView: UIView) -> PeerInfoEmojiRainOverlay? {
        hostView.layoutIfNeeded()
        guard hostView.bounds.width > 0.0, hostView.bounds.height > 0.0 else { return nil }
        for running in hostView.subviews where running is PeerInfoEmojiRainOverlay {
            running.removeFromSuperview()
        }
        let overlay = PeerInfoEmojiRainOverlay(frame: hostView.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(overlay)
        hostView.bringSubviewToFront(overlay)
        overlay.start()
        return overlay
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.zPosition = 1000.0
        self.contentMode = .redraw
        self.displayLinkTarget.overlay = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
        super.willMove(toSuperview: newSuperview)
    }

    private func start() {
        let coordinates: UIView = self.window ?? self.superview ?? self
        self.coordinateView = coordinates
        self.emissionBounds = self.convert(self.bounds, to: coordinates)
        self.images = Self.emojis.map(Self.renderEmoji)
        self.reducedMotion = UIAccessibility.isReduceMotionEnabled
        self.startTime = CACurrentMediaTime()
        self.frameTime = self.startTime
        for _ in 0 ..< Self.immediateCount {
            self.emit(at: self.startTime, visibleAtStart: true)
        }
        // Paint the first batch in the same tap, with no dispatch/delayed start.
        self.setNeedsDisplay()
        self.layer.displayIfNeeded()
        let link = CADisplayLink(target: self.displayLinkTarget, selector: #selector(PeerInfoEmojiRainDisplayLinkTarget.tick(_:)))
        self.displayLink = link
        link.add(to: .main, forMode: .common)
    }

    fileprivate func advance(to timestamp: CFTimeInterval) {
        guard self.superview != nil else { return }
        self.frameTime = max(timestamp, self.startTime)
        let elapsed = self.frameTime - self.startTime
        if !self.reducedMotion {
            let interval = Self.emissionDuration / Double(Self.dropCount - Self.immediateCount)
            while self.emitted < Self.dropCount {
                let delay = interval * Double(self.emitted - Self.immediateCount + 1)
                if delay > elapsed { break }
                self.emit(at: self.startTime + delay, visibleAtStart: false)
            }
        }
        self.drops.removeAll { self.frameTime - $0.birth >= $0.duration }
        let lifetime = self.reducedMotion ? 0.8 : Self.emissionDuration + Self.maxFallDuration
        if elapsed >= lifetime {
            self.removeFromSuperview()
        } else {
            self.setNeedsDisplay()
        }
    }

    private func emit(at time: CFTimeInterval, visibleAtStart: Bool) {
        let side = CGFloat.random(in: 28.0 ... 46.0)
        let margin = min(side / 2.0, self.bounds.width / 2.0)
        let localX: CGFloat
        if visibleAtStart {
            localX = margin + (self.bounds.width - 2.0 * margin) * CGFloat(self.emitted + 1) / CGFloat(Self.immediateCount + 1)
        } else {
            localX = CGFloat.random(in: margin ... max(margin, self.bounds.width - margin))
        }
        let localY = self.reducedMotion ? CGFloat.random(in: 0.25 ... 0.75) * self.bounds.height : (visibleAtStart ? side / 2.0 : -side / 2.0)
        let start = self.convert(CGPoint(x: localX, y: localY), to: self.coordinateView ?? self)
        self.drops.append(Drop(image: self.images[self.emitted % self.images.count], x: start.x, side: side,
            startY: start.y, endY: self.emissionBounds.maxY + side, birth: time,
            duration: self.reducedMotion ? 0.8 : Double.random(in: 2.4 ... Self.maxFallDuration)))
        self.emitted += 1
    }

    override func draw(_ rect: CGRect) {
        for drop in self.drops {
            let progress = CGFloat(min(1.0, max(0.0, (self.frameTime - drop.birth) / drop.duration)))
            let y = self.reducedMotion ? drop.startY : drop.startY + (drop.endY - drop.startY) * progress
            let windowPoint = CGPoint(x: drop.x, y: y)
            let coordinates = self.coordinateView ?? self
            let localPoint = self.convert(windowPoint, from: coordinates)
            drop.image.draw(in: CGRect(x: localPoint.x - drop.side / 2.0, y: localPoint.y - drop.side / 2.0,
                width: drop.side, height: drop.side), blendMode: .normal,
                alpha: self.reducedMotion ? 1.0 - progress : 1.0)
        }
    }

    private static func renderEmoji(_ emoji: String) -> UIImage {
        let side: CGFloat = 96.0
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let string = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: side * 0.8)])
            let textSize = string.size()
            string.draw(at: CGPoint(x: (side - textSize.width) / 2.0, y: (side - textSize.height) / 2.0))
        }
    }

    #if PEERINFO_EMOJI_RAIN_TESTS
    func prepareForPixelTest() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        if let first = self.drops.first {
            self.drops = [Drop(image: first.image, x: self.emissionBounds.midX, side: 32.0,
                startY: self.emissionBounds.minY + 16.0, endY: self.emissionBounds.maxY + 32.0,
                birth: first.birth, duration: 3.0)]
        }
        self.emitted = Self.dropCount
        self.reducedMotion = false
    }

    func advanceForPixelTest(by elapsed: Double) {
        self.advance(to: self.startTime + elapsed)
        self.layer.displayIfNeeded()
    }
    #endif
}
