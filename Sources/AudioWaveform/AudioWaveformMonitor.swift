import SwiftUI
import AVFoundation
import Accelerate

@MainActor
@Observable
public final class AudioWaveformMonitor {

    public static let shared = AudioWaveformMonitor()

    private var audioEngine = AVAudioEngine()
    private var isAudioEngineRunning = false

    public var fftMagnitudes = [Float](repeating: 0, count: 200)

    private let bufferSize = 8192
    private var fftSetup: OpaquePointer?

    private init() {
        // Initialize FFT setup
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(self.bufferSize), .FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    public var isMonitoring: Bool {
        return isAudioEngineRunning
    }

    public func startMonitoring() async {
        guard !isAudioEngineRunning else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

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
        guard let setup = fftSetup else { return [Float](repeating: 0, count: 200) }

        var realIn = data
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        var magnitudes = [Float](repeating: 0, count: 200)

        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                        vDSP_DFT_Execute(setup, realInPtr.baseAddress!, imagInPtr.baseAddress!, realOutPtr.baseAddress!, imagOutPtr.baseAddress!)

                        var complex = DSPSplitComplex(realp: realOutPtr.baseAddress!, imagp: imagOutPtr.baseAddress!)
                        vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(200))
                    }
                }
            }
        }

        return magnitudes.map { min($0, 100) }
    }
}