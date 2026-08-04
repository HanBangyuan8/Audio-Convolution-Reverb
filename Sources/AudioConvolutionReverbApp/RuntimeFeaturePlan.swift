import Foundation

struct RuntimeFeaturePlan {
    let profile: RuntimeOptimizationProfile

    static var current: RuntimeFeaturePlan {
        RuntimeFeaturePlan(profile: .current)
    }

    var usesSwiftUIAppLifecycle: Bool {
        profile.osFamily == .macOS13Or14 || profile.osFamily == .macOS15OrNewer
    }

    var audioAnalysisPointBudget: Int {
        profile.audioAnalysisPointBudget
    }

    var audioSpectrumBinBudget: Int {
        profile.audioSpectrumBinBudget
    }

    var libraryRenderLimit: Int {
        profile.libraryRenderLimit
    }

    var librarySearchDebounceNanoseconds: UInt64 {
        switch profile.osFamily {
        case .macOS15OrNewer: 100_000_000
        case .macOS13Or14: 140_000_000
        case .macOS12: 200_000_000
        case .macOS1015Or11: 280_000_000
        }
    }
}
