import SwiftUI
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

@MainActor
@Observable
public final class AudioWaveformMonitor {
    
    public static let shared = AudioWaveformMonitor()
    
    private var audioEngine = AVAudioEngine()
    private var isAudioEngineRunning = false
    
    public var fftMagnitudes = [Float](repeating: 0, count: 200)
    
    private let fftManager = FFTSetupManager(bufferSize: 8192)
    
    private init() {}
    
    public var isMonitoring: Bool {
        return isAudioEngineRunning
    }
    
    public func startMonitoring() async {
        guard !isAudioEngineRunning else { return }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let bufferSize = UInt32(fftManager.bufferSize)
        
        let audioStream = AsyncStream<[Float]> { continuation in
            inputNode.installTap(onBus: 0, bufferSize: UInt32(bufferSize), format: inputFormat) { @Sendable buffer, _ in
                let channelData = buffer.floatChannelData?[0]
                let frameCount = Int(buffer.frameLength)
                let floatData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                continuation.yield(floatData)
            }
        }
        
        do {
            try audioEngine.start()
            isAudioEngineRunning = true
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            return
        }
        
        for await floatData in audioStream {
            self.fftMagnitudes = await self.performFFT(data: floatData)
        }
    }
    
    public func stopMonitoring() {
        guard isAudioEngineRunning else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        fftMagnitudes = [Float](repeating: 0, count: 200)
        isAudioEngineRunning = false
    }
    
    private func performFFT(data: [Float]) async -> [Float] {
        let bufferSize = fftManager.bufferSize
        var realIn = data
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        var magnitudes = [Float](repeating: 0, count: 200)
        
        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                        vDSP_DFT_Execute(fftManager.fftSetup, realInPtr.baseAddress!, imagInPtr.baseAddress!, realOutPtr.baseAddress!, imagOutPtr.baseAddress!)
                        
                        var complex = DSPSplitComplex(realp: realOutPtr.baseAddress!, imagp: imagOutPtr.baseAddress!)
                        vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(200))
                    }
                }
            }
        }
        
        return magnitudes.map { min($0, 100) }
    }
}
