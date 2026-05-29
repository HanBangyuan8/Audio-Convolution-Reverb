import Foundation

public struct WaveformSummary: Codable, Equatable, Sendable {
    public var peaks: [Double]
    public var rms: Double
    public var peak: Double
    public var duration: Double

    public init(peaks: [Double], rms: Double, peak: Double, duration: Double) {
        self.peaks = peaks
        self.rms = rms
        self.peak = peak
        self.duration = duration
    }
}

public struct FrequencyPoint: Codable, Equatable, Sendable {
    public var frequency: Double
    public var magnitudeDB: Double
}

public struct AudioAnalysis: Codable, Equatable, Sendable {
    public var waveform: WaveformSummary
    public var spectrum: [FrequencyPoint]
    public var decay: [Double]

    public init(waveform: WaveformSummary, spectrum: [FrequencyPoint], decay: [Double]) {
        self.waveform = waveform
        self.spectrum = spectrum
        self.decay = decay
    }
}

public enum AudioAnalyzer {
    public static func analyze(_ buffer: AudioBuffer, points: Int = 180) -> AudioAnalysis {
        let mono = buffer.monoSamples
        return AudioAnalysis(
            waveform: waveform(mono, sampleRate: buffer.sampleRate, points: points),
            spectrum: spectrum(mono, sampleRate: buffer.sampleRate, bins: 96),
            decay: decay(mono, points: points)
        )
    }

    public static func waveform(_ samples: [Double], sampleRate: Int, points: Int) -> WaveformSummary {
        guard !samples.isEmpty else {
            return WaveformSummary(peaks: [], rms: 0, peak: 0, duration: 0)
        }
        let bucketSize = max(1, samples.count / max(1, points))
        var peaks: [Double] = []
        var index = 0
        while index < samples.count {
            let end = min(index + bucketSize, samples.count)
            peaks.append(samples[index..<end].map(abs).max() ?? 0)
            index = end
        }
        return WaveformSummary(
            peaks: peaks,
            rms: ReverbDSP.rms(samples),
            peak: ReverbDSP.peak(samples),
            duration: Double(samples.count) / Double(max(sampleRate, 1))
        )
    }

    public static func spectrum(_ samples: [Double], sampleRate: Int, bins: Int) -> [FrequencyPoint] {
        guard !samples.isEmpty else { return [] }
        let fftCount = 2_048
        let stride = max(1, samples.count / fftCount)
        let windowed = (0..<fftCount).map { index -> Double in
            let sourceIndex = min(index * stride, samples.count - 1)
            let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(max(fftCount - 1, 1)))
            return samples[sourceIndex] * window
        }
        let nyquist = Double(sampleRate) / 2
        return (0..<bins).map { bin in
            let position = Double(bin + 1) / Double(bins)
            let frequency = 20 * pow(nyquist / 20, position)
            var real = 0.0
            var imag = 0.0
            for index in windowed.indices {
                let phase = -2 * Double.pi * frequency * Double(index) / Double(sampleRate)
                real += windowed[index] * cos(phase)
                imag += windowed[index] * sin(phase)
            }
            let magnitude = sqrt(real * real + imag * imag) / Double(fftCount)
            return FrequencyPoint(frequency: frequency, magnitudeDB: 20 * log10(max(magnitude, 1e-9)))
        }
    }

    public static func decay(_ samples: [Double], points: Int) -> [Double] {
        guard !samples.isEmpty else { return [] }
        var energy = Array(repeating: 0.0, count: samples.count)
        var running = 0.0
        for index in samples.indices.reversed() {
            running += samples[index] * samples[index]
            energy[index] = running
        }
        let maxEnergy = max(energy.first ?? 0, 1e-12)
        let bucketSize = max(1, energy.count / max(1, points))
        return stride(from: 0, to: energy.count, by: bucketSize).map { index in
            10 * log10(max(energy[index] / maxEnergy, 1e-12))
        }
    }
}
