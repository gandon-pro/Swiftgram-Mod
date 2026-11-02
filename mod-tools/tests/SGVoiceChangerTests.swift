import Foundation

@main
struct SGVoiceChangerTests {
    static func apply(_ effect: SGVoiceEffect, _ input: [Int16], chunks: [Int], rate: Double = 48000) -> [Int16] {
        let processor = SGVoiceChanger(effect: effect, sampleRate: rate)
        var output = input
        output.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            var chunk = 0
            while offset < buffer.count {
                let count = min(chunks[chunk % chunks.count], buffer.count - offset)
                processor.process(base.advanced(by: offset), count: count)
                offset += count
                chunk += 1
            }
        }
        return output
    }

    static func spectralPeak(_ samples: [Int16], rate: Double) -> Int {
        // Independent frequency-domain check; skip delay-line startup transient.
        let start = Int(rate / 5)
        let count = Int(rate / 2)
        var best = 0
        var bestPower = 0.0
        for hz in 100 ... 400 {
            var real = 0.0
            var imaginary = 0.0
            for i in 0 ..< count {
                let phase = 2 * Double.pi * Double(hz * i) / rate
                let weight = 0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(count - 1))
                let value = Double(samples[start + i]) * weight
                real += value * cos(phase)
                imaginary += value * sin(phase)
            }
            let power = real * real + imaginary * imaginary
            if power > bestPower { bestPower = power; best = hz }
        }
        return best
    }

    static func main() {
        let key = "sg.mod.voiceEffect"
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)
        precondition(SGPrivacySettings.voiceEffect == .off)
        for effect in SGVoiceEffect.allCases {
            SGPrivacySettings.voiceEffect = effect
            precondition(defaults.string(forKey: key) == effect.rawValue)
            precondition(SGPrivacySettings.voiceEffect == effect)
        }
        defaults.set("unknown-future-effect", forKey: key)
        precondition(SGPrivacySettings.voiceEffect == .off)

        for rate in [16000.0, 48000.0] {
            let tone = (0 ..< Int(rate)).map { i in
                Int16((12000 * sin(2 * Double.pi * 220 * Double(i) / rate)).rounded())
            }
            precondition(apply(.off, tone, chunks: [127, 960]) == tone, "Off must be bit-exact")
            for effect in SGVoiceEffect.allCases {
                let whole = apply(effect, tone, chunks: [tone.count], rate: rate)
                let split = apply(effect, tone, chunks: [1, 127, 960, 2048], rate: rate)
                precondition(whole == split, "Audio callback sizes must not change the effect")
                precondition(whole.count == tone.count, "Voice duration must stay unchanged")
                let silence = apply(effect, Array(repeating: 0, count: 4096), chunks: [37], rate: rate)
                precondition(silence.allSatisfy { $0 == 0 })
                if effect != .off { precondition(whole != tone) }
                if effect == .deep {
                    precondition(abs(spectralPeak(whole, rate: rate) - 165) <= 12)
                } else if effect == .high {
                    precondition(abs(spectralPeak(whole, rate: rate) - 297) <= 12)
                }
            }
        }
        let extremes: [Int16] = (0 ..< 10000).map { $0 % 2 == 0 ? Int16.min : Int16.max }
        for effect in SGVoiceEffect.allCases {
            precondition(apply(effect, extremes, chunks: [257]).count == extremes.count)
        }
        print("Voice effect persistence, bypass, pitch, silence and streaming continuity passed")
    }
}
