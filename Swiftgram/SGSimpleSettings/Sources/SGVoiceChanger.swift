import Foundation

public enum SGVoiceEffect: String, CaseIterable {
    case off, deep, high, female, robot

    public func title(russian: Bool) -> String {
        switch self {
        case .off: return russian ? "Без эффекта" : "Off"
        case .deep: return russian ? "Низкий голос" : "Deep voice"
        case .high: return russian ? "Высокий голос" : "High voice"
        case .female: return russian ? "Женский голос" : "Female voice"
        case .robot: return russian ? "Робот" : "Robot"
        }
    }
}

/// Streaming mono Int16 PCM processor. Owned exclusively by the recorder queue.
/// Two overlapping variable-delay grains shift pitch without changing sample count
/// or playback speed. No files, network requests, or audio-session changes are needed.
public final class SGVoiceChanger {
    private let effect: SGVoiceEffect
    private let sampleRate: Double
    private let window: Double
    private var delay: [Double]
    private var writeIndex = 0
    private var pitchPhase = 0.0
    private var carrierPhase = 0.0
    private let femaleHighPassCoefficient: Double
    private let femaleBrightnessCoefficient: Double
    private var previousFemaleInput = 0.0
    private var femaleHighPass = 0.0
    private var femaleLowPass = 0.0

    public init(effect: SGVoiceEffect, sampleRate: Double) {
        precondition(sampleRate.isFinite && sampleRate >= 8000 && sampleRate <= 192000)
        self.effect = effect
        self.sampleRate = sampleRate
        self.window = (sampleRate * 0.04).rounded()
        self.delay = Array(repeating: 0, count: Int(self.window) + 4)
        self.femaleHighPassCoefficient = exp(-2 * Double.pi * 120 / sampleRate)
        self.femaleBrightnessCoefficient = 1 - exp(-2 * Double.pi * 1800 / sampleRate)
    }

    private func delayed(_ distance: Double) -> Double {
        var position = Double(self.writeIndex) - distance
        if position < 0 { position += Double(self.delay.count) }
        let left = Int(position)
        let right = (left + 1) % self.delay.count
        let fraction = position - Double(left)
        return self.delay[left] * (1 - fraction) + self.delay[right] * fraction
    }

    public func process(_ samples: UnsafeMutablePointer<Int16>, count: Int) {
        guard count > 0, self.effect != .off else { return }
        let ratio: Double
        switch self.effect {
        case .deep: ratio = 0.75
        case .female: ratio = 1.25
        default: ratio = 1.35
        }
        let phaseStep = abs(1 - ratio) / self.window
        for index in 0 ..< count {
            let input = Double(samples[index])
            var output: Double
            if self.effect == .robot {
                // Ring modulation produces a mechanical voice at the original tempo.
                output = input * sin(self.carrierPhase)
                self.carrierPhase += 2 * Double.pi * 70 / self.sampleRate
                if self.carrierPhase >= 2 * Double.pi { self.carrierPhase -= 2 * Double.pi }
            } else {
                self.delay[self.writeIndex] = input
                let otherPhase = self.pitchPhase < 0.5 ? self.pitchPhase + 0.5 : self.pitchPhase - 0.5
                let firstDistance = 1 + (ratio < 1 ? self.pitchPhase : 1 - self.pitchPhase) * self.window
                let secondDistance = 1 + (ratio < 1 ? otherPhase : 1 - otherPhase) * self.window
                // Zero gain at each grain's wrap prevents a discontinuity there.
                let weight = 0.5 - 0.5 * cos(2 * Double.pi * self.pitchPhase)
                output = self.delayed(firstDistance) * weight + self.delayed(secondDistance) * (1 - weight)
                self.writeIndex = (self.writeIndex + 1) % self.delay.count
                self.pitchPhase += phaseStep
                if self.pitchPhase >= 1 { self.pitchPhase -= 1 }
            }
            if self.effect == .female {
                // A modest pitch lift, less bass and a brighter spectral balance.
                // This is a local DSP preset, not a neural voice conversion model.
                self.femaleHighPass = self.femaleHighPassCoefficient * (self.femaleHighPass + output - self.previousFemaleInput)
                self.previousFemaleInput = output
                self.femaleLowPass += self.femaleBrightnessCoefficient * (self.femaleHighPass - self.femaleLowPass)
                output = self.femaleHighPass + 0.18 * (self.femaleHighPass - self.femaleLowPass)
            }
            samples[index] = Int16(clamping: Int(output.rounded()))
        }
    }
}
