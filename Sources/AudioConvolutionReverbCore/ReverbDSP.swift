import Foundation

public enum ReverbDSP {
    public static func generateLogSweep(
        duration: Double = 10,
        sampleRate: Int = 44_100,
        startFrequency: Double = 20,
        endFrequency: Double = 20_000
    ) -> AudioBuffer {
        let sampleCount = max(1, Int(duration * Double(sampleRate)))
        let logRatio = log(endFrequency / startFrequency)
        let samples = (0..<sampleCount).map { index in
            let t = Double(index) / Double(max(sampleCount - 1, 1)) * duration
            let phase = 2 * Double.pi * startFrequency * duration / logRatio * (exp(t * logRatio / duration) - 1)
            return sin(phase)
        }
        return AudioBuffer(samples: [normalize(samples, peak: 1)], sampleRate: sampleRate)
    }

    public static func extractImpulseResponse(
        recorded: AudioBuffer,
        sweep: AudioBuffer,
        irLength: Double = 10
    ) -> AudioBuffer {
        let recordedMono = recorded.monoSamples
        let sweepMono = resampleIfNeeded(sweep.monoSamples, from: sweep.sampleRate, to: recorded.sampleRate)
        let inverseSweep = Array(sweepMono.reversed())
        let deconvolved = ComplexFFT.convolve(recordedMono, inverseSweep)
        guard let peakIndex = deconvolved.indices.max(by: { abs(deconvolved[$0]) < abs(deconvolved[$1]) }) else {
            return AudioBuffer(samples: [[]], sampleRate: recorded.sampleRate)
        }
        let length = min(Int(irLength * Double(recorded.sampleRate)), max(0, deconvolved.count - peakIndex))
        let impulse = normalize(Array(deconvolved[peakIndex..<peakIndex + length]), peak: 1)
        return AudioBuffer(samples: [impulse], sampleRate: recorded.sampleRate)
    }

    public static func applyConvolutionReverb(
        dry: AudioBuffer,
        impulseResponse: AudioBuffer,
        settings: ReverbSettings
    ) -> AudioBuffer {
        var ir = resampleIfNeeded(impulseResponse.monoSamples, from: impulseResponse.sampleRate, to: dry.sampleRate)
        ir = shapedImpulse(ir, sampleRate: dry.sampleRate, settings: settings)
        let inputGain = dbToLinear(settings.inputGainDB)
        let outputGain = dbToLinear(settings.outputGainDB)
        let tailSamples = max(0, Int(settings.tailLengthSeconds * Double(dry.sampleRate)))
        let latencySamples = Int(settings.latencyCompensationMilliseconds / 1000 * Double(dry.sampleRate))

        let renderedChannels = dry.samples.map { channel -> [Double] in
            let input = channel.map { $0 * inputGain }
            var wet = ComplexFFT.convolve(input, ir)
            if settings.normalizeWetSignal {
                wet = normalize(wet, peak: 0.95)
            }
            let count = min(max(channel.count, channel.count + tailSamples), wet.count)
            var mixed = Array(repeating: 0.0, count: count)
            for index in 0..<count {
                let dryValue = index < input.count ? input[index] : 0
                let wetIndex = index + latencySamples
                let wetValue = wet.indices.contains(wetIndex) ? wet[wetIndex] : 0
                mixed[index] = (settings.dryLevel * dryValue + settings.wetLevel * wetValue) * outputGain
            }
            return mixed
        }

        let widened = applyStereoWidth(renderedChannels, width: settings.stereoWidth)
        let rendered = AudioBuffer(samples: widened, sampleRate: dry.sampleRate)
        return settings.normalizeOutput ? rendered.normalized(peak: 0.95) : rendered
    }

    public static func createCustomImpulse(
        sampleRate: Int,
        duration: Double,
        decay: Double,
        tone: Double,
        earlyReflectionCount: Int,
        seed: UInt64 = 42
    ) -> AudioBuffer {
        let count = max(1, Int(duration * Double(sampleRate)))
        var random = SeededRandom(seed: seed)
        var samples = Array(repeating: 0.0, count: count)
        samples[0] = 1

        if earlyReflectionCount > 0 {
            for reflection in 1...earlyReflectionCount {
                let position = min(count - 1, Int(Double(reflection) / Double(earlyReflectionCount + 1) * 0.18 * Double(sampleRate)))
                samples[position] += (random.nextDouble() * 2 - 1) * pow(0.72, Double(reflection))
            }
        }

        for index in 1..<count {
            let t = Double(index) / Double(sampleRate)
            let envelope = exp(-decay * t / max(duration, 0.001))
            let brightness = min(max(tone, 0), 1)
            let noise = (random.nextDouble() * 2 - 1) * envelope
            let shimmer = sin(2 * Double.pi * (380 + 7_000 * brightness) * t) * envelope * 0.08 * brightness
            samples[index] += noise * (0.3 + 0.7 * brightness) + shimmer
        }

        return AudioBuffer(samples: [normalize(samples, peak: 1)], sampleRate: sampleRate)
    }

