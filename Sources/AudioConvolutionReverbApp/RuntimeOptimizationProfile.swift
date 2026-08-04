import Foundation

enum RuntimeChipFamily: String {
    case appleSilicon
    case intel
}

enum RuntimeOSFamily: String {
    case macOS1015Or11
    case macOS12
    case macOS13Or14
    case macOS15OrNewer
}

struct RuntimeOptimizationProfile {
    let chipFamily: RuntimeChipFamily
    let osFamily: RuntimeOSFamily

    static var current: RuntimeOptimizationProfile {
        RuntimeOptimizationProfile(
            chipFamily: detectedChipFamily,
            osFamily: detectedOSFamily
        )
    }

    private static var detectedChipFamily: RuntimeChipFamily {
        #if arch(arm64)
        return .appleSilicon
        #else
        return .intel
        #endif
    }

    private static var detectedOSFamily: RuntimeOSFamily {
        if #available(macOS 15.0, *) {
            return .macOS15OrNewer
        }
        if #available(macOS 13.0, *) {
            return .macOS13Or14
        }
        if #available(macOS 12.0, *) {
            return .macOS12
        }
        return .macOS1015Or11
    }

    var audioAnalysisPointBudget: Int {
        switch (chipFamily, osFamily) {
        case (.appleSilicon, .macOS15OrNewer): 180
        case (.appleSilicon, .macOS13Or14): 168
        case (.appleSilicon, .macOS12): 144
        case (.appleSilicon, .macOS1015Or11): 108
        case (.intel, .macOS15OrNewer): 156
        case (.intel, .macOS13Or14): 144
        case (.intel, .macOS12): 120
        case (.intel, .macOS1015Or11): 90
        }
    }

    var audioSpectrumBinBudget: Int {
        switch (chipFamily, osFamily) {
        case (.appleSilicon, .macOS15OrNewer): 96
        case (.appleSilicon, .macOS13Or14): 84
        case (.appleSilicon, .macOS12): 72
        case (.appleSilicon, .macOS1015Or11): 54
        case (.intel, .macOS15OrNewer): 84
        case (.intel, .macOS13Or14): 72
        case (.intel, .macOS12): 60
        case (.intel, .macOS1015Or11): 48
        }
    }

    var libraryRenderLimit: Int {
        switch (chipFamily, osFamily) {
        case (.appleSilicon, .macOS15OrNewer): 100
        case (.appleSilicon, .macOS13Or14): 90
        case (.appleSilicon, .macOS12): 72
        case (.appleSilicon, .macOS1015Or11): 48
        case (.intel, .macOS15OrNewer): 80
        case (.intel, .macOS13Or14): 72
        case (.intel, .macOS12): 56
        case (.intel, .macOS1015Or11): 40
        }
    }
}
