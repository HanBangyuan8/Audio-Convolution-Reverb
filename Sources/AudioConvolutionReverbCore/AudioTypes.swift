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

    public func prefix(seconds: Double) -> AudioBuffer {
        let count = min(frameCount, max(1, Int(seconds * Double(sampleRate))))
        return AudioBuffer(samples: samples.map { Array($0.prefix(count)) }, sampleRate: sampleRate)
    }
}

public struct ReverbSettings: Codable, Equatable, Sendable {
    public var dryLevel: Double
    public var wetLevel: Double
    public var inputGainDB: Double
    public var outputGainDB: Double
    public var preDelayMilliseconds: Double
    public var decayScale: Double
    public var lowCutHz: Double
    public var highCutHz: Double
    public var impulseTrimStartMilliseconds: Double
    public var impulseTrimEndMilliseconds: Double
    public var fadeInMilliseconds: Double
    public var fadeOutMilliseconds: Double
    public var stereoWidth: Double
    public var tailLengthSeconds: Double
    public var latencyCompensationMilliseconds: Double
    public var reverseImpulse: Bool
    public var normalizeOutput: Bool
    public var normalizeWetSignal: Bool

    public init(
        dryLevel: Double = 0.5,
        wetLevel: Double = 0.5,
        inputGainDB: Double = 0,
        outputGainDB: Double = 0,
        preDelayMilliseconds: Double = 0,
        decayScale: Double = 1,
        lowCutHz: Double = 20,
        highCutHz: Double = 20_000,
        impulseTrimStartMilliseconds: Double = 0,
        impulseTrimEndMilliseconds: Double = 0,
        fadeInMilliseconds: Double = 0,
        fadeOutMilliseconds: Double = 25,
        stereoWidth: Double = 1,
        tailLengthSeconds: Double = 2,
        latencyCompensationMilliseconds: Double = 0,
        reverseImpulse: Bool = false,
        normalizeOutput: Bool = true,
        normalizeWetSignal: Bool = false
    ) {
        self.dryLevel = dryLevel
        self.wetLevel = wetLevel
        self.inputGainDB = inputGainDB
        self.outputGainDB = outputGainDB
        self.preDelayMilliseconds = preDelayMilliseconds
        self.decayScale = decayScale
        self.lowCutHz = lowCutHz
        self.highCutHz = highCutHz
        self.impulseTrimStartMilliseconds = impulseTrimStartMilliseconds
        self.impulseTrimEndMilliseconds = impulseTrimEndMilliseconds
        self.fadeInMilliseconds = fadeInMilliseconds
        self.fadeOutMilliseconds = fadeOutMilliseconds
        self.stereoWidth = stereoWidth
        self.tailLengthSeconds = tailLengthSeconds
        self.latencyCompensationMilliseconds = latencyCompensationMilliseconds
        self.reverseImpulse = reverseImpulse
        self.normalizeOutput = normalizeOutput
        self.normalizeWetSignal = normalizeWetSignal
    }

    private enum CodingKeys: String, CodingKey {
        case dryLevel
        case wetLevel
        case inputGainDB
        case outputGainDB
        case preDelayMilliseconds
        case decayScale
        case lowCutHz
        case highCutHz
        case impulseTrimStartMilliseconds
        case impulseTrimEndMilliseconds
        case fadeInMilliseconds
        case fadeOutMilliseconds
        case stereoWidth
        case tailLengthSeconds
        case latencyCompensationMilliseconds
        case reverseImpulse
        case normalizeOutput
        case normalizeWetSignal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dryLevel = try container.decodeIfPresent(Double.self, forKey: .dryLevel) ?? 0.5
        wetLevel = try container.decodeIfPresent(Double.self, forKey: .wetLevel) ?? 0.5
        inputGainDB = try container.decodeIfPresent(Double.self, forKey: .inputGainDB) ?? 0
        outputGainDB = try container.decodeIfPresent(Double.self, forKey: .outputGainDB) ?? 0
        preDelayMilliseconds = try container.decodeIfPresent(Double.self, forKey: .preDelayMilliseconds) ?? 0
        decayScale = try container.decodeIfPresent(Double.self, forKey: .decayScale) ?? 1
        lowCutHz = try container.decodeIfPresent(Double.self, forKey: .lowCutHz) ?? 20
        highCutHz = try container.decodeIfPresent(Double.self, forKey: .highCutHz) ?? 20_000
        impulseTrimStartMilliseconds = try container.decodeIfPresent(Double.self, forKey: .impulseTrimStartMilliseconds) ?? 0
        impulseTrimEndMilliseconds = try container.decodeIfPresent(Double.self, forKey: .impulseTrimEndMilliseconds) ?? 0
        fadeInMilliseconds = try container.decodeIfPresent(Double.self, forKey: .fadeInMilliseconds) ?? 0
        fadeOutMilliseconds = try container.decodeIfPresent(Double.self, forKey: .fadeOutMilliseconds) ?? 25
        stereoWidth = try container.decodeIfPresent(Double.self, forKey: .stereoWidth) ?? 1
        tailLengthSeconds = try container.decodeIfPresent(Double.self, forKey: .tailLengthSeconds) ?? 2
        latencyCompensationMilliseconds = try container.decodeIfPresent(Double.self, forKey: .latencyCompensationMilliseconds) ?? 0
        reverseImpulse = try container.decodeIfPresent(Bool.self, forKey: .reverseImpulse) ?? false
        normalizeOutput = try container.decodeIfPresent(Bool.self, forKey: .normalizeOutput) ?? true
        normalizeWetSignal = try container.decodeIfPresent(Bool.self, forKey: .normalizeWetSignal) ?? false
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
