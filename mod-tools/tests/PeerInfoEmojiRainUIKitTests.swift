import Foundation
import UIKit

private var failures: [String] = []
private var checks = 0
private var renderedDownSign = 1.0
private func check(_ value: Bool, _ message: String) {
    checks += 1
    if !value { failures.append(message) }
}

private func centroid(_ view: UIView) -> (x: Double, y: Double, weight: Double) {
    view.layer.displayIfNeeded()
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { context in
        view.layer.render(in: context.cgContext)
    }.cgImage!
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var sum = 0.0, sx = 0.0, sy = 0.0
    pixels.withUnsafeMutableBytes { data in
        let context = CGContext(data: data.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    for y in 0 ..< height {
        for x in 0 ..< width {
            let alpha = Double(pixels[(y * width + x) * 4 + 3]) / 255.0
            sum += alpha
            sx += Double(x) * alpha
            sy += Double(y) * alpha
        }
    }
    return (sum > 0 ? sx / sum : 0, sum > 0 ? sy / sum : 0, sum)
}

private final class TestController: UIViewController {
    let profile = UIView(frame: CGRect(x: 20, y: 40, width: 350, height: 700))
    let button = UIButton(type: .system)
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        self.view.isOpaque = false
        self.view.addSubview(self.profile)
        self.profile.addSubview(self.button)
        self.button.frame = CGRect(x: 40, y: 600, width: 100, height: 44)
        self.button.addTarget(self, action: #selector(self.playRain), for: .touchUpInside)
    }
    @objc private func playRain() {
        PeerInfoEmojiRainOverlay.play(in: self.profile)
    }
    func run() {
        self.button.sendActions(for: .touchUpInside)
        guard let overlay = self.profile.subviews.compactMap({ $0 as? PeerInfoEmojiRainOverlay }).first else {
            check(false, "first tap did not attach an overlay")
            return
        }
        check(overlay.superview === self.profile, "overlay must use profile coordinates")
        check(overlay.frame == self.profile.bounds, "overlay must fill profile bounds")
        check(!overlay.isUserInteractionEnabled, "rain must not consume subsequent taps")
        check(centroid(self.view).weight > 20, "first tap must render visible emoji synchronously")
        overlay.prepareForPixelTest()
        overlay.advanceForPixelTest(by: 0.1)
        let first = centroid(self.view)
        overlay.advanceForPixelTest(by: 0.5)
        let later = centroid(self.view)
        check(first.weight > 20 && later.weight > 20, "both sampled frames must contain emoji pixels")
        check(abs(first.x - later.x) < 0.25, "rendered emoji moved sideways")
        check((later.y - first.y) * renderedDownSign > 10, "rendered emoji must move down")
        check(overlay.layer.animationKeys()?.isEmpty ?? true, "no layer animation may interpolate the path")
        self.button.sendActions(for: .touchUpInside)
        let overlays = self.profile.subviews.compactMap { $0 as? PeerInfoEmojiRainOverlay }
        check(overlays.count == 1 && overlays.first !== overlay, "repeat tap must start exactly one fresh rain")
        check(overlay.superview == nil, "previous rain must be detached")
        if let next = overlays.first {
            check(centroid(self.view).weight > 20, "repeat tap must also render immediately")
            next.prepareForPixelTest()
            next.advanceForPixelTest(by: 9.0)
            check(next.superview == nil, "rain must remove itself after its lifetime")
        }
    }
}

@main final class TestApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = TestController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Calibrate bitmap row order using UIKit views at known positions.
            let reference = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 200))
            reference.backgroundColor = .clear
            reference.isOpaque = false
            let marker = UIView(frame: CGRect(x: 10, y: 20, width: 10, height: 10))
            marker.backgroundColor = .red
            reference.addSubview(marker)
            let top = centroid(reference)
            marker.frame.origin.y = 120
            let bottom = centroid(reference)
            renderedDownSign = bottom.y > top.y ? 1.0 : -1.0
            check(top.weight > 0 && bottom.weight > 0 && abs(top.y - bottom.y) > 90, "bitmap direction calibration")
            // Several independent positions/sizes exercise actual rendered pixels.
            for _ in 0 ..< 20 { autoreleasepool { controller.run() } }
            // A tilted parent used to make a local-Y trajectory move right in
            // the visible screen. Capture the parent, not just the canvas.
            controller.profile.transform = CGAffineTransform(a: 1.0, b: 0.0, c: 0.12, d: 1.0, tx: 0.0, ty: 0.0)
            for _ in 0 ..< 20 { autoreleasepool { controller.run() } }
            let result: [String: Any] = ["checks": checks, "failures": failures, "passed": failures.isEmpty]
            let data = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("rain-ui-result.json")
            try! data.write(to: url)
        }
        return true
    }
}
