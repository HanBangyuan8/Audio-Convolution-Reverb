import AudioConvolutionReverbCore
import Foundation

enum CLIError: Error, CustomStringConvertible {
    case usage
    case message(String)

    var description: String {
        switch self {
        case .usage:
            return help
        case .message(let message):
            return message
        }
    }
}

let help = """
audio-reverb-swift commands:

  sweep <output.wav> [duration] [sampleRate]
  extract-ir <recorded.wav> <sweep.wav> <output-ir.wav> [length]
  apply <dry.wav> <ir.wav> <output.wav> [wet] [dry]
  custom-ir <output.wav> [duration] [decay] [tone]
  inspect <audio.wav>

The Python CLI from the original notebook remains available as audio-reverb.
"""

do {
    try run(CommandLine.arguments)
} catch {
    fputs("\(error)\n", stderr)
    exit(error is CLIError ? 2 : 1)
}

func run(_ arguments: [String]) throws {
    guard arguments.count >= 2 else { throw CLIError.usage }
    let command = arguments[1]

    switch command {
    case "sweep":
        guard arguments.count >= 3 else { throw CLIError.usage }
        let duration = arguments.double(at: 3) ?? 10
        let sampleRate = arguments.int(at: 4) ?? 48_000
        let buffer = ReverbDSP.generateLogSweep(duration: duration, sampleRate: sampleRate)
        try WAVAudioIO.write(buffer, to: URL(fileURLWithPath: arguments[2]), bitDepth: 24)
        print("Generated sweep: \(arguments[2])")

    case "extract-ir":
        guard arguments.count >= 5 else { throw CLIError.usage }
        let recorded = try WAVAudioIO.read(from: URL(fileURLWithPath: arguments[2]))
        let sweep = try WAVAudioIO.read(from: URL(fileURLWithPath: arguments[3]))
        let length = arguments.double(at: 5) ?? 10
        let ir = ReverbDSP.extractImpulseResponse(recorded: recorded, sweep: sweep, irLength: length)
        try WAVAudioIO.write(ir, to: URL(fileURLWithPath: arguments[4]), bitDepth: 24)
        print("Extracted impulse response: \(arguments[4])")

    case "apply":
        guard arguments.count >= 5 else { throw CLIError.usage }
        let dry = try WAVAudioIO.read(from: URL(fileURLWithPath: arguments[2]))
        let ir = try WAVAudioIO.read(from: URL(fileURLWithPath: arguments[3]))
        var settings = ReverbSettings()
        settings.wetLevel = arguments.double(at: 5) ?? 0.5
        settings.dryLevel = arguments.double(at: 6) ?? 0.5
        let rendered = ReverbDSP.applyConvolutionReverb(dry: dry, impulseResponse: ir, settings: settings)
        try WAVAudioIO.write(rendered, to: URL(fileURLWithPath: arguments[4]), bitDepth: 24)
        print("Rendered: \(arguments[4])")

    case "custom-ir":
        guard arguments.count >= 3 else { throw CLIError.usage }
        let duration = arguments.double(at: 3) ?? 2.8
        let decay = arguments.double(at: 4) ?? 4.2
        let tone = arguments.double(at: 5) ?? 0.55
        let ir = ReverbDSP.createCustomImpulse(sampleRate: 48_000, duration: duration, decay: decay, tone: tone, earlyReflectionCount: 10)
        try WAVAudioIO.write(ir, to: URL(fileURLWithPath: arguments[2]), bitDepth: 24)
        print("Generated custom IR: \(arguments[2])")

    case "inspect":
        guard arguments.count >= 3 else { throw CLIError.usage }
        let audio = try WAVAudioIO.read(from: URL(fileURLWithPath: arguments[2]))
        print("channels=\(audio.channelCount) sampleRate=\(audio.sampleRate) frames=\(audio.frameCount) duration=\(String(format: "%.3f", audio.duration))")

    default:
        throw CLIError.usage
    }
}

private extension Array where Element == String {
    func double(at index: Int) -> Double? {
        guard indices.contains(index) else { return nil }
        return Double(self[index])
    }

    func int(at index: Int) -> Int? {
        guard indices.contains(index) else { return nil }
        return Int(self[index])
    }
}
