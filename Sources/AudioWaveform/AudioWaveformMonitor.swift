import AVFoundation
import Accelerate

/// Manages the lifecycle of the vDSP FFT setup pointer.
/// This class uses the RAII pattern to ensure the pointer is created
/// and destroyed properly.
private final class FFTSetupManager: @unchecked Sendable {
    let bufferSize: Int
    let fftSetup: OpaquePointer
    
    init(bufferSize: Int) {
        self.bufferSize = bufferSize
        // Create the FFT setup object.
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(bufferSize), .FORWARD)!
    }
    
    deinit {
        // Destroy the FFT setup object when this manager is deinitialized.
        vDSP_DFT_DestroySetup(fftSetup)
    }
}

private final class AudioWaveformProcessor: @unchecked Sendable {
    private let fftManager: FFTSetupManager
    private let fftSize: Int
    private let magnitudeCount: Int
    private let lock = NSLock()
    
    private var realIn: [Float]
    private var imagIn: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]
    private var magnitudes: [Float]
    
    init(fftSize: Int, magnitudeCount: Int) {
        self.fftSize = fftSize
        self.magnitudeCount = magnitudeCount
        self.fftManager = FFTSetupManager(bufferSize: fftSize)
        self.realIn = [Float](repeating: 0, count: fftSize)
        self.imagIn = [Float](repeating: 0, count: fftSize)
        self.realOut = [Float](repeating: 0, count: fftSize)
        self.imagOut = [Float](repeating: 0, count: fftSize)
        self.magnitudes = [Float](repeating: 0, count: magnitudeCount)
    }
    
    func process(samples inputSamples: [Float]) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        
        if inputSamples.isEmpty {
            magnitudes.withUnsafeMutableBufferPointer { pointer in
                pointer.update(repeating: 0)
            }
            return magnitudes
        }
        
        realIn.withUnsafeMutableBufferPointer { pointer in
            pointer.update(repeating: 0)
        }
        let copyCount = min(inputSamples.count, fftSize)
        if copyCount > 0 {
            for index in 0..<copyCount {
                realIn[index] = inputSamples[index]
            }
        }
        imagIn.withUnsafeMutableBufferPointer { pointer in
            pointer.update(repeating: 0)
        }
        realOut.withUnsafeMutableBufferPointer { pointer in
            pointer.update(repeating: 0)
        }
        imagOut.withUnsafeMutableBufferPointer { pointer in
            pointer.update(repeating: 0)
        }
        
        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                        vDSP_DFT_Execute(
                            fftManager.fftSetup,
                            realInPtr.baseAddress!,
                            imagInPtr.baseAddress!,
                            realOutPtr.baseAddress!,
                            imagOutPtr.baseAddress!
                        )
                        
                        var complex = DSPSplitComplex(
                            realp: realOutPtr.baseAddress!,
                            imagp: imagOutPtr.baseAddress!
                        )
                        vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(magnitudeCount))
                    }
                }
            }
        }
        
        let upperBound: Float = 100
        for index in magnitudes.indices {
            magnitudes[index] = min(magnitudes[index], upperBound)
        }
        
        return magnitudes
    }
    
    func process(buffer: AVAudioPCMBuffer) -> [Float] {
        guard
            let channelData = buffer.floatChannelData?.pointee,
            buffer.frameLength > 0
        else {
            return [Float](repeating: 0, count: magnitudeCount)
        }
        
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        return process(samples: samples)
    }
    
    func resetMagnitudes() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        magnitudes.withUnsafeMutableBufferPointer { pointer in
            pointer.update(repeating: 0)
        }
        return magnitudes
    }
    
    var magnitudeVectorLength: Int {
        magnitudeCount
    }
}

@MainActor
@Observable
public final class AudioWaveformMonitor {
    public static let shared = AudioWaveformMonitor()
    
    public private(set) var fftMagnitudes: [Float]
    
    private let processor: AudioWaveformProcessor
    
    public init(fftSize: Int = 8192, magnitudeCount: Int = 200) {
        self.processor = AudioWaveformProcessor(fftSize: fftSize, magnitudeCount: magnitudeCount)
        self.fftMagnitudes = [Float](repeating: 0, count: magnitudeCount)
    }
    
    public func reset() {
        fftMagnitudes = processor.resetMagnitudes()
    }
    
    nonisolated public func process(buffer: AVAudioPCMBuffer) {
        let magnitudes = processor.process(buffer: buffer)
        Task { @MainActor [self] in
            self.fftMagnitudes = magnitudes
        }
    }
    
    nonisolated public func process(samples: [Float]) {
        let magnitudes = processor.process(samples: samples)
        Task { @MainActor [self] in
            self.fftMagnitudes = magnitudes
        }
    }
}
