import Foundation

public struct AudioBuffer: Sendable {
    public var samples: [[Double]]
    public var sampleRate: Int

    public init(samples: [[Double]], sampleRate: Int) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public var channelCount: Int { samples.count }
    public var frameCount: Int { samples.first?.count ?? 0 }
    public var duration: Double { sampleRate > 0 ? Double(frameCount) / Double(sampleRate) : 0 }

    public var monoSamples: [Double] {
        guard let first = samples.first else { return [] }
        if samples.count == 1 { return first }
        var mixed = Array(repeating: 0.0, count: frameCount)
        for channel in samples {
            for index in 0..<min(channel.count, mixed.count) {
                mixed[index] += channel[index] / Double(samples.count)
            }
        }
        return mixed
    }

    public func normalized(peak: Double = 0.95) -> AudioBuffer {
        let maxValue = samples.flatMap { $0 }.map(abs).max() ?? 0
        guard maxValue > 0 else { return self }
        let gain = peak / maxValue
        return AudioBuffer(samples: samples.map { $0.map { $0 * gain } }, sampleRate: sampleRate)
    }
}

public struct ReverbSettings: Codable, Equatable, Sendable {
    public var dryLevel: Double
    public var wetLevel: Double
    public var preDelayMilliseconds: Double
    public var decayScale: Double
    public var lowCutHz: Double
    public var highCutHz: Double
    public var reverseImpulse: Bool
    public var normalizeOutput: Bool

    public init(
        dryLevel: Double = 0.5,
        wetLevel: Double = 0.5,
        preDelayMilliseconds: Double = 0,
        decayScale: Double = 1,
        lowCutHz: Double = 20,
        highCutHz: Double = 20_000,
        reverseImpulse: Bool = false,
        normalizeOutput: Bool = true
    ) {
        self.dryLevel = dryLevel
        self.wetLevel = wetLevel
        self.preDelayMilliseconds = preDelayMilliseconds
        self.decayScale = decayScale
        self.lowCutHz = lowCutHz
        self.highCutHz = highCutHz
        self.reverseImpulse = reverseImpulse
        self.normalizeOutput = normalizeOutput
    }
}

public struct RenderRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: Int64
    public var name: String
    public var createdAt: Date
    public var dryPath: String
    public var impulsePath: String
    public var outputPath: String
    public var settings: ReverbSettings
    public var sampleRate: Int
    public var duration: Double

    public init(
        id: Int64 = 0,
        name: String,
        createdAt: Date = Date(),
        dryPath: String,
        impulsePath: String,
        outputPath: String,
        settings: ReverbSettings,
        sampleRate: Int,
        duration: Double
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.dryPath = dryPath
        self.impulsePath = impulsePath
        self.outputPath = outputPath
        self.settings = settings
        self.sampleRate = sampleRate
        self.duration = duration
    }
}

public struct ReverbPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: Int64
    public var name: String
    public var createdAt: Date
    public var settings: ReverbSettings

    public init(id: Int64 = 0, name: String, createdAt: Date = Date(), settings: ReverbSettings) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.settings = settings
    }
}