    public static func rms(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0) { $0 + $1 * $1 } / Double(samples.count))
    }

    public static func peak(_ samples: [Double]) -> Double {
        samples.map(abs).max() ?? 0
    }

    public static func normalize(_ samples: [Double], peak: Double) -> [Double] {
        let maxValue = samples.map(abs).max() ?? 0
        guard maxValue > 0 else { return samples }
        return samples.map { $0 / maxValue * peak }
    }

    private static func shapedImpulse(_ input: [Double], sampleRate: Int, settings: ReverbSettings) -> [Double] {
        var ir = settings.reverseImpulse ? Array(input.reversed()) : input
        ir = trim(ir, sampleRate: sampleRate, startMilliseconds: settings.impulseTrimStartMilliseconds, endMilliseconds: settings.impulseTrimEndMilliseconds)
        ir = applyFades(ir, sampleRate: sampleRate, fadeInMilliseconds: settings.fadeInMilliseconds, fadeOutMilliseconds: settings.fadeOutMilliseconds)
        if settings.decayScale != 1 {
            let count = max(ir.count - 1, 1)
            ir = ir.enumerated().map { index, sample in
                let position = Double(index) / Double(count)
                return sample * exp(-position * max(settings.decayScale - 1, -0.95) * 4)
            }
        }

        ir = toneFilter(ir, sampleRate: sampleRate, lowCutHz: settings.lowCutHz, highCutHz: settings.highCutHz)

        let preDelaySamples = max(0, Int(settings.preDelayMilliseconds / 1000 * Double(sampleRate)))
        if preDelaySamples > 0 {
            ir = Array(repeating: 0.0, count: preDelaySamples) + ir
        }
        return ir
    }

    private static func trim(_ input: [Double], sampleRate: Int, startMilliseconds: Double, endMilliseconds: Double) -> [Double] {
        guard !input.isEmpty else { return input }
        let start = min(max(0, Int(startMilliseconds / 1000 * Double(sampleRate))), input.count - 1)
        let endTrim = max(0, Int(endMilliseconds / 1000 * Double(sampleRate)))
        let end = max(start + 1, input.count - endTrim)
        return Array(input[start..<min(end, input.count)])
    }

    private static func applyFades(_ input: [Double], sampleRate: Int, fadeInMilliseconds: Double, fadeOutMilliseconds: Double) -> [Double] {
        var output = input
        let fadeInCount = min(output.count, max(0, Int(fadeInMilliseconds / 1000 * Double(sampleRate))))
        let fadeOutCount = min(output.count, max(0, Int(fadeOutMilliseconds / 1000 * Double(sampleRate))))
        if fadeInCount > 1 {
            for index in 0..<fadeInCount {
                output[index] *= Double(index) / Double(fadeInCount - 1)
            }
        }
        if fadeOutCount > 1 {
            let start = output.count - fadeOutCount
            for offset in 0..<fadeOutCount {
                output[start + offset] *= 1 - Double(offset) / Double(fadeOutCount - 1)
            }
        }
        return output
    }

    private static func applyStereoWidth(_ channels: [[Double]], width: Double) -> [[Double]] {
        guard channels.count == 2, channels[0].count == channels[1].count else { return channels }
        let safeWidth = min(max(width, 0), 2)
        var left = channels[0]
        var right = channels[1]
        for index in left.indices {
            let mid = (left[index] + right[index]) * 0.5
            let side = (left[index] - right[index]) * 0.5 * safeWidth
            left[index] = mid + side
            right[index] = mid - side
        }
        return [left, right]
    }

    private static func dbToLinear(_ db: Double) -> Double {
        pow(10, db / 20)
    }

    private static func toneFilter(_ input: [Double], sampleRate: Int, lowCutHz: Double, highCutHz: Double) -> [Double] {
        guard !input.isEmpty else { return input }
        var output = input
        let dt = 1 / Double(sampleRate)

        if highCutHz < Double(sampleRate) / 2 {
            let rc = 1 / (2 * Double.pi * max(highCutHz, 10))
            let alpha = dt / (rc + dt)
            var previous = output[0]
            for index in output.indices {
                previous += alpha * (output[index] - previous)
                output[index] = previous
            }
        }

        if lowCutHz > 0 {
            let rc = 1 / (2 * Double.pi * lowCutHz)
            let alpha = rc / (rc + dt)
            var previousInput = output[0]
            var previousOutput = 0.0
            for index in output.indices {
                let current = output[index]
                let filtered = alpha * (previousOutput + current - previousInput)
                output[index] = filtered
                previousInput = current
                previousOutput = filtered
            }
        }
        return output
    }

    private static func resampleIfNeeded(_ input: [Double], from sourceRate: Int, to targetRate: Int) -> [Double] {
        guard sourceRate != targetRate, !input.isEmpty else { return input }
        let ratio = Double(sourceRate) / Double(targetRate)
        let outputCount = max(1, Int(Double(input.count) / ratio))
        return (0..<outputCount).map { index in
            let sourcePosition = Double(index) * ratio
            let lower = Int(sourcePosition)
            let upper = min(lower + 1, input.count - 1)
            let fraction = sourcePosition - Double(lower)
            return input[lower] * (1 - fraction) + input[upper] * fraction
        }
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x1234_5678 : seed
    }

    mutating func nextDouble() -> Double {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
}
