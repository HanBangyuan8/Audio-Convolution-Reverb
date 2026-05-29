import Foundation

struct ComplexFFT {
    static func convolve(_ signal: [Double], _ kernel: [Double]) -> [Double] {
        guard !signal.isEmpty, !kernel.isEmpty else { return [] }
        let outputCount = signal.count + kernel.count - 1
        let fftCount = nextPowerOfTwo(outputCount)

        var realA = signal + Array(repeating: 0, count: fftCount - signal.count)
        var imagA = Array(repeating: 0.0, count: fftCount)
        var realB = kernel + Array(repeating: 0, count: fftCount - kernel.count)
        var imagB = Array(repeating: 0.0, count: fftCount)

        fft(real: &realA, imag: &imagA, inverse: false)
        fft(real: &realB, imag: &imagB, inverse: false)

        for index in 0..<fftCount {
            let real = realA[index] * realB[index] - imagA[index] * imagB[index]
            let imag = realA[index] * imagB[index] + imagA[index] * realB[index]
            realA[index] = real
            imagA[index] = imag
        }

        fft(real: &realA, imag: &imagA, inverse: true)
        return Array(realA.prefix(outputCount))
    }

    private static func fft(real: inout [Double], imag: inout [Double], inverse: Bool) {
        let n = real.count
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j ^= bit
            if i < j {
                real.swapAt(i, j)
                imag.swapAt(i, j)
            }
        }

        var length = 2
        while length <= n {
            let angle = (inverse ? 2.0 : -2.0) * Double.pi / Double(length)
            let wLengthReal = cos(angle)
            let wLengthImag = sin(angle)

            var start = 0
            while start < n {
                var wReal = 1.0
                var wImag = 0.0
                let half = length / 2
                for offset in 0..<half {
                    let even = start + offset
                    let odd = even + half
                    let oddReal = real[odd] * wReal - imag[odd] * wImag
                    let oddImag = real[odd] * wImag + imag[odd] * wReal

                    real[odd] = real[even] - oddReal
                    imag[odd] = imag[even] - oddImag
                    real[even] += oddReal
                    imag[even] += oddImag

                    let nextReal = wReal * wLengthReal - wImag * wLengthImag
                    wImag = wReal * wLengthImag + wImag * wLengthReal
                    wReal = nextReal
                }
                start += length
            }
            length <<= 1
        }

        if inverse {
            let scale = Double(n)
            for index in 0..<n {
                real[index] /= scale
                imag[index] /= scale
            }
        }
    }

    private static func nextPowerOfTwo(_ value: Int) -> Int {
        var power = 1
        while power < value { power <<= 1 }
        return power
    }
}
